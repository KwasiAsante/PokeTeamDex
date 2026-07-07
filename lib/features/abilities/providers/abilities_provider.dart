import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Maps PokéAPI generation names (as stored in abilityGenerationFilterProvider)
/// to the integer gen field used by the backend.
const _kGenNameToInt = <String, int>{
  'generation-i': 1,
  'generation-ii': 2,
  'generation-iii': 3,
  'generation-iv': 4,
  'generation-v': 5,
  'generation-vi': 6,
  'generation-vii': 7,
  'generation-viii': 8,
  'generation-ix': 9,
};

/// Backend-first full ability catalog. Falls back to PokéAPI name list on failure.
/// Fallback entries use gen == 0 as a sentinel; the filtered provider passes
/// sentinel entries through all gen filters to preserve usability when offline.
final abilitiesListProvider =
    FutureProvider<List<BackendAbilityEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogAbilities(pageSize: 1000);
    AppLogger().d('[catalog] abilities: loaded ${result.total} entries from backend');
    return result.items;
  } catch (e) {
    AppLogger().w('[catalog] abilities backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchAbilityList();
    return names.map(BackendAbilityEntry.fromName).toList();
  }
});

// Not autoDispose — persists across tab switches.
final abilitiesSearchProvider = StateProvider<String>((ref) => '');

// ── Filtering & sorting ───────────────────────────────────────────────────────

enum AbilitySort { nameAZ, nameZA }

/// Selected generation filter (null = all). Value is the PokéAPI gen name
/// e.g. "generation-iii". Abilities start from Gen III.
final abilityGenerationFilterProvider = StateProvider<String?>((ref) => null);

/// Sort direction.
final abilitySortProvider =
    StateProvider<AbilitySort>((ref) => AbilitySort.nameAZ);

/// Generation options shown as filter chips (gen name → display label).
const kAbilityGenerations = <String, String>{
  'generation-iii': 'Gen III',
  'generation-iv':  'Gen IV',
  'generation-v':   'Gen V',
  'generation-vi':  'Gen VI',
  'generation-vii': 'Gen VII',
  'generation-viii':'Gen VIII',
  'generation-ix':  'Gen IX',
};

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredAbilitiesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final genFilter = ref.watch(abilityGenerationFilterProvider);
  final sort      = ref.watch(abilitySortProvider);
  final search    = ref.watch(abilitiesSearchProvider).trim().toLowerCase();

  final listAsync = ref.watch(abilitiesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<BackendAbilityEntry> entries = List.of(listAsync.requireValue);

  if (genFilter != null) {
    final genInt = _kGenNameToInt[genFilter];
    if (genInt != null) {
      // gen == 0 is the PokéAPI fallback sentinel — pass it through.
      entries = entries
          .where((e) => e.gen == 0 || e.gen == genInt)
          .toList();
    }
  }
  if (search.isNotEmpty) {
    entries = entries
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  List<String> names = entries.map((e) => e.name).toList();

  switch (sort) {
    case AbilitySort.nameAZ:
      names.sort();
    case AbilitySort.nameZA:
      names.sort((a, b) => b.compareTo(a));
  }

  return AsyncValue.data(names);
});
