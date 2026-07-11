import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/catalog/catalog_offline_merge.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_providers.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

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

/// Backend-first full ability catalog. Falls back to a full offline
/// PokéAPI+PS-data merge (see [buildOfflineAbilityCatalog]) when the backend
/// and cache are both unavailable.
final abilitiesListProvider =
    FutureProvider<List<BackendAbilityEntry>>((ref) async {
  ref.keepAlive();
  return withBackendFallback<List<BackendAbilityEntry>>(
    cacheKey: 'catalog_abilities',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () async {
      final repo = ref.read(pokemonBackendRepositoryProvider);
      final first = await repo.fetchCatalogAbilities(pageSize: 1000);
      var items = first.items;
      if (first.totalPages > 1) {
        final rest = await Future.wait([
          for (int p = 2; p <= first.totalPages; p++)
            repo.fetchCatalogAbilities(page: p, pageSize: 1000),
        ]);
        items = [...items, for (final r in rest) ...r.items];
      }
      return items;
    },
    offlineFallback: () => buildOfflineAbilityCatalog(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
    ),
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((a) => BackendAbilityEntry.fromJson(a as Map<String, dynamic>))
        .toList(),
    toJson: (abilities) => {'items': abilities.map((a) => a.toJson()).toList()},
  );
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

final filteredAbilitiesProvider = Provider<AsyncValue<List<BackendAbilityEntry>>>((ref) {
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
      entries = entries
          .where((e) => e.gen == genInt)
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

  switch (sort) {
    case AbilitySort.nameAZ:
      entries.sort((a, b) => a.name.compareTo(b.name));
    case AbilitySort.nameZA:
      entries.sort((a, b) => b.name.compareTo(a.name));
  }

  return AsyncValue.data(entries);
});

/// Single ability from the backend catalog — used for inline display in the
/// Pokémon detail screen where only effect text and gen label are needed.
final catalogAbilityProvider =
    FutureProvider.autoDispose.family<BackendAbilityEntry, String>((ref, name) {
  return withBackendFallback<BackendAbilityEntry>(
    cacheKey: 'catalog_ability_$name',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () =>
        ref.read(pokemonBackendRepositoryProvider).fetchCatalogAbility(name),
    offlineFallback: () => buildOfflineAbilityEntry(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
      name,
    ),
    fromJson: BackendAbilityEntry.fromJson,
    toJson: (ability) => ability.toJson(),
  );
});

/// A Pokémon's own 2-3 abilities (with `slot`/`isHidden` per entry) via the
/// backend's `/abilities?pokemon=` variant — distinct from
/// [abilitiesListProvider]'s full paginated catalog. Not currently called
/// from any screen (per-Pokémon ability display goes through
/// [resolveGenAccuratePokedexData]/`resolvedPokemonProvider` instead), but
/// built for full endpoint-surface parity — see [buildOfflineAbilitiesForPokemon].
final abilitiesForPokemonProvider = FutureProvider.autoDispose
    .family<List<BackendAbilityEntry>, String>((ref, pokemon) {
  return withBackendFallback<List<BackendAbilityEntry>>(
    cacheKey: 'catalog_abilities_for_$pokemon',
    box: ref.read(backendFallbackBoxProvider),
    isOnline: ref.read(backendFallbackIsOnlineProvider),
    backendCall: () async {
      final response = await ref
          .read(pokemonBackendRepositoryProvider)
          .fetchCatalogAbilities(pokemon: pokemon, pageSize: 10);
      return response.items;
    },
    offlineFallback: () => buildOfflineAbilitiesForPokemon(
      ref.read(pokeApiRepositoryProvider),
      ref.read(psDataServiceProvider),
      pokemon,
    ),
    fromJson: (json) => (json['items'] as List<dynamic>)
        .map((a) => BackendAbilityEntry.fromJson(a as Map<String, dynamic>))
        .toList(),
    toJson: (abilities) => {'items': abilities.map((a) => a.toJson()).toList()},
  );
});
