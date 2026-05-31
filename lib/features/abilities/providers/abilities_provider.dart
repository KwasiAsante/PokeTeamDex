import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final abilitiesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchAbilityList();
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

/// Abilities introduced in a specific generation.
final abilitiesByGenerationProvider =
    FutureProvider.family<List<String>, String>((ref, genName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchAbilitiesByGeneration(genName);
});

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredAbilitiesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final gen    = ref.watch(abilityGenerationFilterProvider);
  final sort   = ref.watch(abilitySortProvider);
  final search = ref.watch(abilitiesSearchProvider).trim().toLowerCase();

  final AsyncValue<List<String>> listAsync = gen != null
      ? ref.watch(abilitiesByGenerationProvider(gen))
      : ref.watch(abilitiesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
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
    case AbilitySort.nameAZ:
      items.sort();
    case AbilitySort.nameZA:
      items.sort((a, b) => b.compareTo(a));
  }

  return AsyncValue.data(items);
});
