import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

/// All regions → their location name lists. Fetched once, cached 7 days.
final regionLocationsProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchAllRegionLocations();
});

/// Currently selected region filter (null = all regions).
final locationRegionFilterProvider = StateProvider<String?>((ref) => null);

/// Current search string for the locations list.
final locationSearchProvider = StateProvider<String>((ref) => '');

/// Filtered list of (regionName, locationName) pairs for the list screen.
final filteredLocationsProvider =
    Provider<AsyncValue<List<(String region, String location)>>>((ref) {
  final regionsAsync = ref.watch(regionLocationsProvider);
  final regionFilter = ref.watch(locationRegionFilterProvider);
  final search = ref.watch(locationSearchProvider).trim().toLowerCase();

  return regionsAsync.whenData((regionMap) {
    final results = <(String, String)>[];

    for (final entry in regionMap.entries) {
      if (regionFilter != null && entry.key != regionFilter) continue;
      for (final loc in entry.value) {
        if (search.isEmpty || loc.replaceAll('-', ' ').contains(search)) {
          results.add((entry.key, loc));
        }
      }
    }
    return results;
  });
});

/// Detail for a single location (areas + region). Cached per name.
final locationDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchLocation(name);
});

/// Encounter data for a single location area. Cached per name.
final locationAreaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchLocationArea(name);
});
