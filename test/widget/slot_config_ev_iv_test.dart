import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_config_screen.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

PokemonEntry _entry() => PokemonEntry(
      id: 6,
      name: 'charizard',
      height: 17,
      weight: 905,
      types: {1: 'fire', 2: 'flying'},
      stats: [
        {'base_stat': 78, 'stat': {'name': 'hp'}},
        {'base_stat': 84, 'stat': {'name': 'attack'}},
        {'base_stat': 78, 'stat': {'name': 'defense'}},
        {'base_stat': 109, 'stat': {'name': 'special-attack'}},
        {'base_stat': 85, 'stat': {'name': 'special-defense'}},
        {'base_stat': 100, 'stat': {'name': 'speed'}},
      ],
      abilities: [
        {'ability': {'name': 'blaze'}, 'is_hidden': false, 'slot': 1},
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
  late MockPokeApiRepository mockApi;

  setUp(() {
    mockApi = MockPokeApiRepository();
    when(() => mockApi.fetchPokemon(any())).thenAnswer((_) async => _entry());
    when(() => mockApi.fetchPokemonSpecies(any())).thenAnswer((_) async => _species);
    when(() => mockApi.fetchPokemonByName(any())).thenAnswer((_) async => _entry());
    when(() => mockApi.fetchPokemonEncounters(any())).thenAnswer((_) async => []);
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
