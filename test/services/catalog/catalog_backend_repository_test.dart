import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';

class MockDio extends Mock implements Dio {}
class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late PokemonBackendRepository repo;

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    repo = PokemonBackendRepository(mockApiClient);
  });

  group('fetchCatalogMoves', () {
    test('returns PaginatedCatalogResponse<BackendMoveEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/moves',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _movesListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/moves'),
              ));

      final result = await repo.fetchCatalogMoves(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'thunderbolt');
      expect(result.items[0].type, 'electric');
      expect(result.total, 1);
    });

    test('throws on non-200', () async {
      when(() => mockDio.get<dynamic>('/moves',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 500,
                requestOptions: RequestOptions(path: '/moves'),
              ));

      expect(() => repo.fetchCatalogMoves(), throwsException);
    });
  });

  group('fetchCatalogMove', () {
    test('returns BackendMoveEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/moves/thunderbolt',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _moveEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/moves/thunderbolt'),
              ));

      final result = await repo.fetchCatalogMove('thunderbolt');
      expect(result.name, 'thunderbolt');
      expect(result.power, 90);
    });
  });

  group('fetchCatalogItems', () {
    test('returns PaginatedCatalogResponse<BackendItemEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/items',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _itemsListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/items'),
              ));

      final result = await repo.fetchCatalogItems(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'leftovers');
      expect(result.items[0].isBerry, false);
    });
  });

  group('fetchCatalogItem', () {
    test('returns BackendItemEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/items/leftovers',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _itemEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/items/leftovers'),
              ));

      final result = await repo.fetchCatalogItem('leftovers');
      expect(result.name, 'leftovers');
      expect(result.gen, 2);
    });
  });

  group('fetchCatalogAbilities', () {
    test('returns PaginatedCatalogResponse<BackendAbilityEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/abilities',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _abilitiesListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/abilities'),
              ));

      final result = await repo.fetchCatalogAbilities(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'blaze');
      expect(result.items[0].gen, 3);
    });
  });

  group('fetchCatalogAbility', () {
    test('returns BackendAbilityEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/abilities/blaze',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _abilityEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/abilities/blaze'),
              ));

      final result = await repo.fetchCatalogAbility('blaze');
      expect(result.name, 'blaze');
    });
  });
}

Map<String, dynamic> _movesListJson() => {
  'items': [_moveEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _moveEntryJson() => {
  'name': 'thunderbolt', 'display_name': 'Thunderbolt',
  'gen': 1, 'type': 'electric', 'damage_class': 'special',
  'power': 90, 'accuracy': 100, 'pp': 15, 'priority': 0,
  'is_z_move': false, 'is_max_move': false, 'flags': {},
};

Map<String, dynamic> _itemsListJson() => {
  'items': [_itemEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _itemEntryJson() => {
  'name': 'leftovers', 'display_name': 'Leftovers',
  'gen': 2, 'category': 'held-items', 'sprite': null,
  'fling_power': 10, 'is_mega_stone': false, 'mega_species': null,
  'is_z_crystal': false, 'is_berry': false, 'is_plate': false, 'is_memory': false,
};

Map<String, dynamic> _abilitiesListJson() => {
  'items': [_abilityEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _abilityEntryJson() => {
  'name': 'blaze', 'display_name': 'Blaze', 'gen': 3,
  'effect_short': 'Powers up Fire moves in a pinch.',
  'effect': null, 'slot': null, 'is_hidden': false,
};
