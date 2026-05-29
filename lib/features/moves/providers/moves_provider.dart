import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final movesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMoveList();
});

final movesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final movesDamageClassFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final filteredMovesProvider = Provider.autoDispose<AsyncValue<List<String>>>((ref) {
  final listAsync = ref.watch(movesListProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();

  return listAsync.whenData((names) {
    if (search.isEmpty) return names;
    return names
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  });
});
