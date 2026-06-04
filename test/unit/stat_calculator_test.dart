import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/shared/utils/stat_calculator.dart';

void main() {
  group('calcHP', () {
    test('base 45 IV 31 EV 0 level 50 (Caterpie HP)', () {
      // (2*45 + 31 + 0) * 50 / 100 + 50 + 10 = 121*50~/100 + 60 = 60 + 60
      expect(calcHP(45, 31, 0, 50), 120);
    });

    test('base 160 IV 31 EV 0 level 50 (Snorlax HP)', () {
      // (2*160 + 31 + 0) * 50 / 100 + 60 = 351*50~/100 + 60 = 175 + 60
      expect(calcHP(160, 31, 0, 50), 235);
    });

    test('base 100 IV 31 EV 252 level 100', () {
      // (2*100 + 31 + 63) * 100 / 100 + 100 + 10 = 294 + 110
      expect(calcHP(100, 31, 252, 100), 404);
    });

    test('zero IVs and EVs level 1 (minimum HP)', () {
      // (2*1 + 0 + 0) * 1 / 100 + 1 + 10 = 0 + 11
      expect(calcHP(1, 0, 0, 1), 11);
    });

    test('max EVs (252) add 32 HP at level 50', () {
      // noEv:    (200+31+0)*50~/100 + 60 = 115 + 60 = 175
      // maxEv:   (200+31+63)*50~/100 + 60 = 147 + 60 = 207
      // diff = 32
      expect(calcHP(100, 31, 0, 50), 175);
      expect(calcHP(100, 31, 252, 50), 207);
      expect(calcHP(100, 31, 252, 50) - calcHP(100, 31, 0, 50), 32);
    });
  });

  group('calcStat', () {
    test('base 100 IV 31 EV 0 level 50 neutral nature', () {
      // inner = (2*100 + 31 + 0)*50~/100 + 5 = 231*50~/100 + 5 = 115 + 5 = 120
      // × 1.0 = 120
      expect(calcStat(100, 31, 0, 50, 1.0), 120);
    });

    test('base 100 IV 31 EV 252 level 50 boosted nature', () {
      // inner = (200 + 31 + 63)*50~/100 + 5 = 294*50~/100 + 5 = 147 + 5 = 152
      // × 1.1 = 167.2 → floor → 167
      expect(calcStat(100, 31, 252, 50, 1.1), 167);
    });

    test('base 100 IV 31 EV 252 level 50 lowered nature', () {
      // inner = 152 (as above), × 0.9 = 136.8 → floor → 136
      expect(calcStat(100, 31, 252, 50, 0.9), 136);
    });

    test('level 100 no nature modifier', () {
      // inner = (200 + 31 + 0)*100~/100 + 5 = 231 + 5 = 236
      expect(calcStat(100, 31, 0, 100, 1.0), 236);
    });
  });

  group('natureMod', () {
    test('null nature returns 1.0', () {
      expect(natureMod(null, 'attack'), 1.0);
    });

    test('unknown nature name returns 1.0', () {
      expect(natureMod('Unknown', 'attack'), 1.0);
    });

    test('Adamant boosts attack', () {
      expect(natureMod('Adamant', 'attack'), 1.1);
    });

    test('Adamant lowers special-attack', () {
      expect(natureMod('Adamant', 'special-attack'), 0.9);
    });

    test('Adamant is neutral on defense', () {
      expect(natureMod('Adamant', 'defense'), 1.0);
    });

    test('Timid boosts speed', () {
      expect(natureMod('Timid', 'speed'), 1.1);
    });

    test('Timid lowers attack', () {
      expect(natureMod('Timid', 'attack'), 0.9);
    });

    test('Hardy is neutral on all stats', () {
      for (final stat in ['attack', 'defense', 'special-attack', 'special-defense', 'speed']) {
        expect(natureMod('Hardy', stat), 1.0, reason: 'Hardy should be neutral on $stat');
      }
    });

    test('nature name matching is case-insensitive', () {
      expect(natureMod('adamant', 'attack'), 1.1);
      expect(natureMod('ADAMANT', 'attack'), 1.1);
      expect(natureMod('Adamant', 'attack'), 1.1);
    });
  });
}
