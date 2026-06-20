import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
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

  group('fetchResolved', () {
    test('returns PokemonResolvedBackendResponse on 200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/6/resolved',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _minimalResolvedJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/6/resolved'),
              ));

      final result = await repo.fetchResolved(6);
      expect(result.pokemonId, 6);
      expect(result.name, 'charizard');
    });

    test('throws on non-200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/6/resolved',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 404,
                requestOptions: RequestOptions(path: '/pokemon/6/resolved'),
              ));

      expect(() => repo.fetchResolved(6), throwsException);
    });
  });

  group('fetchMoves', () {
    test('returns List<MoveSummary> on 200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/moves/6'))
          .thenAnswer((_) async => Response(
                data: {
                  'pokemon_id': 6,
                  'name': 'charizard',
                  'moves': [
                    {
                      'name': 'flamethrower',
                      'learn_details': [
                        {'version_group': 'sword-shield', 'method': 'machine', 'level': 0}
                      ],
                    }
                  ],
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/moves/6'),
              ));

      final moves = await repo.fetchMoves(6);
      expect(moves.length, 1);
      expect(moves[0].name, 'flamethrower');
    });
  });

  group('fetchFlavorText', () {
    test('returns List<FlavorTextEntry> filtered by lang', () async {
      when(() => mockDio.get<dynamic>('/pokemon/flavor-text/6',
              queryParameters: {'lang': 'en'}))
          .thenAnswer((_) async => Response(
                data: {
                  'pokemon_id': 6,
                  'name': 'charizard',
                  'flavor_text_entries': [
                    {'text': 'Spits fire.', 'language': 'en', 'version': 'red'}
                  ],
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/flavor-text/6'),
              ));

      final entries = await repo.fetchFlavorText(6, lang: 'en');
      expect(entries.length, 1);
      expect(entries[0].text, 'Spits fire.');
    });
  });
}

Map<String, dynamic> _minimalResolvedJson() => {
  'pokemon_id': 6, 'gen': 9, 'name': 'charizard',
  'types': ['Fire', 'Flying'],
  'base_stats': {'hp': 78, 'attack': 84, 'defense': 78,
                 'special-attack': 109, 'special-defense': 85, 'speed': 100},
  'abilities': [{'name': 'blaze', 'is_hidden': false, 'slot': 1}],
  'height': 17, 'weight': 905, 'base_experience': 240,
  'species_name': 'charizard', 'moves': [], 'moves_url': null,
  'supplement_moves': [], 'smogon_analyses': null,
  'varieties': [], 'varieties_url': null,
  'forms': [{'name': 'charizard', 'form_id': 6, 'is_default': true,
             'front_sprite_url': null, 'sprite_urls': null}],
  'forms_url': null,
  'sprite_urls': {'official_artwork': null, 'official_artwork_shiny': null,
                  'home': null, 'home_shiny': null, 'home_female': null,
                  'home_female_shiny': null, 'game_front': null,
                  'game_front_shiny': null, 'game_front_female': null,
                  'game_front_female_shiny': null},
  'resolved_at': '2026-06-18T12:00:00Z',
  'genus': 'Flame Pokémon', 'generation_name': 'generation-i',
  'gender_rate': 1, 'capture_rate': 45, 'base_happiness': 70,
  'hatch_counter': 20, 'growth_rate': 'medium-slow',
  'egg_groups': ['monster', 'dragon'], 'flavor_text_entries': [],
  'flavor_text_url': null, 'is_baby': false,
  'is_legendary': false, 'is_mythical': false, 'evolution_chain_id': 2,
};
