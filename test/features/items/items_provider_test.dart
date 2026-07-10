import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
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

  test('itemsListProvider falls back to offline PokéAPI+PS merge on backend failure', () async {
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
        .thenAnswer((_) async => ['leftovers']);
    when(() => mockPokeApi.fetchItem('leftovers')).thenAnswer((_) async => const ItemEntry(
          name: 'leftovers',
          category: 'held-items',
        ));

    final container = makeContainer();
    final result = await container.read(itemsListProvider.future);
    final leftovers = result.firstWhere((e) => e.name == 'leftovers');
    expect(leftovers.category, 'held-items');
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
                BackendItemEntry.fromJson(
                    {'name': 'leftovers', 'display_name': 'Leftovers', 'gen': 2}),
                BackendItemEntry.fromJson(
                    {'name': 'master-ball', 'display_name': 'Master Ball', 'gen': 1}),
              ],
              total: 2, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    await container.read(itemsListProvider.future);
    container.read(itemsSearchProvider.notifier).state = 'left';
    final filtered = container.read(filteredItemsProvider);
    expect(filtered.requireValue.map((e) => e.name).toList(), ['leftovers']);
  });
}
