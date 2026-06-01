import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final movesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMoveList();
});

// Persists across tab switches.
final movesSearchProvider = StateProvider<String>((ref) => '');
final movesDamageClassFilterProvider = StateProvider<String?>((ref) => null);
final movesTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Move names for a given type — fetched from /type/{name}, cached 7 days.
final movesByTypeProvider =
    FutureProvider.family<List<String>, String>((ref, typeName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMovesByType(typeName);
});

final filteredMovesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final typeFilter = ref.watch(movesTypeFilterProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();

  // When a type filter is active use the type-specific list; otherwise full list.
  final AsyncValue<List<String>> listAsync = typeFilter != null
      ? ref.watch(movesByTypeProvider(typeFilter))
      : ref.watch(movesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<String> names = List<String>.from(listAsync.requireValue);

  if (search.isNotEmpty) {
    names = names
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  }

  return AsyncValue.data(names);
});

/// Fetches a machine's item name and URL by the machine's full PokéAPI URL.
final machineProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>(
        (ref, url) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMachineByUrl(url);
});
