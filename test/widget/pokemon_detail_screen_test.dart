import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_screen.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

class MockPokeApiRepository extends Mock implements PokeApiRepository {}
class _MockBackendRepo extends Mock implements PokemonBackendRepository {}
class _MockBox extends Mock implements Box {}

PokemonEntry _testEntry() => PokemonEntry(
      id: 25,
      name: 'pikachu',
      height: 4,
      weight: 60,
      types: ['electric'],
      stats: {
        'hp': 35,
        'attack': 55,
        'defense': 40,
        'special-attack': 50,
        'special-defense': 50,
        'speed': 90,
      },
    );

const _testSpecies = PokemonSpeciesEntry(
  id: 25,
  name: 'pikachu',
  genus: 'Mouse Pokémon',
  eggGroups: ['fairy', 'field'],
  flavorTextEntries: [],
  varieties: [],
);

void main() {
  late MockPokeApiRepository mockApi;
  late _MockBackendRepo mockBackend;
  late _MockBox mockBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
    registerFallbackValue('');
    registerFallbackValue(0);
  });

  setUp(() {
    mockApi = MockPokeApiRepository();
    mockBackend = _MockBackendRepo();
    mockBox = _MockBox();

    when(() => mockApi.fetchPokemon(any())).thenAnswer((_) async => _testEntry());
    when(() => mockApi.fetchPokemonSpecies(any())).thenAnswer((_) async => _testSpecies);
    when(() => mockApi.fetchPokemonByName(any())).thenAnswer((_) async => _testEntry());
    when(() => mockApi.fetchPokemonEncounters(any())).thenAnswer((_) async => []);

    // Cache always misses; backend always throws → provider falls back to PokéAPI path.
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockBackend.fetchResolved(any()))
        .thenThrow(Exception('test: backend disabled'));
  });

  List<dynamic> overrides() => [
        pokeApiRepositoryProvider.overrideWithValue(mockApi),
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        backendFallbackBoxProvider.overrideWithValue(mockBox),
        backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
      ];

  group('PokemonDetailScreen', () {
    testWidgets('renders without crashing', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(
        tester,
        const PokemonDetailScreen(pokemonId: 25),
        db: db,
        extraOverrides: overrides(),
      );
      await tester.pumpAndSettle();

      // If it renders, we're good — no exceptions thrown
      expect(find.byType(PokemonDetailScreen), findsOneWidget);

      // Dispose widget tree inside test body so drift stream-cleanup timers
      // fire before the framework's _verifyInvariants() check.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows pokemon name after data loads', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(
        tester,
        const PokemonDetailScreen(pokemonId: 25),
        db: db,
        extraOverrides: overrides(),
      );
      await tester.pumpAndSettle();

      // Pokemon name should appear in the AppBar or the Overview tab
      expect(find.textContaining('Pikachu', findRichText: true), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows tab bar for navigation between sections', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(
        tester,
        const PokemonDetailScreen(pokemonId: 25),
        db: db,
        extraOverrides: overrides(),
      );
      await tester.pumpAndSettle();

      // Detail screen should show multiple tabs / sections
      // At minimum, Overview should be present
      expect(find.textContaining('Overview', findRichText: true), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows stats section in Overview tab', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(
        tester,
        const PokemonDetailScreen(pokemonId: 25),
        db: db,
        extraOverrides: overrides(),
      );
      await tester.pumpAndSettle();

      // The Stats tab or overview section should exist
      expect(find.textContaining('Stats', findRichText: true), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
