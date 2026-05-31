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

// ── Filtering & sorting ───────────────────────────────────────────────────────

enum ItemSort { nameAZ, nameZA, idAscending, idDescending }

/// Selected item pocket filter (null = all items).
final itemPocketFilterProvider = StateProvider<String?>((ref) => null);

/// Sort direction for the item list.
final itemSortProvider = StateProvider<ItemSort>((ref) => ItemSort.nameAZ);

/// The item pockets available as filter options.
/// Maps PokéAPI pocket name → display label.
const kItemPockets = <String, String>{
  'pokeballs': 'Poké Balls',
  'medicine':  'Medicine',
  'berries':   'Berries',
  'held-items': 'Held Items',
  'machines':  'Machines',
  'battle':    'Battle',
  'key':       'Key Items',
  'misc':      'Misc',
};

/// Item names for a given pocket, fetched from PokéAPI and cached.
final itemsByPocketProvider =
    FutureProvider.family<List<String>, String>((ref, pocket) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItemsByPocket(pocket);
});

// ── Per-item detail (autoDispose — large family cache) ────────────────────────

final itemProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItem(name);
});

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredItemsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final pocket = ref.watch(itemPocketFilterProvider);
  final sort   = ref.watch(itemSortProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();

  // For ID sorting we need the full list order as a reference index.
  final fullListAsync = ref.watch(itemsListProvider);
  final fullList = fullListAsync.asData?.value ?? const [];
  final idOrder = <String, int>{
    for (int i = 0; i < fullList.length; i++) fullList[i]: i,
  };

  // Use pocket-specific list when filtered, otherwise the full list.
  final AsyncValue<List<String>> listAsync = pocket != null
      ? ref.watch(itemsByPocketProvider(pocket))
      : fullListAsync;

  if (listAsync is AsyncLoading || fullListAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<String> items = List<String>.from(listAsync.requireValue);

  if (search.isNotEmpty) {
    items = items
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  }

  switch (sort) {
    case ItemSort.nameAZ:
      items.sort();
    case ItemSort.nameZA:
      items.sort((a, b) => b.compareTo(a));
    case ItemSort.idAscending:
      items.sort((a, b) =>
          (idOrder[a] ?? 999999).compareTo(idOrder[b] ?? 999999));
    case ItemSort.idDescending:
      items.sort((a, b) =>
          (idOrder[b] ?? 999999).compareTo(idOrder[a] ?? 999999));
  }

  return AsyncValue.data(items);
});
