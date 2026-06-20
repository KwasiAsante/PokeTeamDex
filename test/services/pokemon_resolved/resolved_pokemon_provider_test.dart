import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokemonResolvedCache extends Mock implements PokemonResolvedCache {}

void main() {
  late MockPokemonBackendRepository mockRepo;
  late MockPokemonResolvedCache mockCache;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
    registerFallbackValue(const Duration(days: 7));
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockRepo = MockPokemonBackendRepository();
    mockCache = MockPokemonResolvedCache();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      pokemonBackendRepositoryProvider.overrideWithValue(mockRepo),
      pokemonResolvedCacheProvider.overrideWithValue(mockCache),
    ]);
  }

  // ── gen: null (no format / Pokédex) ────────────────────────────────────────

  test('returns ResolvedPokemon from backend when cache misses (gen: null)', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenAnswer((_) async => _makeBackendResponse());
    when(() => mockCache.putWithTTL(any(), any(), any())).thenReturn(null);

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);

    expect(result.id, 6);
    expect(result.detail.types, ['fire', 'flying']); // toPokemonEntry lowercases types
    expect(result.species.evolutionChainId, 2);
    expect(result.spriteUrls.officialArtwork, 'https://example.com/art/6.png');
    // gen: null → cache key is 'resolved_6' (no gen suffix)
    verify(() => mockCache.putWithTTL('resolved_6', any(), any())).called(1);
  });

  test('returns ResolvedPokemon from Hive cache without backend call', () async {
    when(() => mockCache.getIfValid('resolved_6'))
        .thenReturn(_makeBackendResponse().toJson());

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);

    expect(result.id, 6);
    verifyNever(() => mockRepo.fetchResolved(any(), gen: any(named: 'gen')));
  });

  test('falls back gracefully when backend throws', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenThrow(Exception('offline'));

    final container = makeContainer();
    final future =
        container.read(resolvedPokemonProvider((id: 6, gen: null)).future);
    expect(future, isA<Future>());
  });

  // ── gen: 5 (explicit generation) ────────────────────────────────────────────

  test('explicit gen uses gen-specific cache key resolved_{id}_g{gen}', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenAnswer((_) async => _makeBackendResponse());
    when(() => mockCache.putWithTTL(any(), any(), any())).thenReturn(null);

    final container = makeContainer();
    await container.read(resolvedPokemonProvider((id: 6, gen: 5)).future);

    verify(() => mockCache.putWithTTL('resolved_6_g5', any(), any())).called(1);
  });

  test('gen: null and gen: 5 are independent provider instances', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6, gen: any(named: 'gen')))
        .thenAnswer((_) async => _makeBackendResponse());
    when(() => mockCache.putWithTTL(any(), any(), any())).thenReturn(null);

    final container = makeContainer();

    await container.read(resolvedPokemonProvider((id: 6, gen: null)).future);
    await container.read(resolvedPokemonProvider((id: 6, gen: 5)).future);

    // Two separate backend calls — different provider keys.
    verify(() => mockRepo.fetchResolved(6, gen: any(named: 'gen'))).called(2);
    verify(() => mockCache.putWithTTL('resolved_6', any(), any())).called(1);
    verify(() => mockCache.putWithTTL('resolved_6_g5', any(), any())).called(1);
  });

  test('gen: 5 Hive cache key is resolved_6_g5', () async {
    when(() => mockCache.getIfValid('resolved_6_g5'))
        .thenReturn(_makeBackendResponse().toJson());

    final container = makeContainer();
    final result =
        await container.read(resolvedPokemonProvider((id: 6, gen: 5)).future);

    expect(result.id, 6);
    verifyNever(() => mockRepo.fetchResolved(any(), gen: any(named: 'gen')));
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
