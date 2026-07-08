import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Backend-first full item catalog. Falls back to PokéAPI name list on failure.
final itemsListProvider = FutureProvider<List<BackendItemEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final first = await repo.fetchCatalogItems(pageSize: 1000);
    var items = first.items;
    if (first.totalPages > 1) {
      final rest = await Future.wait([
        for (int p = 2; p <= first.totalPages; p++)
          repo.fetchCatalogItems(page: p, pageSize: 1000),
      ]);
      items = [...items, for (final r in rest) ...r.items];
    }
    AppLogger().d('[catalog] items: loaded ${items.length} entries from backend (${first.totalPages} pages)');
    return items;
  } catch (e) {
    AppLogger().w('[catalog] items backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchItemList();
    return names.map(BackendItemEntry.fromName).toList();
  }
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
///
/// "held-items" is special-cased: it's a PokéAPI item *category* nested
/// inside the "misc" pocket, not a pocket of its own — see
/// [PokeApiRepository.fetchItemsByCategory].
final itemsByPocketProvider =
    FutureProvider.family<List<String>, String>((ref, pocket) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return pocket == 'held-items'
      ? repo.fetchItemsByCategory('held-items')
      : repo.fetchItemsByPocket(pocket);
});

// ── Per-item detail (autoDispose — large family cache) ────────────────────────

final itemProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItem(name);
});

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredItemsProvider = Provider<AsyncValue<List<BackendItemEntry>>>((ref) {
  final pocket = ref.watch(itemPocketFilterProvider);
  final sort   = ref.watch(itemSortProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();

  final backendAsync = ref.watch(itemsListProvider);
  final backendList = backendAsync.asData?.value ?? const <BackendItemEntry>[];
  // Map for fast name → entry lookup (used when pocket filter is active).
  final catalogMap = <String, BackendItemEntry>{
    for (final e in backendList) e.name: e,
  };
  // ID order map for idAscending/idDescending sorts.
  final idOrder = <String, int>{
    for (int i = 0; i < backendList.length; i++) backendList[i].name: i,
  };

  // Determine the base list of entries to filter/sort.
  final AsyncValue<List<BackendItemEntry>> entriesAsync;
  if (pocket != null) {
    // Pocket filter uses PokéAPI name list; enrich from catalog where available.
    final pocketAsync = ref.watch(itemsByPocketProvider(pocket));
    if (pocketAsync is AsyncLoading || backendAsync is AsyncLoading) {
      return const AsyncValue.loading();
    }
    if (pocketAsync is AsyncError) {
      return AsyncValue.error(
          (pocketAsync as AsyncError).error,
          (pocketAsync as AsyncError).stackTrace);
    }
    final pocketNames = pocketAsync.requireValue;
    entriesAsync = AsyncValue.data(
      pocketNames
          .map((n) => catalogMap[n] ?? BackendItemEntry.fromName(n))
          .toList(),
    );
  } else if (backendAsync is AsyncLoading) {
    return const AsyncValue.loading();
  } else if (backendAsync is AsyncError) {
    return AsyncValue.error(
        (backendAsync as AsyncError).error,
        (backendAsync as AsyncError).stackTrace);
  } else {
    entriesAsync = AsyncValue.data(List.of(backendList));
  }

  List<BackendItemEntry> items = List.of(entriesAsync.requireValue);

  if (search.isNotEmpty) {
    items = items
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  switch (sort) {
    case ItemSort.nameAZ:
      items.sort((a, b) => a.name.compareTo(b.name));
    case ItemSort.nameZA:
      items.sort((a, b) => b.name.compareTo(a.name));
    case ItemSort.idAscending:
      items.sort((a, b) =>
          (idOrder[a.name] ?? 999999).compareTo(idOrder[b.name] ?? 999999));
    case ItemSort.idDescending:
      items.sort((a, b) =>
          (idOrder[b.name] ?? 999999).compareTo(idOrder[a.name] ?? 999999));
  }

  return AsyncValue.data(items);
});
