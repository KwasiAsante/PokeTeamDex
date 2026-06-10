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
  });
}
