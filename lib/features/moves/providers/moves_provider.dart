import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final movesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMoveList();
});

// Not autoDispose — persists across tab switches so search/filter state
// is restored when the user returns to the Moves tab.
final movesSearchProvider = StateProvider<String>((ref) => '');

final movesDamageClassFilterProvider = StateProvider<String?>((ref) => null);

final filteredMovesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final listAsync = ref.watch(movesListProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();
  // Damage class filter is applied per-tile in the screen (requires detail
  // fetch); the provider just handles text search for now.
  return listAsync.whenData((names) {
    if (search.isEmpty) return names;
    return names
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  });
});
