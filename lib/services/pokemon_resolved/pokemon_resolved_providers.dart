import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/sprite_url_builder.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';

final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(
  (ref) => PokemonBackendRepository(ref.read(apiClientProvider)),
);

/// Lazy-loaded moves list. When gen is null, returns all version groups with
/// per-gen supplement moves merged in for every generation 1-9 (mirrors the
/// backend's `resolve_moves(gen=None)`, then flattened by name — see
/// [PokemonBackendRepository.fetchMoves]'s "all-gens" branch). When gen is N,
/// returns gen-N version groups with backend supplement moves already merged.
///
/// Offline fallback: PokéAPI's full movepool plus PS `learnset_N.json`
/// supplement moves (event/egg/tutor moves PokéAPI has no record of).
final pokemonMovesProvider =
    FutureProvider.family<List<MoveSummary>, ({int id, int? gen})>((ref, args) async {
  final id = args.id;
  final gen = args.gen;
  final cacheKey = gen != null ? 'moves_${id}_g$gen' : 'moves_$id';

  return withBackendFallback<List<MoveSummary>>(
    cacheKey: cacheKey,
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () => ref.read(pokemonBackendRepositoryProvider).fetchMoves(id, gen: gen),
    offlineFallback: () async {
      final detail = await ref.read(pokemonDetailProvider(id).future);
      final psData = ref.read(psDataServiceProvider);
      await psData.initialize();
      // Always key the PS lookup off the actually-resolved Pokémon's own name
      // — mirrors the backend's `ps_id` (computed once from `pokemon_name` in
      // resolve() and reused for supplement-move lookups here). Never falls
      // back to the species name: doing so would silently substitute the
      // BASE species' PS learnset/supplement data for a genuine variety
      // (e.g. a Mega/regional/battle form selected in team slot config).
      final speciesPsId = psIdFromName(detail.name);

      if (gen != null) {
        // Mirrors the backend's `_moves_by_gen` bucketing in resolve() —
        // detail.moves is the Pokémon's ENTIRE unfiltered movepool (every
        // version_group_details entry across every generation it has ever
        // appeared in, side-game VGs included). Bucket it down to just the
        // requested gen's own version groups before returning, exactly like
        // the backend does, rather than returning the whole movepool.
        final genMoves = _filterMovesToGen(detail.moves, gen);

        final learnset = await psData.learnsetForGen(gen);
        final supplements = learnsetSupplementMoves(
          psData: psData,
          learnsetForGen: learnset,
          speciesPsId: speciesPsId,
          gen: gen,
          // Gen-scoped exclusion set — mirrors the backend's `move_slugs`
          // (resolve(), "Use only the moves PokéAPI already has for data_gen
          // as the exclusion set"): a move present in some OTHER gen but
          // absent from this one must still be added as a supplement here.
          existingMoveNames: genMoves.map((m) => m.name).toSet(),
        );
        if (supplements.isEmpty) return genMoves;

        final versionGroup = PokemonDataRegistry.instance.genToLastVg[gen] ?? 'unknown';
        return [
          ...genMoves,
          for (final s in supplements)
            supplementMoveToMoveSummary(s, versionGroup),
        ];
      }

      // gen == null: mirrors the backend's resolve_moves(gen=None) exactly —
      // for each gen 1-9 INDEPENDENTLY, bucket the real PokéAPI movepool to
      // that gen (same _filterMovesToGen the gen!=null branch above uses),
      // compute that gen's supplement moves excluding only ITS OWN bucket
      // (mirrors backend's `existing_slugs = {ms.name for ms in
      // all_moves.get(g, [])}` — per-gen, not global: a move known in some
      // OTHER gen but missing from this one must still get a synthetic entry
      // here), then flatten every gen's bucket into one list by name,
      // merging learnDetails — exactly what
      // PokemonBackendRepository.fetchMoves's "all-gens" branch does to the
      // backend's own gen-keyed response. A single global exclusion set
      // (the previous approach here) only reproduces the correct SET of move
      // NAMES, not the correct per-version-group learnDetails — the Pokédex
      // Moves tab's version-filter dropdown depends on the latter.
      final learnsetsByGen = await Future.wait(
        [for (var g = 1; g <= 9; g++) psData.learnsetForGen(g)],
      );

      final byName = <String, List<MoveLearnDetail>>{};
      void addMove(MoveSummary ms) {
        byName.update(ms.name, (d) => d..addAll(ms.learnDetails),
            ifAbsent: () => List.of(ms.learnDetails));
      }

      for (var g = 1; g <= 9; g++) {
        final genMoves = _filterMovesToGen(detail.moves, g);
        for (final m in genMoves) {
          addMove(m);
        }
        final supplements = learnsetSupplementMoves(
          psData: psData,
          learnsetForGen: learnsetsByGen[g - 1],
          speciesPsId: speciesPsId,
          gen: g,
          existingMoveNames: genMoves.map((m) => m.name).toSet(),
        );
        if (supplements.isEmpty) continue;
        final versionGroup = PokemonDataRegistry.instance.genToLastVg[g] ?? 'unknown';
        for (final s in supplements) {
          addMove(supplementMoveToMoveSummary(s, versionGroup));
        }
      }

      return [
        for (final entry in byName.entries)
          MoveSummary(name: entry.key, learnDetails: entry.value),
      ];
    },
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList(),
    toJson: (moves) => {'items': moves.map((m) => m.toJson()).toList()},
  );
});

/// PokéAPI version groups for side-game titles with no real gen mapping —
/// mirrors the backend's `_SIDE_GAME_VGS`. Moves only ever learned in these
/// games are excluded entirely, regardless of requested gen.
const _kSideGameVgs = {'colosseum', 'xd', 'stadium', 'stadium-2'};

/// Buckets [moves] (the Pokémon's entire unfiltered PokéAPI movepool) down to
/// just [gen]'s own version groups — mirrors the backend's `_moves_by_gen`
/// construction in `resolve()`. A move whose every `version_group_details`
/// entry belongs to a different gen (or a side-game VG) is dropped entirely;
/// a move with at least one gen-[gen] entry is kept with its [learnDetails]
/// filtered down to just those gen-[gen] entries.
List<MoveSummary> _filterMovesToGen(List<MoveSummary> moves, int gen) {
  final vgToGen = PokemonDataRegistry.instance.vgToGen;
  final result = <MoveSummary>[];
  for (final m in moves) {
    final genDetails = m.learnDetails.where((d) {
      if (_kSideGameVgs.contains(d.versionGroup)) return false;
      return vgToGen[d.versionGroup] == gen;
    }).toList();
    if (genDetails.isNotEmpty) {
      result.add(MoveSummary(name: m.name, learnDetails: genDetails));
    }
  }
  return result;
}

/// Valid learnset for a Pokémon in a specific generation — a set of move names
/// learnable in that gen, with backend supplement moves (event, egg, tutor)
/// already merged.
///
/// Uses [pokemonMovesProvider] with gen filtering. On backend failure the
/// offline fallback bucket-filters the movepool down to this gen too (see
/// [_filterMovesToGen]), so this stays gen-accurate offline as well.
final validLearnsetProvider =
    FutureProvider.family<Set<String>, ({int id, int gen})>((ref, args) async {
  final moves = await ref.read(
    pokemonMovesProvider((id: args.id, gen: args.gen)).future,
  );
  return {for (final m in moves) m.name};
});

/// Lazy-loaded full variety data (types, base_stats, abilities, sprite_urls per variety).
///
/// Slim [resolvedPokemonProvider] varieties only carry name + pokemon_id.
/// This provider fetches [GET /pokemon/varieties/{id}] which returns full
/// [SpriteUrlsFull] and stat/type data for every non-default variety.
///
/// Offline fallback: PokéAPI's species variety list, resolved to full
/// per-variety data via individual `/pokemon/{name}` fetches, with the same
/// gen-accurate PS overrides, introduction-gen filtering, and mega/G-max
/// classification the backend's `_fetch_varieties` applies.
///
/// Used by form picker chips to show artwork for Mega, regional, and other
/// battle-meaningful variety forms.
final pokemonVarietiesProvider =
    FutureProvider.family<List<VarietyBackendData>, ({int id, int? gen})>(
        (ref, args) async {
  ref.keepAlive(); // keep in memory so teams screen reads instantly after team_detail loads it
  final id = args.id;
  final gen = args.gen;
  final cacheKey = gen != null ? 'varieties_${id}_g$gen' : 'varieties_$id';

  return withBackendFallback<List<VarietyBackendData>>(
    cacheKey: cacheKey,
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () => ref
        .read(pokemonBackendRepositoryProvider)
        .fetchVarieties(id, gen: gen ?? 9),
    offlineFallback: () async {
      // Backend treats a missing gen as 9 for this endpoint (`gen: int = 9`
      // default at the route level) — matches the online branch above.
      final effectiveGen = gen ?? 9;
      final species = await ref.read(pokemonSpeciesProvider(id).future);
      final repo = ref.read(pokeApiRepositoryProvider);
      final psData = ref.read(psDataServiceProvider);
      await psData.initialize();

      final basePsId = psIdFromName(species.name);
      final baseNum = (psData.pokedex[basePsId] as Map<String, dynamic>?)?['num'] as int?;
      final registry = PokemonDataRegistry.instance;

      final results = <VarietyBackendData>[];
      for (final v in species.varieties) {
        if (v.isDefault) continue;
        // Mirrors the backend's `resolve()` post-filter (`varieties = [v for
        // v in varieties if v.pokemon_id != pokemon_id]`, pokemon_resolver.py
        // :1303) — when resolving a variety directly (e.g. Charizard-Mega-X
        // itself), the species' own varieties list includes that variety;
        // exclude it from its own varieties list.
        if (v.pokemonId == id) continue;
        if (varietyIntroGen(v.name, baseNum) > effectiveGen) continue;
        try {
          final p = await repo.fetchPokemonByNameOrDefault(v.name);
          // Always key the PS lookup off the variety's own name — mirrors
          // the backend's `_fetch_varieties` (`ps_id = data["name"].replace(
          // "-", "").lower()`, `data` being the variety's own /pokemon/{id}
          // response). Never falls back to the base species name.
          final varietyPsId = psIdFromName(p.name);
          final resolved = resolveGenAccuratePokedexData(
            psData,
            varietyPsId,
            effectiveGen,
            rawTypes: p.types,
            rawStats: p.stats,
            rawAbilities: p.abilities,
          );

          final isGmax = v.name.contains('gmax');
          final associatedItem = registry.megaFormToItem[v.name];
          final associatedMove = registry.megaFormMoveRequirements[v.name];
          final isMega = associatedItem != null || associatedMove != null;

          final psSpriteName = toShowdownName(p.name, registry.psFormExceptions);
          final spriteUrls = buildVarietySpriteUrls(
            sprites: p.sprites,
            psName: psSpriteName,
            varietyId: p.id,
            gen: effectiveGen,
            varietyName: v.name,
            basePokemonId: id,
            varietyIconIdOverrides: registry.varietyIconIdOverrides,
          );

          results.add(VarietyBackendData(
            name: v.name,
            pokemonId: p.id,
            isDefault: false,
            types: resolved.types,
            baseStats: resolved.stats,
            abilities: abilityInfoListToPsSlotMap(resolved.abilities),
            spriteUrls: spriteUrls,
            isMega: isMega,
            isBattleOnly: isMega || isGmax,
            isGmax: isGmax,
            associatedItem: associatedItem,
            associatedMove: associatedMove,
            associatedAbility: registry.abilityGatingRules[v.name],
          ));
        } catch (_) {
          // Mirrors the backend's `_fetch_varieties`: on a failed per-variety
          // fetch, still include a slim stub (name/pokemonId/isDefault only)
          // rather than dropping the variety entirely — so a Mega/regional/
          // battle-form chip doesn't just vanish on a transient failure, and
          // stays available to retry. Skip only if we truly have no id to
          // stub with (species data cached before this field existed).
          if (v.pokemonId != null) {
            results.add(VarietyBackendData(
              name: v.name,
              pokemonId: v.pokemonId!,
              isDefault: false,
            ));
          }
        }
      }
      return results;
    },
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((v) => VarietyBackendData.fromJson(v as Map<String, dynamic>))
        .toList(),
    toJson: (varieties) => {'items': varieties.map((v) => v.toJson()).toList()},
  );
});

/// Lazy-loaded full form sprite data (official_artwork, home, game_front per form).
///
/// Slim [resolvedPokemonProvider] only carries [FormBackendData.frontSpriteUrl]
/// (pixel sprite). This provider fetches [GET /pokemon/forms/{id}] which returns
/// the full [SpriteUrlsFull] for every cosmetic form.
///
/// Offline fallback: PokéAPI's `pokemon-form` list via [cosmeticFormsProvider].
///
/// Used by form picker chips to show official → home → sprite quality images.
final pokemonFormsProvider =
    FutureProvider.family<List<FormBackendData>, ({int id, int? gen})>(
        (ref, args) async {
  ref.keepAlive(); // keep in memory so teams screen reads instantly after team_detail loads it
  final id = args.id;
  final gen = args.gen;
  final cacheKey = gen != null ? 'forms_${id}_g$gen' : 'forms_$id';

  return withBackendFallback<List<FormBackendData>>(
    cacheKey: cacheKey,
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () => ref
        .read(pokemonBackendRepositoryProvider)
        .fetchForms(id, gen: gen ?? 9),
    offlineFallback: () async {
      // Backend treats a missing gen as 9 for this endpoint (`gen: int = 9`
      // default at the route level) — matches the online branch above.
      final effectiveGen = gen ?? 9;
      final detail = await ref.read(pokemonDetailProvider(id).future);
      final species = await ref.read(pokemonSpeciesProvider(id).future);
      final registry = PokemonDataRegistry.instance;
      final forms = await ref.read(cosmeticFormsProvider(detail.name).future);

      return Future.wait(forms.map((f) async {
        final spriteUrls = await buildFormSpriteUrlsProbed(
          formName: f.name,
          baseId: id,
          speciesName: species.name,
          gen: effectiveGen,
          psExceptions: registry.psFormExceptions,
        );
        // Mirrors the backend's `api_front = sprites.front_default or
        // pokeapi_home or fallback_front` chain — prefer the form-API's own
        // sprite, then the probed HOME URL, then the constructed plain sprite.
        final fallbackFront = formFallbackFrontUrl(f.name, species.name, id);
        final frontSpriteUrl = f.spriteUrl ?? spriteUrls.home ?? fallbackFront;

        return FormBackendData(
          name: f.name,
          formId: f.id,
          isDefault: f.isDefault,
          frontSpriteUrl: frontSpriteUrl,
          spriteUrls: spriteUrls,
        );
      }).toList());
    },
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((f) => FormBackendData.fromJson(f as Map<String, dynamic>))
        .toList(),
    toJson: (forms) => {'items': forms.map((f) => f.toJson()).toList()},
  );
});

/// Lazy-loaded English flavor text entries.
final pokemonFlavorTextProvider =
    FutureProvider.family<List<FlavorTextEntry>, int>((ref, id) async {
  return withBackendFallback<List<FlavorTextEntry>>(
    cacheKey: 'flavor_$id',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () => ref.read(pokemonBackendRepositoryProvider).fetchFlavorText(id, lang: 'en'),
    offlineFallback: () async {
      final species = await ref.read(pokemonSpeciesProvider(id).future);
      return species.flavorTextEntries.where((e) => e.language == 'en').toList();
    },
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList(),
    toJson: (entries) => {'items': entries.map((e) => e.toJson()).toList()},
  );
});
