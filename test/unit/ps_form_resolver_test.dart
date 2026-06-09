// test/unit/ps_form_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/logic/ps_form_resolver.dart';

void main() {
  group('resolveFormFromVarieties — exact match', () {
    test('returns exact variety name when present', () {
      expect(
        resolveFormFromVarieties('rotom-heat', ['rotom', 'rotom-heat', 'rotom-wash']),
        'rotom-heat',
      );
    });

    test('returns null when no match', () {
      expect(
        resolveFormFromVarieties('rotom-unknown', ['rotom', 'rotom-heat']),
        isNull,
      );
    });
  });

  group('resolveFormFromVarieties — forward prefix', () {
    test('ogerpon-wellspring matches ogerpon-wellspring-mask', () {
      expect(
        resolveFormFromVarieties(
          'ogerpon-wellspring',
          ['ogerpon', 'ogerpon-teal-mask', 'ogerpon-wellspring-mask'],
        ),
        'ogerpon-wellspring-mask',
      );
    });
  });

  group('resolveFormFromVarieties — reverse prefix', () {
    test('necrozma-dawn-wings matches necrozma-dawn', () {
      expect(
        resolveFormFromVarieties(
          'necrozma-dawn-wings',
          ['necrozma', 'necrozma-dawn', 'necrozma-dusk'],
        ),
        'necrozma-dawn',
      );
    });
  });

  group('resolveFormFromVarieties — last segment', () {
    test('maushold-four matches maushold-family-of-four', () {
      expect(
        resolveFormFromVarieties(
          'maushold-four',
          ['maushold', 'maushold-family-of-three', 'maushold-family-of-four'],
        ),
        'maushold-family-of-four',
      );
    });
  });

  group('resolveFormFromVarieties — pipeline priority', () {
    test('exact match takes priority over forward prefix', () {
      expect(
        resolveFormFromVarieties(
          'aegislash-blade',
          ['aegislash', 'aegislash-blade', 'aegislash-blade-extra'],
        ),
        'aegislash-blade',
      );
    });
  });

  group('applyPsFormExceptions', () {
    test('returns mapped name for known exceptions', () {
      expect(applyPsFormExceptions('ogerpon-wellspring'), 'ogerpon-wellspring-mask');
    });

    test('returns null for unknown names', () {
      expect(applyPsFormExceptions('pikachu-original'), isNull);
    });
  });
}
