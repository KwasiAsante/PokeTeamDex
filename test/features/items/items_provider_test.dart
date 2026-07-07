import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

void main() {
  late MockPokemonBackendRepository mockBackend;
  late MockPokeApiRepository mockPokeApi;

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
      ]);

  test('itemsListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendItemEntry.fromJson({
                  'name': 'leftovers', 'display_name': 'Leftovers',
                  'gen': 2, 'is_berry': false, 'is_mega_stone': false,
                  'is_z_crystal': false, 'is_plate': false, 'is_memory': false,
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(itemsListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'leftovers');
  });

  test('itemsListProvider falls back to PokéAPI on backend failure', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchItemList())
        .thenAnswer((_) async => ['leftovers', 'master-ball']);

    final container = makeContainer();
    final result = await container.read(itemsListProvider.future);
    expect(result.length, 2);
    expect(result[0].name, 'leftovers');
    expect(result[0].gen, 0); // sentinel
  });

  test('filteredItemsProvider applies name search', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendItemEntry.fromName('leftovers'),
                BackendItemEntry.fromName('master-ball'),
              ],
              total: 2, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    await container.read(itemsListProvider.future);
    container.read(itemsSearchProvider.notifier).state = 'left';
    final filtered = container.read(filteredItemsProvider);
    expect(filtered.requireValue, ['leftovers']);
  });
}
