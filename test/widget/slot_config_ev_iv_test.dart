import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_config_screen.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart'
    show AbilityInfo, PokemonResolvedBackendResponse;
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart'
    show pokemonBackendRepositoryProvider;
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

class MockPokeApiRepository extends Mock implements PokeApiRepository {}
class MockPokemonBackendRepository extends Mock implements PokemonBackendRepository {}
class MockBox extends Mock implements Box {}

PokemonEntry _entry() => PokemonEntry(
      id: 6,
      name: 'charizard',
      height: 17,
      weight: 905,
      types: ['fire', 'flying'],
      stats: {
        'hp': 78,
        'attack': 84,
        'defense': 78,
        'special-attack': 109,
        'special-defense': 85,
        'speed': 100,
      },
      abilities: [
        const AbilityInfo(name: 'blaze', isHidden: false, slot: 1),
      ],
    );

const _species = PokemonSpeciesEntry(
  id: 6,
  name: 'charizard',
  eggGroups: ['monster', 'dragon'],
  flavorTextEntries: [],
  varieties: [],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
    registerFallbackValue(const Duration());
  });

  late MockPokeApiRepository mockApi;
  late MockPokemonBackendRepository mockBackendRepo;
  late MockBox mockBox;

  setUp(() {
    mockApi = MockPokeApiRepository();
    when(() => mockApi.fetchPokemon(any())).thenAnswer((_) async => _entry());
    when(() => mockApi.fetchPokemonSpecies(any())).thenAnswer((_) async => _species);
    when(() => mockApi.fetchPokemonByName(any())).thenAnswer((_) async => _entry());
    when(() => mockApi.fetchPokemonEncounters(any())).thenAnswer((_) async => []);
    when(() => mockApi.fetchItemList()).thenAnswer((_) async => []);
    when(() => mockApi.fetchAbilityList()).thenAnswer((_) async => []);
    when(() => mockApi.fetchPriorEvoEntries(any())).thenAnswer((_) async => []);

    mockBackendRepo = MockPokemonBackendRepository();
    when(() => mockBackendRepo.fetchResolved(any(), gen: any(named: 'gen')))
        .thenAnswer((_) async =>
            PokemonResolvedBackendResponse.fromJson(_resolvedJson()));
    // catalogAbilityProvider/catalogItemProvider/catalogMoveProvider now have
    // an offline fallback (buildOfflineAbilityEntry/etc.) that calls
    // PsDataService.initialize() — rootBundle.loadString() for shared/ps_data/
    // never resolves inside a pumped widget-test frame in this environment
    // (see pokemon_detail_screen_test.dart), so leaving these unstubbed would
    // hang pumpAndSettle once the (also unstubbed, Mock-default-null) backend
    // call fails and the offline path kicks in. This test isn't exercising
    // catalog data, so just succeed the backend call directly.
    when(() => mockBackendRepo.fetchCatalogAbility(any())).thenAnswer(
        (_) async => const BackendAbilityEntry(name: 'blaze', displayName: 'Blaze', gen: 3));
    when(() => mockBackendRepo.fetchCatalogItem(any())).thenAnswer(
        (_) async => const BackendItemEntry(name: 'leftovers', displayName: 'Leftovers', gen: 2));
    when(() => mockBackendRepo.fetchCatalogMove(any())).thenAnswer(
        (_) async => const BackendMoveEntry(
            name: 'tackle', displayName: 'Tackle', gen: 1, type: 'normal', damageClass: 'physical'));

    // Hive is not initialized in tests — mock the cache box so providers
    // skip straight to the backend (which is itself mocked above).
    mockBox = MockBox();
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  /// Creates a team + slot in [db] and returns (teamId, slotId).
  Future<(int, int)> seedSlot(
    AppDatabase db, {
    int evHp = 0,
    int evAtk = 0,
    int evDef = 0,
    int evSpa = 0,
    int evSpd = 0,
    int evSpe = 0,
  }) async {
    final now = DateTime.now();
    final teamId = await db.into(db.teams).insert(
      TeamsCompanion(
        name: const Value('EV Test Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final slotId = await db.into(db.teamSlots).insert(
      TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(1),
        pokemonId: const Value(6), // charizard
        level: const Value(50),
        ivHp:  const Value(31),
        ivAtk: const Value(31),
        ivDef: const Value(31),
        ivSpa: const Value(31),
        ivSpd: const Value(31),
        ivSpe: const Value(31),
        evHp:  Value(evHp),
        evAtk: Value(evAtk),
        evDef: Value(evDef),
        evSpa: Value(evSpa),
        evSpd: Value(evSpd),
        evSpe: Value(evSpe),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return (teamId, slotId);
  }

  group('SlotConfigScreen — EV validation', () {
    testWidgets('renders without crashing when slot exists', (tester) async {
      final db = openTestDatabase();

      final (teamId, _) = await seedSlot(db);

      await pumpTestApp(
        tester,
        SlotConfigScreen(teamId: teamId, slotNumber: 1),
        db: db,
        extraOverrides: [
          pokeApiRepositoryProvider.overrideWithValue(mockApi),
          pokemonBackendRepositoryProvider.overrideWithValue(mockBackendRepo),
          backendFallbackBoxProvider.overrideWithValue(mockBox),
          backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      // Screen renders at all
      expect(find.byType(SlotConfigScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows Save button once slot data is loaded', (tester) async {
      final db = openTestDatabase();

      final (teamId, _) = await seedSlot(db);

      await pumpTestApp(
        tester,
        SlotConfigScreen(teamId: teamId, slotNumber: 1),
        db: db,
        extraOverrides: [
          pokeApiRepositoryProvider.overrideWithValue(mockApi),
          pokemonBackendRepositoryProvider.overrideWithValue(mockBackendRepo),
          backendFallbackBoxProvider.overrideWithValue(mockBox),
          backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('tapping Save with EV total > 510 shows error snackbar', (tester) async {
      final db = openTestDatabase();

      // Total: 252 + 252 + 10 = 514 (over the 510 cap)
      final (teamId, _) = await seedSlot(
        db,
        evHp: 252,
        evAtk: 252,
        evDef: 10,
      );

      await pumpTestApp(
        tester,
        SlotConfigScreen(teamId: teamId, slotNumber: 1),
        db: db,
        extraOverrides: [
          pokeApiRepositoryProvider.overrideWithValue(mockApi),
          pokemonBackendRepositoryProvider.overrideWithValue(mockBackendRepo),
          backendFallbackBoxProvider.overrideWithValue(mockBox),
          backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump(); // let snackbar appear

      expect(
        find.textContaining('EV total exceeds 510', findRichText: true),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('EV total row shows correct running total', (tester) async {
      final db = openTestDatabase();

      // EVs: 4 + 252 + 252 = 508 (within cap)
      final (teamId, _) = await seedSlot(
        db,
        evHp: 4,
        evSpa: 252,
        evSpe: 252,
      );

      await pumpTestApp(
        tester,
        SlotConfigScreen(teamId: teamId, slotNumber: 1),
        db: db,
        extraOverrides: [
          pokeApiRepositoryProvider.overrideWithValue(mockApi),
          pokemonBackendRepositoryProvider.overrideWithValue(mockBackendRepo),
          backendFallbackBoxProvider.overrideWithValue(mockBox),
          backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      // The EV total indicator shows "Total: 508 / 510"
      expect(find.textContaining('508'), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('SlotConfigScreen — IV display', () {
    testWidgets('shows default IVs (31) when slot has no explicit IVs', (tester) async {
      final db = openTestDatabase();

      final (teamId, _) = await seedSlot(db);

      await pumpTestApp(
        tester,
        SlotConfigScreen(teamId: teamId, slotNumber: 1),
        db: db,
        extraOverrides: [
          pokeApiRepositoryProvider.overrideWithValue(mockApi),
          pokemonBackendRepositoryProvider.overrideWithValue(mockBackendRepo),
          backendFallbackBoxProvider.overrideWithValue(mockBox),
          backendFallbackIsOnlineProvider.overrideWithValue(() async => true),
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      // The IV fields should be pre-populated with '31'
      final ivFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // At least some fields should have '31' as their value
      final controllers = ivFields.map((f) => f.controller?.text).toList();
      expect(controllers, contains('31'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}

Map<String, dynamic> _resolvedJson() => {
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
