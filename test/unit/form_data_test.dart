// test/unit/form_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/form_data.dart';

void main() {
  group('kPsFormExceptions', () {
    test('maps ogerpon-wellspring to ogerpon-wellspring-mask', () {
      expect(kPsFormExceptions['ogerpon-wellspring'], 'ogerpon-wellspring-mask');
    });

    test('maps ogerpon-hearthflame to ogerpon-hearthflame-mask', () {
      expect(kPsFormExceptions['ogerpon-hearthflame'], 'ogerpon-hearthflame-mask');
    });

    test('maps ogerpon-cornerstone to ogerpon-cornerstone-mask', () {
      expect(kPsFormExceptions['ogerpon-cornerstone'], 'ogerpon-cornerstone-mask');
    });

    test('maps ogerpon-teal to ogerpon-teal-mask', () {
      expect(kPsFormExceptions['ogerpon-teal'], 'ogerpon-teal-mask');
    });

    test('all keys are lowercase hyphenated', () {
      for (final key in kPsFormExceptions.keys) {
        expect(key, equals(key.toLowerCase()), reason: '$key must be lowercase');
        expect(key.contains(' '), isFalse, reason: '$key must use hyphens not spaces');
      }
    });
  });

  group('kCosmeticSpriteStems', () {
    test('burmy sandy cloak stem is 412-sandy', () {
      expect(kCosmeticSpriteStems['burmy']?['burmy-sandy'], '412-sandy');
    });

    test('burmy trash cloak stem is 412-trash', () {
      expect(kCosmeticSpriteStems['burmy']?['burmy-trash'], '412-trash');
    });

    test('shellos east sea stem is 422-east', () {
      expect(kCosmeticSpriteStems['shellos']?['shellos-east'], '422-east');
    });

    test('all stem values follow {id}-{suffix} format', () {
      for (final entry in kCosmeticSpriteStems.entries) {
        for (final stem in entry.value.values) {
          expect(
            stem.contains('-'),
            isTrue,
            reason: 'stem "$stem" must follow {id}-{suffix} format',
          );
        }
      }
    });
  });
}
