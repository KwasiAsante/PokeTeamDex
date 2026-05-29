import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final abilitiesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchAbilityList();
});

final abilitiesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredAbilitiesProvider =
    Provider.autoDispose<AsyncValue<List<String>>>((ref) {
  final listAsync = ref.watch(abilitiesListProvider);
  final search = ref.watch(abilitiesSearchProvider).trim().toLowerCase();

  return listAsync.whenData((names) {
    if (search.isEmpty) return names;
    return names
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  });
});
