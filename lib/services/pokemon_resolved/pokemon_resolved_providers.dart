import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

final pokemonResolvedCacheProvider = Provider<PokemonResolvedCache>(
  (_) => PokemonResolvedCache(),
);

final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(
  (ref) => PokemonBackendRepository(ref.read(apiClientProvider)),
);

/// Lazy-loaded moves list. When gen is null, returns all version groups (no
/// supplement moves). When gen is N, returns gen-N version groups with backend
/// supplement moves already merged.
///
/// Falls back to PokéAPI-sourced moves on backend failure (unfiltered by gen).
final pokemonMovesProvider =
    FutureProvider.family<List<MoveSummary>, ({int id, int? gen})>((ref, args) async {
  final id = args.id;
  final gen = args.gen;
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cacheKey = gen != null ? 'moves_${id}_g$gen' : 'moves_$id';
  final cached = cache.getIfValid(cacheKey);
  if (cached != null) {
    AppLogger().d('[moves] cache hit id=$id gen=$gen');
    return (cached['moves'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  try {
    AppLogger().d('[moves] fetching from backend id=$id gen=$gen');
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final moves = await repo.fetchMoves(id, gen: gen);
    AppLogger().d('[moves] loaded ${moves.length} moves for id=$id gen=$gen');
    cache.putWithTTL(
      cacheKey,
      {'moves': moves.map((m) => m.toJson()).toList()},
      const Duration(days: 7),
    );
    return moves;
  } catch (e) {
    AppLogger().w('[moves] backend failed for id=$id gen=$gen, falling back to PokéAPI', error: e);
    final detail = await ref.read(pokemonDetailProvider(id).future);
    return detail.moves;
  }
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
/// Used by form picker chips to show artwork for Mega, regional, and other
/// battle-meaningful variety forms.
final pokemonVarietiesProvider =
    FutureProvider.family<List<VarietyBackendData>, ({int id, int? gen})>(
        (ref, args) async {
  ref.keepAlive(); // keep in memory so teams screen reads instantly after team_detail loads it
  final id = args.id;
  final gen = args.gen;
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cacheKey = gen != null ? 'varieties_${id}_g$gen' : 'varieties_$id';
  final cached = cache.getIfValid(cacheKey);
  if (cached != null) {
    AppLogger().d('[varieties] cache hit id=$id gen=$gen');
    return (cached['varieties'] as List<dynamic>)
        .map((v) => VarietyBackendData.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  try {
    AppLogger().d('[varieties] fetching from backend id=$id gen=$gen');
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final varieties = await repo.fetchVarieties(id, gen: gen ?? 9);
    AppLogger().d('[varieties] loaded ${varieties.length} varieties for id=$id gen=$gen');
    cache.putWithTTL(
      cacheKey,
      {'varieties': varieties.map((v) => v.toJson()).toList()},
      const Duration(days: 7),
    );
    return varieties;
  } catch (e) {
    AppLogger().w('[varieties] failed for id=$id gen=$gen, returning empty', error: e);
    return const [];
  }
});

/// Lazy-loaded full form sprite data (official_artwork, home, game_front per form).
///
/// Slim [resolvedPokemonProvider] only carries [FormBackendData.frontSpriteUrl]
/// (pixel sprite). This provider fetches [GET /pokemon/forms/{id}] which returns
/// the full [SpriteUrlsFull] for every cosmetic form.
///
/// Used by form picker chips to show official → home → sprite quality images.
final pokemonFormsProvider =
    FutureProvider.family<List<FormBackendData>, ({int id, int? gen})>(
        (ref, args) async {
  ref.keepAlive(); // keep in memory so teams screen reads instantly after team_detail loads it
  final id = args.id;
  final gen = args.gen;
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cacheKey = gen != null ? 'forms_${id}_g$gen' : 'forms_$id';
  final cached = cache.getIfValid(cacheKey);
  if (cached != null) {
    AppLogger().d('[forms] cache hit id=$id gen=$gen');
    return (cached['forms'] as List<dynamic>)
        .map((f) => FormBackendData.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  try {
    AppLogger().d('[forms] fetching from backend id=$id gen=$gen');
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final forms = await repo.fetchForms(id, gen: gen ?? 9);
    AppLogger().d('[forms] loaded ${forms.length} forms for id=$id gen=$gen');
    cache.putWithTTL(
      cacheKey,
      {'forms': forms.map((f) => f.toJson()).toList()},
      const Duration(days: 7),
    );
    return forms;
  } catch (e) {
    AppLogger().w('[forms] failed for id=$id gen=$gen, returning empty', error: e);
    return const [];
  }
});

/// Lazy-loaded English flavor text entries.
final pokemonFlavorTextProvider =
    FutureProvider.family<List<FlavorTextEntry>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('flavor_$id');
  if (cached != null) {
    AppLogger().d('[flavor] cache hit id=$id');
    return (cached['entries'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList();
  }

  try {
    AppLogger().d('[flavor] fetching from backend id=$id');
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final entries = await repo.fetchFlavorText(id, lang: 'en');
    AppLogger().d('[flavor] loaded ${entries.length} entries for id=$id');
    cache.putWithTTL(
      'flavor_$id',
      {'entries': entries.map((e) => e.toJson()).toList()},
      const Duration(days: 7),
    );
    return entries;
  } catch (e) {
    AppLogger().w('[flavor] backend failed for id=$id, falling back to PokéAPI', error: e);
    final species = await ref.read(pokemonSpeciesProvider(id).future);
    return species.flavorTextEntries
        .where((e) => e.language == 'en')
        .toList();
  }
});
