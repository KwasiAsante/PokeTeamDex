import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
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

  setUpAll(() {
    registerFallbackValue(1);
    registerFallbackValue('');
  });

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
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
  });

  test('movesListProvider falls back to PokéAPI name list on backend failure', () async {
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
        .thenAnswer((_) async => ['tackle', 'flamethrower']);

    final container = makeContainer();
    final result = await container.read(movesListProvider.future);
    expect(result.length, 2);
    expect(result[0].name, 'tackle');
    expect(result[0].type, ''); // sentinel — no metadata from PokéAPI fallback
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
    expect(filtered.requireValue, ['thunderbolt']);
  });

  test('filteredMovesProvider passes all entries when backend unavailable (sentinel type)', () async {
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

    final container = makeContainer();
    await container.read(movesListProvider.future);
    container.read(movesTypeFilterProvider.notifier).state = 'electric';
    final filtered = container.read(filteredMovesProvider);
    // Sentinel entries (type == '') pass the type filter
    expect(filtered.requireValue, ['tackle']);
  });
}
