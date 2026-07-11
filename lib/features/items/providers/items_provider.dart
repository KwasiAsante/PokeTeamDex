import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/catalog/catalog_offline_merge.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

/// Backend-first full item catalog. Falls back to a full offline
/// PokéAPI+PS-data merge (see [buildOfflineItemCatalog]) when the backend and
/// cache are both unavailable.
final itemsListProvider = FutureProvider<List<BackendItemEntry>>((ref) async {
  ref.keepAlive();
  return withBackendFallback<List<BackendItemEntry>>(
    cacheKey: 'catalog_items',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () async {
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
      return items;
    },
    offlineFallback: () => buildOfflineItemCatalog(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
    ),
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((i) => BackendItemEntry.fromJson(i as Map<String, dynamic>))
        .toList(),
    toJson: (items) => {'items': items.map((i) => i.toJson()).toList()},
  );
});

// Not autoDispose — persists across tab switches.
final itemsSearchProvider = StateProvider<String>((ref) => '');

// ── Filtering & sorting ───────────────────────────────────────────────────────

enum ItemSort { nameAZ, nameZA, idAscending, idDescending }

/// Selected item pocket filter (null = all items).
final itemPocketFilterProvider = StateProvider<String?>((ref) => null);

/// Sort direction for the item list.
final itemSortProvider = StateProvider<ItemSort>((ref) => ItemSort.nameAZ);

/// Filter by generation (1-9) — mirrors the backend's `/items?gen=` param
/// (`catalog_service.py`'s `list_items`). Not yet exposed in the UI.
final itemsGenFilterProvider = StateProvider<int?>((ref) => null);

/// Filter by exact PokéAPI item-category name (e.g. "mega-stones") — mirrors
/// the backend's `/items?category=` param. More granular than
/// [itemPocketFilterProvider] (a pocket groups multiple categories together,
/// e.g. "misc" bundles 25 categories) — not yet exposed in the UI.
final itemsCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Filter to only mega stones (true) or only non-mega-stones (false) —
/// mirrors the backend's `/items?is_mega_stone=` param. Not yet exposed in the UI.
final itemsIsMegaStoneFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only Z-crystals — mirrors `/items?is_z_crystal=`. Not yet
/// exposed in the UI.
final itemsIsZCrystalFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only berries — mirrors `/items?is_berry=`. Not yet exposed in
/// the UI.
final itemsIsBerryFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only plates — mirrors `/items?is_plate=`. Not yet exposed in
/// the UI.
final itemsIsPlateFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only memories — mirrors `/items?is_memory=`. Not yet exposed in
/// the UI.
final itemsIsMemoryFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only PS-sourced/battle-relevant items (true) or only
/// PokéAPI-only items like key items/mail/medicine (false) — mirrors the
/// backend's `/items?is_battle_relevant=` param. Not yet exposed in the UI.
final itemsIsBattleRelevantFilterProvider = StateProvider<bool?>((ref) => null);

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

/// PokéAPI item-category name → pocket name, verified against the live
/// `/item-pocket/{pocket}` endpoints for all 8 real pockets (misc, medicine,
/// pokeballs, machines, berries, mail, battle, key — "mail" has no filter
/// chip in [kItemPockets] and is intentionally not user-facing here).
///
/// This replaces a live `/item-pocket/{pocket}` fetch per filter tap
/// ([PokeApiRepository.fetchItemsByPocket], now removed) with a lookup over
/// each entry's already-known `category` field (present on every
/// [BackendItemEntry] from either the backend catalog or the offline
/// PokéAPI+PS merge) — pocket filtering now works identically online and
/// offline, with no extra network dependency at all.
///
/// Static PokéAPI game data that does not change; safe to hardcode. Note the
/// name collision: the "medicine" *category* here belongs to the "berries"
/// *pocket* (distinct from the "medicine" pocket's own categories) — this
/// map disambiguates that correctly since it's keyed by category, not by a
/// naive category-equals-pocket-name assumption.
const _kCategoryToPocket = <String, String>{
  // misc
  'collectibles': 'misc',
  'evolution': 'misc',
  'spelunking': 'misc',
  'held-items': 'misc',
  'choice': 'misc',
  'effort-training': 'misc',
  'bad-held-items': 'misc',
  'training': 'misc',
  'plates': 'misc',
  'species-specific': 'misc',
  'type-enhancement': 'misc',
  'loot': 'misc',
  'mulch': 'misc',
  'dex-completion': 'misc',
  'scarves': 'misc',
  'jewels': 'misc',
  'mega-stones': 'misc',
  'memories': 'misc',
  'species-candies': 'misc',
  'dynamax-crystals': 'misc',
  'curry-ingredients': 'misc',
  'tera-shard': 'misc',
  'sandwich-ingredients': 'misc',
  'tm-materials': 'misc',
  'picnic': 'misc',
  // medicine
  'vitamins': 'medicine',
  'healing': 'medicine',
  'pp-recovery': 'medicine',
  'revival': 'medicine',
  'status-cures': 'medicine',
  'nature-mints': 'medicine',
  // pokeballs
  'special-balls': 'pokeballs',
  'standard-balls': 'pokeballs',
  'apricorn-balls': 'pokeballs',
  // machines
  'all-machines': 'machines',
  // berries
  'effort-drop': 'berries',
  'medicine': 'berries',
  'other': 'berries',
  'in-a-pinch': 'berries',
  'picky-healing': 'berries',
  'type-protection': 'berries',
  'baking-only': 'berries',
  'catching-bonus': 'berries',
  // mail (no filter chip today)
  'all-mail': 'mail',
  // battle
  'stat-boosts': 'battle',
  'flutes': 'battle',
  'miracle-shooter': 'battle',
  // key
  'event-items': 'key',
  'gameplay': 'key',
  'plot-advancement': 'key',
  'unused': 'key',
  'apricorn-box': 'key',
  'data-cards': 'key',
  'z-crystals': 'key',
};

/// Resolves an entry's pocket-filter membership from its own `category`
/// field — see [_kCategoryToPocket]. "held-items" is special-cased in
/// [kItemPockets] as its own pseudo-pocket (it's really a category nested
/// inside "misc"), so it's matched by category equality rather than via the
/// category→pocket map.
bool _entryMatchesPocket(BackendItemEntry entry, String pocket) {
  final category = entry.category;
  if (category == null) return false;
  if (pocket == 'held-items') return category == 'held-items';
  return _kCategoryToPocket[category] == pocket;
}

// ── Per-item detail (autoDispose — large family cache) ────────────────────────

final itemProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItem(name);
});

final catalogItemProvider =
    FutureProvider.autoDispose.family<BackendItemEntry, String>((ref, name) {
  return withBackendFallback<BackendItemEntry>(
    cacheKey: 'catalog_item_$name',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () =>
        ref.read(pokemonBackendRepositoryProvider).fetchCatalogItem(name),
    offlineFallback: () => buildOfflineItemEntry(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
      name,
    ),
    fromJson: BackendItemEntry.fromJson,
    toJson: (item) => item.toJson(),
  );
});

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredItemsProvider = Provider<AsyncValue<List<BackendItemEntry>>>((ref) {
  final pocket = ref.watch(itemPocketFilterProvider);
  final sort   = ref.watch(itemSortProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();
  final genFilter = ref.watch(itemsGenFilterProvider);
  final categoryFilter = ref.watch(itemsCategoryFilterProvider);
  final isMegaStoneFilter = ref.watch(itemsIsMegaStoneFilterProvider);
  final isZCrystalFilter = ref.watch(itemsIsZCrystalFilterProvider);
  final isBerryFilter = ref.watch(itemsIsBerryFilterProvider);
  final isPlateFilter = ref.watch(itemsIsPlateFilterProvider);
  final isMemoryFilter = ref.watch(itemsIsMemoryFilterProvider);
  final isBattleRelevantFilter = ref.watch(itemsIsBattleRelevantFilterProvider);

  final backendAsync = ref.watch(itemsListProvider);
  if (backendAsync is AsyncLoading) return const AsyncValue.loading();
  if (backendAsync is AsyncError) {
    return AsyncValue.error(
        (backendAsync as AsyncError).error,
        (backendAsync as AsyncError).stackTrace);
  }
  final backendList = backendAsync.requireValue;
  // ID order map for idAscending/idDescending sorts.
  final idOrder = <String, int>{
    for (int i = 0; i < backendList.length; i++) backendList[i].name: i,
  };

  // Pocket membership is derived from each entry's own `category` field
  // (see [_entryMatchesPocket]) rather than a live PokéAPI fetch — works
  // identically online and offline, no extra network dependency.
  List<BackendItemEntry> items = pocket == null
      ? List.of(backendList)
      : backendList.where((e) => _entryMatchesPocket(e, pocket)).toList();

  if (genFilter != null) {
    items = items.where((e) => e.gen == genFilter).toList();
  }
  if (categoryFilter != null) {
    items = items.where((e) => e.category == categoryFilter).toList();
  }
  if (isMegaStoneFilter != null) {
    items = items.where((e) => e.isMegaStone == isMegaStoneFilter).toList();
  }
  if (isZCrystalFilter != null) {
    items = items.where((e) => e.isZCrystal == isZCrystalFilter).toList();
  }
  if (isBerryFilter != null) {
    items = items.where((e) => e.isBerry == isBerryFilter).toList();
  }
  if (isPlateFilter != null) {
    items = items.where((e) => e.isPlate == isPlateFilter).toList();
  }
  if (isMemoryFilter != null) {
    items = items.where((e) => e.isMemory == isMemoryFilter).toList();
  }
  if (isBattleRelevantFilter != null) {
    items = items
        .where((e) => e.isBattleRelevant == isBattleRelevantFilter)
        .toList();
  }

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
