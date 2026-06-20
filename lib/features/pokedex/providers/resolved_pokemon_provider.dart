import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

/// Merges Pokémon data for a single ID into one [ResolvedPokemon].
///
/// Fetch order:
/// 1. Hive cache hit  — returns immediately without network calls.
/// 2. Backend fetch   — fast on Postgres hit; result is written to Hive cache.
/// 3. Offline fallback — Task C behaviour: assembles from PokéAPI providers
///    (which are themselves Hive-cached by pokeapi_cache).
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
  final cache = ref.read(pokemonResolvedCacheProvider);

  // Cache key includes gen so gen-specific sprite data is stored separately.
  final cacheKey = gen != null ? 'resolved_${id}_g$gen' : 'resolved_$id';

  // 1. Hive cache hit
  final cached = cache.getIfValid(cacheKey);
  if (cached != null) {
    AppLogger().d('[resolved] Hive cache hit id=$id gen=$gen');
    final response = PokemonResolvedBackendResponse.fromJson(cached);
    return _fromBackendResponse(response);
  }

  // 2. Backend fetch (returns fast on Postgres hit)
  try {
    AppLogger().d('[resolved] fetching from backend id=$id gen=$gen');
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final response = await repo.fetchResolved(id, gen: gen);
    AppLogger().d('[resolved] backend ok id=$id name=${response.name}');
    cache.putWithTTL(cacheKey, response.toJson(), const Duration(days: 7));
    return _fromBackendResponse(response);
  } catch (e) {
    AppLogger().w('[resolved] backend failed id=$id, falling back to PokéAPI', error: e);
    // 3. Offline fallback — Task C behavior
  }

  // Offline: assemble from PokéAPI (already Hive-cached per pokeapi_cache).
  // Use ref.read (not ref.watch) after an await to avoid StateError.
  final detail = await ref.read(pokemonDetailProvider(id).future);
  final species = await ref.read(pokemonSpeciesProvider(id).future);

  // cosmeticFormsProvider returns [] for species with ≤1 form or where all
  // form names are varieties. Skip entirely for species known to inherit
  // irrelevant form names from an evolution partner (e.g. Mothim ← Burmy).
  final rawCosmetic =
      PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains(detail.name)
          ? const <PokemonFormEntry>[]
          : await ref.read(cosmeticFormsProvider(detail.name).future);

  // Patch gender form entries whose /pokemon-form sprite URL is null
  // (frillish-female, jellicent-female) and preserve artwork URLs.
  final patched = rawCosmetic.map((f) {
    if (f.spriteUrl == null && f.formName == 'female') {
      return PokemonFormEntry(
        id: f.id,
        name: f.name,
        formName: f.formName,
        isDefault: f.isDefault,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
        officialArtworkUrl: f.officialArtworkUrl,
        officialArtworkShinyUrl: f.officialArtworkShinyUrl,
      );
    }
    return f;
  }).toList();

  // Synthetic female entry for species with gender-diff sprites but no
  // separate /pokemon-form resource (e.g. Unfezant).
  final cosmeticForms = [
    ...patched,
    if (PokemonDataRegistry.instance.cosmeticGenderDiffPokemon
        .contains(detail.name))
      PokemonFormEntry(
        id: detail.id,
        name: '${detail.name}-female',
        formName: 'female',
        isDefault: false,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
      ),
  ];

  return ResolvedPokemon(
    detail: detail,
    species: species,
    cosmeticForms: cosmeticForms,
    spriteUrls: SpriteUrlsFull(
      officialArtwork: detail.officialArtworkUrl,
      officialArtworkShiny: detail.officialArtworkShinyUrl,
    ),
  );
});

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
