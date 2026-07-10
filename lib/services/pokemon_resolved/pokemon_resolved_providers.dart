import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';

final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(
  (ref) => PokemonBackendRepository(ref.read(apiClientProvider)),
);

/// Lazy-loaded moves list. When gen is null, returns all version groups (no
/// supplement moves). When gen is N, returns gen-N version groups with backend
/// supplement moves already merged.
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
      if (gen == null) return detail.moves;

      final psData = ref.read(psDataServiceProvider);
      await psData.initialize();
      final learnset = await psData.learnsetForGen(gen);
      final speciesPsId = psIdFromName(detail.speciesName ?? detail.name);
      final supplements = learnsetSupplementMoves(
        psData: psData,
        learnsetForGen: learnset,
        speciesPsId: speciesPsId,
        gen: gen,
        existingMoveNames: detail.moves.map((m) => m.name).toSet(),
      );
      if (supplements.isEmpty) return detail.moves;

      final versionGroup = PokemonDataRegistry.instance.genToLastVg[gen] ?? 'unknown';
      return [
        ...detail.moves,
        for (final s in supplements)
          MoveSummary(
            name: s.name,
            learnDetails: [
              for (final method in s.methods)
                MoveLearnDetail(versionGroup: versionGroup, method: method, level: null),
            ],
          ),
      ];
    },
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList(),
    toJson: (moves) => {'items': moves.map((m) => m.toJson()).toList()},
  );
});

/// Valid learnset for a Pokémon in a specific generation — a set of move names
/// learnable in that gen, with backend supplement moves (event, egg, tutor)
/// already merged.
///
/// Uses [pokemonMovesProvider] with gen filtering. On backend failure the
/// fallback is the full PokéAPI moves list (all gens, unfiltered).
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
/// per-variety data via individual `/pokemon/{name}` fetches.
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
      final species = await ref.read(pokemonSpeciesProvider(id).future);
      final repo = ref.read(pokeApiRepositoryProvider);
      final results = <VarietyBackendData>[];
      for (final v in species.varieties) {
        try {
          final p = await repo.fetchPokemonByNameOrDefault(v.name);
          results.add(VarietyBackendData(
            name: v.name,
            pokemonId: p.id,
            isDefault: v.isDefault,
            types: p.types,
            baseStats: p.stats,
            abilities: {
              for (final a in p.abilities)
                (a.isHidden ? 'H' : '${a.slot - 1}'): a.name,
            },
            spriteUrls: SpriteUrlsFull(
              officialArtwork: p.officialArtworkUrl,
              officialArtworkShiny: p.officialArtworkShinyUrl,
            ),
          ));
        } catch (_) {
          // Variety has no reachable PokéAPI resource — skip rather than
          // fabricate a placeholder entry with no real data.
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
      final detail = await ref.read(pokemonDetailProvider(id).future);
      final forms = await ref.read(cosmeticFormsProvider(detail.name).future);
      return forms
          .map((f) => FormBackendData(
                name: f.name,
                formId: f.id,
                isDefault: f.isDefault,
                frontSpriteUrl: f.spriteUrl,
                spriteUrls: SpriteUrlsFull(
                  officialArtwork: f.officialArtworkUrl,
                  officialArtworkShiny: f.officialArtworkShinyUrl,
                  gameFront: f.spriteUrl,
                  gameFrontShiny: f.spriteShinyUrl,
                ),
              ))
          .toList();
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
