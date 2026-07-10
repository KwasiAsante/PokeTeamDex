import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

/// Merges Pokémon data for a single ID into one [ResolvedPokemon].
///
/// Uses [withBackendFallback]: tries the backend first, falls back to a
/// cached copy (accepting up to 24h stale), then to a full offline
/// reconstruction from PokéAPI + bundled PS data (gen-accurate stat/type
/// overrides and learnset-supplement moves), and only throws if neither a
/// cache entry nor internet access is available.
///
/// This provider is **keepAlive** (no `.autoDispose`) — once resolved it stays
/// in memory for the app session. This eliminates the ~100 provider rebuild
/// cycles generated per full scroll pass through the Pokédex list (50 tiles ×
/// 2 autoDispose providers each).
///
/// [pokemonByNameProvider] for user-selected alternate forms (Mega, Gmax,
/// battle varieties) remains a separate autoDispose provider — those are
/// on-demand fetches, not baseline data.
final resolvedPokemonProvider =
    FutureProvider.family<ResolvedPokemon, ({int id, int? gen})>((ref, params) async {
  final id = params.id;
  final gen = params.gen;
  final cacheKey = gen != null ? 'resolved_${id}_g$gen' : 'resolved_$id';

  return withBackendFallback<ResolvedPokemon>(
    cacheKey: cacheKey,
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () async {
      final repo = ref.read(pokemonBackendRepositoryProvider);
      final response = await repo.fetchResolved(id, gen: gen);
      return _fromBackendResponse(response);
    },
    offlineFallback: () => _offlineFallback(ref, id, gen),
    fromJson: ResolvedPokemon.fromJson,
    toJson: (r) => r.toJson(),
  );
});

/// Assembles a [ResolvedPokemon] from PokéAPI (Hive-cached per pokeapi_cache)
/// plus bundled PS data — a full, non-degraded reconstruction of what the
/// backend would have returned, not a partial/sentinel result.
Future<ResolvedPokemon> _offlineFallback(Ref ref, int id, int? gen) async {
  final detail = await ref.read(pokemonDetailProvider(id).future);
  final species = await ref.read(pokemonSpeciesProvider(id).future);

  // cosmeticFormsProvider returns [] for species with ≤1 form or where all
  // form names are varieties. Skip entirely for species known to inherit
  // irrelevant form names from an evolution partner (e.g. Mothim ← Burmy).
  final rawCosmetic =
      PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains(detail.name)
          ? const <PokemonFormEntry>[]
          : await ref.read(cosmeticFormsProvider(detail.name).future);
  final cosmeticForms = _patchCosmeticForms(rawCosmetic, detail.id, detail.name);

  final spriteUrls = SpriteUrlsFull(
    officialArtwork: detail.officialArtworkUrl,
    officialArtworkShiny: detail.officialArtworkShinyUrl,
  );

  if (gen == null) {
    return ResolvedPokemon(
      detail: detail,
      species: species,
      cosmeticForms: cosmeticForms,
      spriteUrls: spriteUrls,
    );
  }

  // Gen-accurate stat/type overrides + learnset supplement moves, sourced
  // from the same bundled shared/ps_data/ files the backend itself reads.
  final psData = ref.read(psDataServiceProvider);
  await psData.initialize();
  final speciesPsId = psIdFromName(detail.speciesName ?? detail.name);

  var patchedDetail = detail;
  final override = genAccuratePokedexOverride(psData, speciesPsId, gen);
  if (override != null && (override.stats.isNotEmpty || override.types.isNotEmpty)) {
    patchedDetail = PokemonEntry(
      id: detail.id,
      name: detail.name,
      speciesName: detail.speciesName,
      height: detail.height,
      weight: detail.weight,
      baseExperience: detail.baseExperience,
      types: override.types.isNotEmpty ? override.types : detail.types,
      officialArtworkUrl: detail.officialArtworkUrl,
      sprites: detail.sprites,
      stats: override.stats.isNotEmpty ? override.stats : detail.stats,
      abilities: detail.abilities,
      moves: detail.moves,
      formNames: detail.formNames,
    );
  }

  final learnset = await psData.learnsetForGen(gen);
  final supplementMoves = learnsetSupplementMoves(
    psData: psData,
    learnsetForGen: learnset,
    speciesPsId: speciesPsId,
    gen: gen,
    existingMoveNames: detail.moves.map((m) => m.name).toSet(),
  );

  return ResolvedPokemon(
    detail: patchedDetail,
    species: species,
    cosmeticForms: cosmeticForms,
    spriteUrls: spriteUrls,
    supplementMoves: supplementMoves,
  );
}

ResolvedPokemon _fromBackendResponse(PokemonResolvedBackendResponse r) {
  final detail = r.toPokemonEntry();
  final species = r.toPokemonSpeciesEntry();
  final rawCosmetic = PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains(detail.name)
      ? const <PokemonFormEntry>[]
      : r.toCosmeticForms();
  final cosmeticForms = _patchCosmeticForms(rawCosmetic, detail.id, detail.name);

  return ResolvedPokemon(
    detail: detail,
    species: species,
    cosmeticForms: cosmeticForms,
    spriteUrls: r.spriteUrls,
    supplementMoves: r.supplementMoves,
    smogonAnalyses: r.smogonAnalyses,
  );
}

List<PokemonFormEntry> _patchCosmeticForms(
    List<PokemonFormEntry> forms, int pokemonId, String pokemonName) {
  final patched = forms.map((f) {
    if (f.spriteUrl == null && f.formName == 'female') {
      return PokemonFormEntry(
        id: f.id,
        name: f.name,
        formName: f.formName,
        isDefault: f.isDefault,
        spriteUrl: '${_kBase}female/$pokemonId.png',
        spriteShinyUrl: '${_kBase}shiny/female/$pokemonId.png',
        officialArtworkUrl: f.officialArtworkUrl,
        officialArtworkShinyUrl: f.officialArtworkShinyUrl,
      );
    }
    return f;
  }).toList();

  if (PokemonDataRegistry.instance.cosmeticGenderDiffPokemon.contains(pokemonName)) {
    patched.add(PokemonFormEntry(
      id: pokemonId,
      name: '$pokemonName-female',
      formName: 'female',
      isDefault: false,
      spriteUrl: '${_kBase}female/$pokemonId.png',
      spriteShinyUrl: '${_kBase}shiny/female/$pokemonId.png',
    ));
  }
  return patched;
}
