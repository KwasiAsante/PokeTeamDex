import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

class MockBox extends Mock implements Box {}

void main() {
  late MockPokemonBackendRepository mockBackend;
  late MockPokeApiRepository mockPokeApi;
  late MockBox mockBox;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
    mockBox = MockBox();
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({bool online = true}) =>
      ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
        backendFallbackBoxProvider.overrideWithValue(mockBox),
        backendFallbackIsOnlineProvider.overrideWithValue(() async => online),
      ]);

  test('abilitiesListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendAbilityEntry.fromJson({
                  'name': 'blaze', 'display_name': 'Blaze',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(abilitiesListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'blaze');
    expect(result[0].gen, 3);
  });

  test('abilitiesListProvider falls back to offline PokéAPI+PS merge on backend failure', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchAbilityList())
        .thenAnswer((_) async => ['blaze']);
    when(() => mockPokeApi.fetchAbility('blaze')).thenAnswer((_) async => const AbilityEntry(
          name: 'blaze',
          generationName: 'generation-iii',
        ));

    final container = makeContainer();
    final result = await container.read(abilitiesListProvider.future);
    final blaze = result.firstWhere((e) => e.name == 'blaze');
    expect(blaze.gen, 3);
  });

  test('filteredAbilitiesProvider filters by gen client-side', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendAbilityEntry.fromJson({
                  'name': 'blaze', 'display_name': 'Blaze',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'intimidate', 'display_name': 'Intimidate',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'flash-fire', 'display_name': 'Flash Fire',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'moody', 'display_name': 'Moody',
                  'gen': 5, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
              ],
              total: 4, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    await container.read(abilitiesListProvider.future);
    container.read(abilityGenerationFilterProvider.notifier).state = 'generation-v';
    final filtered = container.read(filteredAbilitiesProvider);
    expect(filtered.requireValue.map((e) => e.name).toList(), ['moody']);
  });
}
