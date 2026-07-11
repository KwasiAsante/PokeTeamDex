import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
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
    registerFallbackValue(1);
    registerFallbackValue('');
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

  test('movesListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendMoveEntry.fromJson({
                  'name': 'tackle', 'display_name': 'Tackle', 'gen': 1,
                  'type': 'normal', 'damage_class': 'physical',
                  'power': 40, 'accuracy': 100, 'pp': 35, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(movesListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'tackle');
    expect(result[0].type, 'normal');
    verify(() => mockBox.put('catalog_moves', any())).called(1);
  });

  test('movesListProvider falls back to offline PokéAPI+PS merge on backend failure', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchMoveList())
        .thenAnswer((_) async => ['tackle']);
    when(() => mockPokeApi.fetchMove('tackle')).thenAnswer((_) async => const MoveEntry(
          name: 'tackle',
          typeName: 'normal',
          damageClass: 'physical',
          power: 40,
          accuracy: 100,
          pp: 35,
        ));

    final container = makeContainer();
    final result = await container.read(movesListProvider.future);
    // The offline merge also appends PS-only entries (Z-moves, Max moves)
    // from the bundled shared/ps_data/moves.json, so assert on the entry we
    // control rather than the full list length.
    final tackle = result.firstWhere((e) => e.name == 'tackle');
    expect(tackle.type, 'normal');
    expect(tackle.damageClass, 'physical');
  });

  test('filteredMovesProvider filters by type client-side', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendMoveEntry.fromJson({
                  'name': 'tackle', 'display_name': 'Tackle', 'gen': 1,
                  'type': 'normal', 'damage_class': 'physical',
                  'power': 40, 'accuracy': 100, 'pp': 35, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
                BackendMoveEntry.fromJson({
                  'name': 'thunderbolt', 'display_name': 'Thunderbolt', 'gen': 1,
                  'type': 'electric', 'damage_class': 'special',
                  'power': 90, 'accuracy': 100, 'pp': 15, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
              ],
              total: 2, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    // Wait for list to load
    await container.read(movesListProvider.future);
    // Apply type filter
    container.read(movesTypeFilterProvider.notifier).state = 'electric';
    final filtered = container.read(filteredMovesProvider);
    expect(filtered.requireValue.map((e) => e.name).toList(), ['thunderbolt']);
  });
}
