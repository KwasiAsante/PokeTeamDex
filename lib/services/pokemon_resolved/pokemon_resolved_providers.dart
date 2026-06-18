import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';

final pokemonResolvedCacheProvider = Provider<PokemonResolvedCache>(
  (_) => PokemonResolvedCache(),
);

final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(
  (ref) => PokemonBackendRepository(ref.read(apiClientProvider)),
);

/// Lazy-loaded full moves list. Checks pokemon_resolved_cache first,
/// then backend, then falls back to PokéAPI (offline).
final pokemonMovesProvider =
    FutureProvider.family<List<MoveSummary>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('moves_$id');
  if (cached != null) {
    return (cached['moves'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final moves = await repo.fetchMoves(id);
    cache.putWithTTL(
      'moves_$id',
      {'moves': moves.map((m) => m.toJson()).toList()},
      const Duration(days: 7),
    );
    return moves;
  } catch (_) {
    // Offline fallback: return moves from PokéAPI detail
    final detail = await ref.read(pokemonDetailProvider(id).future);
    return detail.moves;
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
    FutureProvider.family<List<FormBackendData>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('forms_$id');
  if (cached != null) {
    return (cached['forms'] as List<dynamic>)
        .map((f) => FormBackendData.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final forms = await repo.fetchForms(id);
    cache.putWithTTL(
      'forms_$id',
      {'forms': forms.map((f) => f.toJson()).toList()},
      const Duration(days: 7),
    );
    return forms;
  } catch (_) {
    return const [];
  }
});

/// Lazy-loaded English flavor text entries.
final pokemonFlavorTextProvider =
    FutureProvider.family<List<FlavorTextEntry>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('flavor_$id');
  if (cached != null) {
    return (cached['entries'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList();
  }

  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final entries = await repo.fetchFlavorText(id, lang: 'en');
    cache.putWithTTL(
      'flavor_$id',
      {'entries': entries.map((e) => e.toJson()).toList()},
      const Duration(days: 7),
    );
    return entries;
  } catch (_) {
    // Offline fallback: return English entries from PokéAPI species
    final species = await ref.read(pokemonSpeciesProvider(id).future);
    return species.flavorTextEntries
        .where((e) => e.language == 'en')
        .toList();
  }
});
