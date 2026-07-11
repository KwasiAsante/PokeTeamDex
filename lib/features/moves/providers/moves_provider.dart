import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/catalog/catalog_offline_merge.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

/// Backend-first full move catalog. Falls back to a full offline
/// PokéAPI+PS-data merge (see [buildOfflineMoveCatalog]) when the backend and
/// cache are both unavailable.
final movesListProvider = FutureProvider<List<BackendMoveEntry>>((ref) async {
  ref.keepAlive();
  return withBackendFallback<List<BackendMoveEntry>>(
    cacheKey: 'catalog_moves',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () async {
      final repo = ref.read(pokemonBackendRepositoryProvider);
      final first = await repo.fetchCatalogMoves(pageSize: 1000);
      var items = first.items;
      if (first.totalPages > 1) {
        final rest = await Future.wait([
          for (int p = 2; p <= first.totalPages; p++)
            repo.fetchCatalogMoves(page: p, pageSize: 1000),
        ]);
        items = [...items, for (final r in rest) ...r.items];
      }
      return items;
    },
    offlineFallback: () => buildOfflineMoveCatalog(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
    ),
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((m) => BackendMoveEntry.fromJson(m as Map<String, dynamic>))
        .toList(),
    toJson: (moves) => {'items': moves.map((m) => m.toJson()).toList()},
  );
});

// Persists across tab switches.
final movesSearchProvider = StateProvider<String>((ref) => '');
final movesDamageClassFilterProvider = StateProvider<String?>((ref) => null);
final movesTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Filter by generation (1-9) — mirrors the backend's `/moves?gen=` param
/// (`catalog_service.py`'s `list_moves`). Not yet exposed in the UI.
final movesGenFilterProvider = StateProvider<int?>((ref) => null);

/// Filter by PokéAPI contest-type name (e.g. "cool", "tough") — mirrors the
/// backend's `/moves?contest_type=` param. Not yet exposed in the UI.
final movesContestTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Filter to only Z-moves (true) or only non-Z-moves (false) — mirrors the
/// backend's `/moves?is_z_move=` param. Not yet exposed in the UI.
final movesIsZMoveFilterProvider = StateProvider<bool?>((ref) => null);

/// Filter to only Max/G-max moves (true) or only non-Max moves (false) —
/// mirrors the backend's `/moves?is_max_move=` param. Not yet exposed in the UI.
final movesIsMaxMoveFilterProvider = StateProvider<bool?>((ref) => null);

/// Move names for a given type — fetched from /type/{name}, cached 7 days.
/// Still used by the retry callback in MovesScreen; type filtering is now
/// client-side on backend entries for the filtered provider.
final movesByTypeProvider =
    FutureProvider.family<List<String>, String>((ref, typeName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMovesByType(typeName);
});

/// Filtered move names derived client-side from the backend entry list.
final filteredMovesProvider = Provider<AsyncValue<List<BackendMoveEntry>>>((ref) {
  final typeFilter = ref.watch(movesTypeFilterProvider);
  final damageClassFilter = ref.watch(movesDamageClassFilterProvider);
  final genFilter = ref.watch(movesGenFilterProvider);
  final contestTypeFilter = ref.watch(movesContestTypeFilterProvider);
  final isZMoveFilter = ref.watch(movesIsZMoveFilterProvider);
  final isMaxMoveFilter = ref.watch(movesIsMaxMoveFilterProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();

  final listAsync = ref.watch(movesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<BackendMoveEntry> entries = List.of(listAsync.requireValue);

  if (typeFilter != null) {
    entries = entries.where((e) => e.type == typeFilter).toList();
  }
  if (damageClassFilter != null) {
    entries = entries.where((e) => e.damageClass == damageClassFilter).toList();
  }
  if (genFilter != null) {
    entries = entries.where((e) => e.gen == genFilter).toList();
  }
  if (contestTypeFilter != null) {
    entries = entries.where((e) => e.contestType == contestTypeFilter).toList();
  }
  if (isZMoveFilter != null) {
    entries = entries.where((e) => e.isZMove == isZMoveFilter).toList();
  }
  if (isMaxMoveFilter != null) {
    entries = entries.where((e) => e.isMaxMove == isMaxMoveFilter).toList();
  }
  if (search.isNotEmpty) {
    entries = entries
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  // Mirrors the backend's `list_moves` (`values.sort(key=lambda m: m.name)`,
  // catalog_service.py:477) — the backend always sorts by name before
  // pagination, so online display order is alphabetical purely as an
  // artifact of that sort + naive page concatenation. The offline builder's
  // enumeration order instead follows PokéAPI's own `/move` list (roughly
  // numeric ID order), so without this explicit sort, move order would
  // visibly differ between online and offline.
  entries.sort((a, b) => a.name.compareTo(b.name));

  return AsyncValue.data(entries);
});

/// Single move entry from the backend catalog — used by the detail screen to
/// read catalog-enriched fields (e.g. damage_class='varies') that PokéAPI's
/// own move resource doesn't carry.
final catalogMoveProvider =
    FutureProvider.autoDispose.family<BackendMoveEntry, String>((ref, name) {
  return withBackendFallback<BackendMoveEntry>(
    cacheKey: 'catalog_move_$name',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () =>
        ref.read(pokemonBackendRepositoryProvider).fetchCatalogMove(name),
    offlineFallback: () => buildOfflineMoveEntry(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
      name,
    ),
    fromJson: BackendMoveEntry.fromJson,
    toJson: (move) => move.toJson(),
  );
});

/// Fetches a machine's item name and URL by the machine's full PokéAPI URL.
final machineProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>(
        (ref, url) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMachineByUrl(url);
});

/// Fetches Gen III regular contest effect data (appeal + jam + effect text).
final contestEffectProvider =
    FutureProvider.autoDispose.family<ContestEffectData, String>(
        (ref, url) async {
  return ref.read(pokeApiRepositoryProvider).fetchContestEffect(url);
});

/// Fetches Gen IV super contest effect data (appeal + flavor text).
final superContestEffectProvider =
    FutureProvider.autoDispose.family<SuperContestEffectData, String>(
        (ref, url) async {
  return ref.read(pokeApiRepositoryProvider).fetchSuperContestEffect(url);
});
