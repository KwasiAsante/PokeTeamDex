import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

/// Full unfiltered Pokémon list (IDs 1–1025 only, excludes alternate forms).
final pokemonListProvider = FutureProvider<List<PokemonListEntry>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  final all = await repo.fetchPokemonList();
  return all.where((p) => p.id >= 1 && p.id <= 1025).toList();
});

/// Current search string.
final pokemonSearchProvider = StateProvider<String>((ref) => '');

/// Current filter + sort state.
final pokedexFilterProvider = StateProvider<PokedexFilter>((ref) => const PokedexFilter());

/// Set of IDs allowed by the active type filter (null = no type filter active).
final _typeFilterIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final filter = ref.watch(pokedexFilterProvider);
  if (filter.type == null) return null;
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemonIdsByType(filter.type!);
});

/// Filtered + sorted list consumed by the UI.
final filteredPokemonListProvider = Provider<AsyncValue<List<PokemonListEntry>>>((ref) {
  final listAsync = ref.watch(pokemonListProvider);
  final typeIdsAsync = ref.watch(_typeFilterIdsProvider);
  final search = ref.watch(pokemonSearchProvider).trim().toLowerCase();
  final filter = ref.watch(pokedexFilterProvider);

  // Propagate loading / error from either async source
  if (listAsync is AsyncLoading || typeIdsAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (listAsync is AsyncError) return AsyncValue.error(listAsync.error!, listAsync.stackTrace!);
  if (typeIdsAsync is AsyncError) return AsyncValue.error(typeIdsAsync.error!, typeIdsAsync.stackTrace!);

  List<PokemonListEntry> items = listAsync.requireValue;

  // Generation filter
  if (filter.generation != null) {
    final range = generationRanges[filter.generation!]!;
    items = items.where((p) => p.id >= range.$1 && p.id <= range.$2).toList();
  }

  // Type filter
  final typeIds = typeIdsAsync.value;
  if (typeIds != null) {
    items = items.where((p) => typeIds.contains(p.id)).toList();
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
  if (filter.sort == PokedexSort.name) {
    items = [...items]..sort((a, b) => a.name.compareTo(b.name));
  }
  // PokedexSort.dexNumber: list is already in dex order from API

  return AsyncValue.data(items);
});
