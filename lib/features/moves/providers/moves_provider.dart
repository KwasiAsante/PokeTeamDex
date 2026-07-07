import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Backend-first full move catalog. Falls back to PokéAPI name list on failure.
/// Fallback entries use sentinel values (type == '', damageClass == '') — the
/// filtered provider treats those as "no metadata, pass all filters".
final movesListProvider = FutureProvider<List<BackendMoveEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogMoves(pageSize: 1000);
    AppLogger().d('[catalog] moves: loaded ${result.total} entries from backend');
    return result.items;
  } catch (e) {
    AppLogger().w('[catalog] moves backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchMoveList();
    return names.map(BackendMoveEntry.fromName).toList();
  }
});

// Persists across tab switches.
final movesSearchProvider = StateProvider<String>((ref) => '');
final movesDamageClassFilterProvider = StateProvider<String?>((ref) => null);
final movesTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Move names for a given type — fetched from /type/{name}, cached 7 days.
/// Still used by the retry callback in MovesScreen; type filtering is now
/// client-side on backend entries for the filtered provider.
final movesByTypeProvider =
    FutureProvider.family<List<String>, String>((ref, typeName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMovesByType(typeName);
});

/// Filtered move names derived client-side from the backend entry list.
///
/// Type and damage class filters use entry metadata when available (gen > 0).
/// Fallback entries (gen == 0, type == '') pass all filters to preserve usability
/// when the backend is unavailable.
final filteredMovesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final typeFilter = ref.watch(movesTypeFilterProvider);
  final damageClassFilter = ref.watch(movesDamageClassFilterProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();

  final listAsync = ref.watch(movesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<BackendMoveEntry> entries = List.of(listAsync.requireValue);

  // Empty type/damageClass == sentinel (PokéAPI fallback) — skip that filter.
  if (typeFilter != null) {
    entries = entries
        .where((e) => e.type.isEmpty || e.type == typeFilter)
        .toList();
  }
  if (damageClassFilter != null) {
    entries = entries
        .where((e) => e.damageClass.isEmpty || e.damageClass == damageClassFilter)
        .toList();
  }
  if (search.isNotEmpty) {
    entries = entries
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  return AsyncValue.data(entries.map((e) => e.name).toList());
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
