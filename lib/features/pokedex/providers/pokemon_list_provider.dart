import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';

/// Full unfiltered Pokémon list (IDs 1–1025 only, excludes alternate forms).
final pokemonListProvider = FutureProvider<List<PokemonListEntry>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  final all = await repo.fetchPokemonList();
  return all.where((p) => p.id >= 1 && p.id <= 1025).toList();
});

/// Current search string.
final pokemonSearchProvider = StateProvider<String>((ref) => '');

/// Whether the Pokédex list is in grid or list mode.
/// Persists across tab switches; compact layouts always use list regardless.
enum PokedexViewMode { list, grid }

final pokedexViewProvider =
    StateProvider<PokedexViewMode>((ref) => PokedexViewMode.list);

/// Current filter + sort state.
final pokedexFilterProvider = StateProvider<PokedexFilter>((ref) => const PokedexFilter());

/// When true, only favorited Pokémon are shown in the Pokédex list.
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Set of IDs allowed by the active type filter (null = no type filter active).
final _typeFilterIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final filter = ref.watch(pokedexFilterProvider);
  if (filter.type == null) return null;
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemonIdsByType(filter.type!);
});

/// Regional pokedex for the selected game: {speciesName: regionalEntryNumber}.
/// null when no game filter is active.
/// For games with multiple sub-dexes (e.g. X/Y Kalos), the maps are merged
/// sequentially so the combined list preserves sub-dex order.
final _gamePokedexProvider =
    FutureProvider<Map<String, int>?>((ref) async {
  final filter = ref.watch(pokedexFilterProvider);
  final gameId = filter.game;
  if (gameId == null) return null;

  final pokedexNames = kGameToPokedexNames[gameId];
  if (pokedexNames == null || pokedexNames.isEmpty) return null;

  final repo = ref.read(pokeApiRepositoryProvider);
  final merged = <String, int>{};

  for (final dexName in pokedexNames) {
    final dex = await repo.fetchRegionalPokedex(dexName);
    // Offset entries from subsequent sub-dexes so they sort after the
    // previous sub-dex (keeps kalos-coastal after kalos-central, etc.).
    final offset = merged.isEmpty
        ? 0
        : merged.values.fold(0, (m, v) => v > m ? v : m);
    for (final entry in dex.entries) {
      if (!merged.containsKey(entry.key)) {
        merged[entry.key] = offset + entry.value;
      }
    }
  }
  return merged;
});

/// Filtered + sorted list consumed by the UI.
final filteredPokemonListProvider =
    Provider<AsyncValue<List<PokemonListEntry>>>((ref) {
  final listAsync      = ref.watch(pokemonListProvider);
  final typeIdsAsync   = ref.watch(_typeFilterIdsProvider);
  final gameDexAsync   = ref.watch(_gamePokedexProvider);
  final search         = ref.watch(pokemonSearchProvider).trim().toLowerCase();
  final filter         = ref.watch(pokedexFilterProvider);
  final showFavs       = ref.watch(showFavoritesOnlyProvider);
  final favSetAsync    = showFavs ? ref.watch(favoritesSetProvider) : null;

  // Propagate loading / error from any async source
  if (listAsync     is AsyncLoading ||
      typeIdsAsync  is AsyncLoading ||
      gameDexAsync  is AsyncLoading ||
      (favSetAsync  is AsyncLoading)) {
    return const AsyncValue.loading();
  }
  if (listAsync    is AsyncError) return AsyncValue.error(listAsync.error!,    listAsync.stackTrace!);
  if (typeIdsAsync is AsyncError) return AsyncValue.error(typeIdsAsync.error!, typeIdsAsync.stackTrace!);
  if (gameDexAsync is AsyncError) return AsyncValue.error(gameDexAsync.error!, gameDexAsync.stackTrace!);

  List<PokemonListEntry> items = listAsync.requireValue;

  // Generation filter — skip when a game is active; the game's regional dex
  // already defines which Pokémon appear (remakes like ORAS span multiple gens).
  if (filter.generation != null && filter.game == null) {
    final range = generationRanges[filter.generation!]!;
    items = items.where((p) => p.id >= range.$1 && p.id <= range.$2).toList();
  }

  // Game filter — restrict to Pokémon in the game's regional dex
  final gameDex = gameDexAsync.value;
  if (gameDex != null) {
    items = items.where((p) => gameDex.containsKey(p.name)).toList();
  }

  // Type filter
  final typeIds = typeIdsAsync.value;
  if (typeIds != null) {
    items = items.where((p) => typeIds.contains(p.id)).toList();
  }

  // Favorites filter
  if (showFavs && favSetAsync != null) {
    final favIds = favSetAsync.requireValue;
    items = items.where((p) => favIds.contains(p.id)).toList();
  }

  // Search
  if (search.isNotEmpty) {
    items = items
        .where((p) =>
            p.name.contains(search) ||
            p.id.toString().contains(search) ||
            p.displayId().contains(search))
        .toList();
  }

  // Sort
  switch (filter.sort) {
    case PokedexSort.name:
      items = [...items]..sort((a, b) => a.name.compareTo(b.name));
    case PokedexSort.dexNumber:
      if (gameDex != null) {
        // Sort by regional dex number when a game is selected.
        items = [...items]..sort((a, b) {
            final ra = gameDex[a.name] ?? 9999;
            final rb = gameDex[b.name] ?? 9999;
            return ra.compareTo(rb);
          });
      }
      // Otherwise the list is already in national dex order from the API.
  }

  return AsyncValue.data(items);
});
