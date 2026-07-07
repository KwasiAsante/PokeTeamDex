import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Backend-first full item catalog. Falls back to PokéAPI name list on failure.
final itemsListProvider = FutureProvider<List<BackendItemEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogItems(pageSize: 1000);
    AppLogger().d('[catalog] items: loaded ${result.total} entries from backend');
    return result.items;
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

final filteredItemsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final pocket = ref.watch(itemPocketFilterProvider);
  final sort   = ref.watch(itemSortProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();

  // Backend list for the no-filter case and for ID ordering.
  final backendAsync = ref.watch(itemsListProvider);
  final backendList = backendAsync.asData?.value ?? const <BackendItemEntry>[];
  final idOrder = <String, int>{
    for (int i = 0; i < backendList.length; i++) backendList[i].name: i,
  };

  // When pocket filter active, use PokéAPI pocket list (returns names).
  // When no pocket filter, extract names from backend entries.
  final AsyncValue<List<String>> namesAsync;
  if (pocket != null) {
    namesAsync = ref.watch(itemsByPocketProvider(pocket));
  } else if (backendAsync is AsyncLoading) {
    namesAsync = const AsyncValue.loading();
  } else if (backendAsync is AsyncError) {
    namesAsync = AsyncValue.error(
        (backendAsync as AsyncError).error,
        (backendAsync as AsyncError).stackTrace);
  } else {
    namesAsync =
        AsyncValue.data(backendList.map((e) => e.name).toList());
  }

  if (namesAsync is AsyncLoading || backendAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (namesAsync is AsyncError) {
    return AsyncValue.error(
        (namesAsync as AsyncError).error,
        (namesAsync as AsyncError).stackTrace);
  }

  List<String> items = List<String>.from(namesAsync.requireValue);

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
