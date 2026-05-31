import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final itemsListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItemList();
});

// Not autoDispose — persists across tab switches.
final itemsSearchProvider = StateProvider<String>((ref) => '');

// Per-item detail stays autoDispose since it's a large family cache.
final itemProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItem(name);
});

final filteredItemsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final listAsync = ref.watch(itemsListProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();

  return listAsync.whenData((names) {
    if (search.isEmpty) return names;
    return names
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  });
});
