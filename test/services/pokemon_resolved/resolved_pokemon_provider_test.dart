import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

class MockBox extends Mock implements Box {}

void main() {
  late MockPokemonBackendRepository mockRepo;
  late MockPokeApiRepository mockPokeApi;
  late MockBox mockBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  setUp(() {
    mockRepo = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
    mockBox = MockBox();
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({bool online = true}) {
    return ProviderContainer(overrides: [
      pokemonBackendRepositoryProvider.overrideWithValue(mockRepo),
      pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
      backendFallbackBoxProvider.overrideWithValue(mockBox),
      backendFallbackIsOnlineProvider.overrideWithValue(() async => online),
    ]);
  }

  test('returns ResolvedPokemon from backend on success', () async {
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenAnswer((_) async => _makeBackendResponse());

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);

    expect(result.id, 6);
    expect(result.detail.types, ['fire', 'flying']); // toPokemonEntry lowercases types
    expect(result.species.evolutionChainId, 2);
    expect(result.spriteUrls.officialArtwork, 'https://example.com/art/6.png');
    verify(() => mockBox.put('resolved_6', any())).called(1);
  });

  test('serves cached data (within 24h grace) when backend fails', () async {
    final cachedResponse = _makeBackendResponse();
    when(() => mockBox.get('resolved_6')).thenReturn({
      'payload': _resolvedPokemonJsonFrom(cachedResponse),
      'expiresAt': DateTime.now().millisecondsSinceEpoch - 1000, // just expired
    });
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenThrow(Exception('backend down'));

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);

    expect(result.id, 6);
  });

  test('falls back to offline PokéAPI assembly when backend and cache both fail', () async {
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchPokemon(6)).thenAnswer((_) async => PokemonEntry(
          id: 6,
          name: 'charizard',
          speciesName: 'charizard',
          height: 17,
          weight: 905,
          types: ['fire', 'flying'],
          stats: {'hp': 78},
          formNames: ['charizard'],
        ));
    when(() => mockPokeApi.fetchPokemonSpecies(6)).thenAnswer((_) async => const PokemonSpeciesEntry(
          id: 6,
          name: 'charizard',
          eggGroups: [],
          flavorTextEntries: [],
          evolutionChainId: 2,
        ));
    when(() => mockPokeApi.fetchPokemonByName('charizard')).thenAnswer((_) async => PokemonEntry(
          id: 6,
          name: 'charizard',
          height: 17,
          weight: 905,
          types: ['fire', 'flying'],
          formNames: ['charizard'], // single form → cosmeticFormsProvider returns []
        ));

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);

    expect(result.id, 6);
    expect(result.species.evolutionChainId, 2);
  });

  test('explicit gen uses gen-specific cache key resolved_{id}_g{gen}', () async {
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenAnswer((_) async => _makeBackendResponse());

    final container = makeContainer();
    await container.read(resolvedPokemonProvider((id: 6, gen: 5)).future);

    verify(() => mockBox.put('resolved_6_g5', any())).called(1);
  });
}

PokemonResolvedBackendResponse _makeBackendResponse() =>
    PokemonResolvedBackendResponse.fromJson({
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
      'sprite_urls': {
        'official_artwork': 'https://example.com/art/6.png',
        'official_artwork_shiny': null, 'home': null, 'home_shiny': null,
        'home_female': null, 'home_female_shiny': null, 'game_front': null,
        'game_front_shiny': null, 'game_front_female': null,
        'game_front_female_shiny': null,
      },
      'resolved_at': '2026-06-18T12:00:00Z',
      'genus': 'Flame Pokémon', 'generation_name': 'generation-i',
      'gender_rate': 1, 'capture_rate': 45, 'base_happiness': 70,
      'hatch_counter': 20, 'growth_rate': 'medium-slow',
      'egg_groups': ['monster', 'dragon'], 'flavor_text_entries': [],
      'flavor_text_url': null, 'is_baby': false,
      'is_legendary': false, 'is_mythical': false, 'evolution_chain_id': 2,
    });

/// Mirrors what [resolvedPokemonProvider]'s `_fromBackendResponse` +
/// `ResolvedPokemon.toJson` produce, for pre-seeding the mock cache.
Map<String, dynamic> _resolvedPokemonJsonFrom(PokemonResolvedBackendResponse r) {
  final detail = r.toPokemonEntry();
  final species = r.toPokemonSpeciesEntry();
  return {
    'detail': detail.toJson(),
    'species': species.toCacheJson(),
    'cosmetic_forms': [],
    'sprite_urls': r.spriteUrls.toJson(),
    'supplement_moves': [],
    'smogon_analyses': null,
  };
}
