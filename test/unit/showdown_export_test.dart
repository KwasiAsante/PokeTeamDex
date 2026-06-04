import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/services/showdown_export.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

// Minimal TeamSlot factory — only fields used by buildShowdownExport matter.
TeamSlot _slot({
  required int id,
  required int slot,
  required int teamId,
  required int pokemonId,
  String? nickname,
  String? abilityName,
  String? natureName,
  String? heldItemName,
  bool isShiny = false,
  int level = 50,
  String? move1,
  String? move2,
  String? move3,
  String? move4,
  int? evHp,
  int? evAtk,
  int? evDef,
  int? evSpa,
  int? evSpd,
  int? evSpe,
}) =>
    TeamSlot(
      id: id,
      teamId: teamId,
      slot: slot,
      pokemonId: pokemonId,
      nickname: nickname,
      abilityName: abilityName,
      natureName: natureName,
      heldItemName: heldItemName,
      isShiny: isShiny,
      level: level,
      move1: move1,
      move2: move2,
      move3: move3,
      move4: move4,
      evHp: evHp,
      evAtk: evAtk,
      evDef: evDef,
      evSpa: evSpa,
      evSpd: evSpd,
      evSpe: evSpe,
      // Required fields with defaults
      syncStatus: 'synced',
      isDeleted: false,
      isMegaEvolved: false,
      hasGigantamax: false,
      gigantamaxEnabled: false,
      isAlpha: false,
      updatedAt: DateTime(2024),
      createdAt: DateTime(2024),
    );

PokemonEntry _pokemon(String name) => PokemonEntry(
      id: 1,
      name: name,
      height: 10,
      weight: 100,
      types: {1: 'normal'},
    );

void main() {
  late MockPokeApiRepository mockApi;

  setUp(() {
    mockApi = MockPokeApiRepository();
  });

  group('buildShowdownExport', () {
    test('no nickname — species name used as header', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(id: 1, slot: 1, teamId: 1, pokemonId: 25);
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, startsWith('Pikachu'));
    });

    test('nickname different from species — "Nickname (Species)"', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25, nickname: 'Sparky',
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, startsWith('Sparky (Pikachu)'));
    });

    test('nickname matching species (case-insensitive) — no nickname prefix', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25, nickname: 'Pikachu',
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, startsWith('Pikachu'));
      expect(result, isNot(contains('(Pikachu)')));
    });

    test('held item appended to header with @ separator', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25,
        heldItemName: 'light-ball',
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, contains('@ Light Ball'));
    });

    test('ability line included when set', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25, abilityName: 'lightning-rod',
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, contains('Ability: Lightning Rod'));
    });

    test('nature line included when set', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25, natureName: 'Timid',
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, contains('Nature: Timid Nature'));
    });

    test('shiny: yes line included only when shiny', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final shiny = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25, isShiny: true,
      );
      final notShiny = _slot(
        id: 2, slot: 2, teamId: 1, pokemonId: 25, isShiny: false,
      );
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final shinyResult = await buildShowdownExport([shiny], mockApi);
      final normalResult = await buildShowdownExport([notShiny], mockApi);

      expect(shinyResult, contains('Shiny: Yes'));
      expect(normalResult, isNot(contains('Shiny')));
    });

    test('zero EVs are omitted entirely', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25,
        evHp: 0, evAtk: 0, evDef: 0, evSpa: 0, evSpd: 0, evSpe: 0,
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, isNot(contains('EVs:')));
    });

    test('non-zero EVs appear with correct labels', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25,
        evHp: 4, evSpa: 252, evSpe: 252,
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, contains('EVs: 4 HP / 252 SpA / 252 Spe'));
    });

    test('moves appear as "- Move" lines, null moves skipped', () async {
      when(() => mockApi.fetchPokemon(25))
          .thenAnswer((_) async => _pokemon('pikachu'));

      final slot = _slot(
        id: 1, slot: 1, teamId: 1, pokemonId: 25,
        move1: 'thunderbolt', move2: 'surf', move3: null, move4: null,
      );
      final result = await buildShowdownExport([slot], mockApi);

      expect(result, contains('- Thunderbolt'));
      expect(result, contains('- Surf'));
      expect(result.split('\n').where((l) => l.startsWith('- ')), hasLength(2));
    });

    test('multiple slots are separated by double newline and sorted by slot', () async {
      when(() => mockApi.fetchPokemon(1)).thenAnswer((_) async => _pokemon('bulbasaur'));
      when(() => mockApi.fetchPokemon(4)).thenAnswer((_) async => _pokemon('charmander'));

      // Pass slots in reverse order — export must sort by slot number.
      final slots = [
        _slot(id: 2, slot: 2, teamId: 1, pokemonId: 4),
        _slot(id: 1, slot: 1, teamId: 1, pokemonId: 1),
      ];
      final result = await buildShowdownExport(slots, mockApi);

      final blocks = result.split('\n\n');
      expect(blocks, hasLength(2));
      expect(blocks[0], startsWith('Bulbasaur'));
      expect(blocks[1], startsWith('Charmander'));
    });
  });
}
