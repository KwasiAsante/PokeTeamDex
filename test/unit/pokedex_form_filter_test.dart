import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

PokemonVariety _v(String name, {bool isDefault = false}) =>
    PokemonVariety(isDefault: isDefault, name: name);

void main() {
  group('battleMeaningfulForms', () {
    test('excludes default variety', () {
      final result = battleMeaningfulForms([
        _v('zigzagoon', isDefault: true),
        _v('zigzagoon-galar'),
      ]);
      expect(result.map((v) => v.name), ['zigzagoon-galar']);
    });

    test('includes all regional suffixes', () {
      final varieties = [
        _v('meowth', isDefault: true),
        _v('meowth-alola'),
        _v('meowth-galar'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.map((v) => v.name), containsAll(['meowth-alola', 'meowth-galar']));
    });

    test('excludes mega forms', () {
      final varieties = [
        _v('charizard', isDefault: true),
        _v('charizard-mega-x'),
        _v('charizard-mega-y'),
        _v('charizard-gmax'),
      ];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('includes meowstic-female', () {
      final result = battleMeaningfulForms([
        _v('meowstic', isDefault: true),
        _v('meowstic-female'),
      ]);
      expect(result.map((v) => v.name), contains('meowstic-female'));
    });

    test('includes all 5 rotom appliances', () {
      final varieties = [
        _v('rotom', isDefault: true),
        _v('rotom-heat'), _v('rotom-wash'), _v('rotom-frost'),
        _v('rotom-fan'), _v('rotom-mow'),
      ];
      expect(battleMeaningfulForms(varieties).length, 5);
    });

    test('excludes cosmetic cap pikachu variants', () {
      final varieties = [
        _v('pikachu', isDefault: true),
        _v('pikachu-original-cap'),
        _v('pikachu-alola-cap'),
        _v('pikachu-gmax'),
      ];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('includes urshifu-rapid-strike', () {
      final result = battleMeaningfulForms([
        _v('urshifu', isDefault: true),
        _v('urshifu-rapid-strike'),
      ]);
      expect(result.map((v) => v.name), contains('urshifu-rapid-strike'));
    });

    test('excludes eternamax', () {
      final varieties = [
        _v('eternatus', isDefault: true),
        _v('eternatus-eternamax'),
      ];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('includes lycanroc forms', () {
      final varieties = [
        _v('lycanroc', isDefault: true),
        _v('lycanroc-midnight'),
        _v('lycanroc-dusk'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.length, 2);
    });

    test('includes all 3 Paldean Tauros breeds', () {
      final varieties = [
        _v('tauros', isDefault: true),
        _v('tauros-paldea-combat-breed'),
        _v('tauros-paldea-blaze-breed'),
        _v('tauros-paldea-aqua-breed'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.length, 3);
      expect(result.map((v) => v.name), containsAll([
        'tauros-paldea-combat-breed',
        'tauros-paldea-blaze-breed',
        'tauros-paldea-aqua-breed',
      ]));
    });

    test('includes Darmanitan forms (Unovan zen, Galarian standard + zen)', () {
      final varieties = [
        _v('darmanitan', isDefault: true),
        _v('darmanitan-zen'),
        _v('darmanitan-galar-standard'),
        _v('darmanitan-galar-zen'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.length, 3);
      expect(result.map((v) => v.name), containsAll([
        'darmanitan-zen', 'darmanitan-galar-standard', 'darmanitan-galar-zen',
      ]));
    });

    test('includes Oinkologne female', () {
      final varieties = [
        _v('oinkologne', isDefault: true),
        _v('oinkologne-female'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.map((v) => v.name), contains('oinkologne-female'));
    });

    test('excludes Wormadam cloaks (cosmetic variety chips, not battle switcher)', () {
      final varieties = [
        _v('wormadam-plant', isDefault: true),
        _v('wormadam-sandy'),
        _v('wormadam-trash'),
      ];
      // Wormadam cloaks are in kCosmeticVarietyNames, NOT in battleMeaningfulForms.
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('excludes Squawkabilly plumages (cosmetic variety chips)', () {
      final varieties = [
        _v('squawkabilly-green-plumage', isDefault: true),
        _v('squawkabilly-blue-plumage'),
        _v('squawkabilly-yellow-plumage'),
        _v('squawkabilly-white-plumage'),
      ];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('includes Basculin white-striped (Hisuian regional form)', () {
      final varieties = [
        _v('basculin-red-striped', isDefault: true),
        _v('basculin-blue-striped'),
        _v('basculin-white-striped'),
      ];
      final result = battleMeaningfulForms(varieties);
      // White-striped is battle-meaningful (evolves into Basculegion).
      expect(result.map((v) => v.name), contains('basculin-white-striped'));
      // Blue-striped is a cosmetic variety chip, not a battle form.
      expect(result.map((v) => v.name), isNot(contains('basculin-blue-striped')));
    });

    test('excludes totem forms with -totem suffix (marowak-totem)', () {
      final varieties = [
        _v('marowak', isDefault: true),
        _v('marowak-totem'),
      ];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('excludes totem forms with -totem- infix (raticate-totem-alola)', () {
      // PokéAPI names Raticate's Alolan Totem form "raticate-totem-alola",
      // not "raticate-alola-totem" — endsWith('-totem') would miss it.
      final varieties = [
        _v('raticate', isDefault: true),
        _v('raticate-alola'),
        _v('raticate-totem-alola'),
      ];
      final result = battleMeaningfulForms(varieties);
      expect(result.length, 1);
      expect(result.single.name, 'raticate-alola');
    });

    test('returns empty for Pokémon with no meaningful alternate forms', () {
      final varieties = [_v('pikachu', isDefault: true)];
      expect(battleMeaningfulForms(varieties), isEmpty);
    });

    test('returns empty list for empty input', () {
      expect(battleMeaningfulForms([]), isEmpty);
    });
  });

  group('kCosmeticVarietyNames', () {
    test('contains Wormadam cosmetic cloaks', () {
      expect(kCosmeticVarietyNames, containsAll(['wormadam-sandy', 'wormadam-trash']));
    });

    test('contains Squawkabilly plumage variants', () {
      expect(kCosmeticVarietyNames, containsAll([
        'squawkabilly-blue-plumage',
        'squawkabilly-yellow-plumage',
        'squawkabilly-white-plumage',
      ]));
    });

    test('contains Minior core colour variants', () {
      expect(kCosmeticVarietyNames, containsAll([
        'minior-red', 'minior-orange', 'minior-yellow', 'minior-green',
        'minior-blue', 'minior-indigo', 'minior-violet',
      ]));
    });

    test('contains Morpeko Hangry mode', () {
      expect(kCosmeticVarietyNames, contains('morpeko-hangry'));
    });

    test('contains Mimikyu Busted form', () {
      expect(kCosmeticVarietyNames, contains('mimikyu-busted'));
    });

    test('does not contain battle-meaningful forms', () {
      expect(kCosmeticVarietyNames, isNot(contains('giratina-origin')));
      expect(kCosmeticVarietyNames, isNot(contains('rotom-heat')));
      expect(kCosmeticVarietyNames, isNot(contains('meowstic-female')));
      expect(kCosmeticVarietyNames, isNot(contains('urshifu-rapid-strike')));
    });

    test('does not contain mega, gmax, or totem forms', () {
      expect(kCosmeticVarietyNames, isNot(contains('charizard-mega-x')));
      expect(kCosmeticVarietyNames, isNot(contains('charizard-gmax')));
      expect(kCosmeticVarietyNames, isNot(contains('marowak-totem')));
    });

    test('battle-meaningful forms and cosmetic forms are disjoint', () {
      // No variety should appear in both sets — that would make its chip
      // appear in the Forms tab AND as a cosmetic chip simultaneously.
      final allBattle = battleMeaningfulForms([
        _v('wormadam-plant', isDefault: true),
        _v('wormadam-sandy'),
        _v('wormadam-trash'),
        _v('squawkabilly-green-plumage', isDefault: true),
        _v('squawkabilly-blue-plumage'),
        _v('morpeko-full-belly', isDefault: true),
        _v('morpeko-hangry'),
        _v('mimikyu-disguised', isDefault: true),
        _v('mimikyu-busted'),
      ]);
      for (final v in allBattle) {
        expect(
          kCosmeticVarietyNames,
          isNot(contains(v.name)),
          reason: '${v.name} should not be in both sets',
        );
      }
    });
  });
}
