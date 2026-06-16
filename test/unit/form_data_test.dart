// test/unit/form_data_test.dart
//
// Tests for the PS form exceptions and cosmetic sprite stems stored in
// PokemonDataRegistry (formerly const maps in form_data.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  group('psFormExceptions', () {
    test('maps ogerpon-wellspring to ogerpon-wellspring-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-wellspring'],
        'ogerpon-wellspring-mask',
      );
    });

    test('maps ogerpon-hearthflame to ogerpon-hearthflame-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-hearthflame'],
        'ogerpon-hearthflame-mask',
      );
    });

    test('maps ogerpon-cornerstone to ogerpon-cornerstone-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-cornerstone'],
        'ogerpon-cornerstone-mask',
      );
    });

    test('maps ogerpon-teal to ogerpon-teal-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-teal'],
        'ogerpon-teal-mask',
      );
    });

    test('unknown PS name returns null', () {
      expect(PokemonDataRegistry.instance.psFormExceptions['pikachu'], isNull);
    });

    test('all keys are lowercase hyphenated', () {
      for (final key in PokemonDataRegistry.instance.psFormExceptions.keys) {
        expect(key, equals(key.toLowerCase()), reason: '$key must be lowercase');
        expect(key.contains(' '), isFalse, reason: '$key must use hyphens not spaces');
      }
    });
  });

  group('cosmeticSpriteStems', () {
    test('burmy sandy cloak stem is 412-sandy', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['burmy']?['burmy-sandy'],
        '412-sandy',
      );
    });

    test('burmy trash cloak stem is 412-trash', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['burmy']?['burmy-trash'],
        '412-trash',
      );
    });

    test('shellos east sea stem is 422-east', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['shellos']?['shellos-east'],
        '422-east',
      );
    });

    test('all stem values follow {id}-{suffix} format', () {
      for (final speciesEntry in PokemonDataRegistry.instance.cosmeticSpriteStems.entries) {
        for (final stem in speciesEntry.value.values) {
          expect(
            stem.contains('-'),
            isTrue,
            reason: 'stem "$stem" for ${speciesEntry.key} must follow {id}-{suffix} format',
          );
        }
      }
    });
  });
}
