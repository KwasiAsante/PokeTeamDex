import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/logic/ps_import_parser.dart';

void main() {
  group('parsePsTeam — nature', () {
    test('parses real Showdown syntax "<Nature> Nature" (no colon prefix)', () {
      const text = '''
Pikachu @ Light Ball
Ability: Static
EVs: 252 SpA / 4 SpD / 252 Spe
Timid Nature
- Thunderbolt
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.nature, 'Timid');
    });

    test('normalises lowercase nature word to Proper case', () {
      const text = '''
Pikachu @ Light Ball
sassy Nature
- Thunderbolt
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.nature, 'Sassy');
    });

    test('defensively strips a legacy "Nature: " prefix if present', () {
      const text = '''
Pikachu @ Light Ball
Nature: Timid Nature
- Thunderbolt
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.nature, 'Timid');
    });

    test('nature is null when no nature line present', () {
      const text = '''
Pikachu @ Light Ball
- Thunderbolt
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.nature, isNull);
    });
  });

  group('parsePsTeam — Gigantamax', () {
    test('sets isGigantamax when "Gigantamax: Yes" present', () {
      const text = '''
Rillaboom @ Life Orb
Ability: Grassy Surge
Gigantamax: Yes
Jolly Nature
- Swords Dance
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.isGigantamax, isTrue);
    });

    test('isGigantamax defaults to false when absent', () {
      const text = '''
Rillaboom @ Life Orb
Ability: Grassy Surge
Jolly Nature
- Swords Dance
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.isGigantamax, isFalse);
    });
  });

  group('parsePsTeam — Tera Type', () {
    test('parses and normalises "Tera Type: X" to lowercase', () {
      const text = '''
Umbreon @ Leftovers
Ability: Synchronize
Tera Type: Dark
Sassy Nature
- Foul Play
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.teraType, 'dark');
    });

    test('teraType is null when absent', () {
      const text = '''
Umbreon @ Leftovers
Ability: Synchronize
Sassy Nature
- Foul Play
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.teraType, isNull);
    });
  });

  group('parsePsTeam — Happiness', () {
    test('parses "Happiness: N" into friendship', () {
      const text = '''
Snorlax @ Leftovers
Happiness: 0
- Frustration
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.friendship, 0);
    });

    test('friendship is null when absent', () {
      const text = '''
Snorlax @ Leftovers
- Return
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.friendship, isNull);
    });
  });

  group('parsePsTeam — species normalisation', () {
    test('strips periods from species names ("Mr. Rime" → "mr-rime")', () {
      const text = '''
Wattson (Mr. Rime) (M) @ Heavy-Duty Boots
Ability: Screen Cleaner
Calm Nature
- Slack Off
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.species, 'mr-rime');
      expect(team.slots.single.nickname, 'Wattson');
      expect(team.slots.single.gender, 'male');
    });

    test('strips periods from "Mime Jr." with no nickname', () {
      const text = '''
Mime Jr. @ Eviolite
Ability: Soundproof
- Fake Out
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.species, 'mime-jr');
    });

    test('strips curly and modifier-letter apostrophes ("Sirfetch’d")', () {
      const text = '''
Suzaku (Sirfetch’d) (M) @ Leek
Ability: Scrappy
- Close Combat
''';
      final team = parsePsTeam(text);
      expect(team.slots.single.species, 'sirfetchd');
    });
  });

  group('applyGenGates', () {
    const fullSlot = PsSlot(
      species: 'snorlax',
      item: 'leftovers',
      ability: 'thick-fat',
      isShiny: true,
      gender: 'male',
      nature: 'Careful',
      friendship: 255,
      isGigantamax: true,
      teraType: 'normal',
    );

    test('null gen (unknown/no format) leaves every field untouched', () {
      final gated = applyGenGates(fullSlot, null);
      expect(gated.item, 'leftovers');
      expect(gated.ability, 'thick-fat');
      expect(gated.isShiny, isTrue);
      expect(gated.gender, 'male');
      expect(gated.nature, 'Careful');
      expect(gated.friendship, 255);
      expect(gated.isGigantamax, isTrue);
      expect(gated.teraType, 'normal');
    });

    test('Gen 1 strips item, ability, shiny, gender, nature, happiness, '
        'Gigantamax, and Tera Type — none of those exist in Gen 1', () {
      final gated = applyGenGates(fullSlot, 1);
      expect(gated.item, isNull);
      expect(gated.ability, isNull);
      expect(gated.isShiny, isFalse);
      expect(gated.gender, isNull);
      expect(gated.nature, isNull);
      expect(gated.friendship, isNull);
      expect(gated.isGigantamax, isFalse);
      expect(gated.teraType, isNull);
      // Species, level, EVs/IVs, and moves are never gen-gated.
      expect(gated.species, 'snorlax');
    });

    test('Gen 2 keeps item, shiny, gender, happiness — still no ability/nature', () {
      final gated = applyGenGates(fullSlot, 2);
      expect(gated.item, 'leftovers');
      expect(gated.isShiny, isTrue);
      expect(gated.gender, 'male');
      expect(gated.friendship, 255);
      expect(gated.ability, isNull);
      expect(gated.nature, isNull);
      expect(gated.isGigantamax, isFalse);
      expect(gated.teraType, isNull);
    });

    test('Gen 3+ keeps ability and nature, still no Gigantamax/Tera Type', () {
      final gated = applyGenGates(fullSlot, 3);
      expect(gated.ability, 'thick-fat');
      expect(gated.nature, 'Careful');
      expect(gated.isGigantamax, isFalse);
      expect(gated.teraType, isNull);
    });

    test('Gen 8 keeps Gigantamax, still no Tera Type', () {
      final gated = applyGenGates(fullSlot, 8);
      expect(gated.isGigantamax, isTrue);
      expect(gated.teraType, isNull);
    });

    test('Gen 9 keeps Tera Type, no longer has Gigantamax', () {
      final gated = applyGenGates(fullSlot, 9);
      expect(gated.teraType, 'normal');
      expect(gated.isGigantamax, isFalse);
    });
  });

  group('psIvDefault', () {
    test('Gen 1/2 default to 15 (raw DV scale)', () {
      expect(psIvDefault(1), 15);
      expect(psIvDefault(2), 15);
    });

    test('Gen 3+ and unknown/null gen default to 31', () {
      expect(psIvDefault(3), 31);
      expect(psIvDefault(9), 31);
      expect(psIvDefault(null), 31);
    });
  });

  group('psIvToStored', () {
    test('Gen 1/2 halves the PS-scale IV back to a raw DV', () {
      // Real Showdown-exported Gen 1/2 IVs are always even (DV × 2).
      expect(psIvToStored(30, 1), 15);
      expect(psIvToStored(26, 2), 13);
      expect(psIvToStored(0, 1), 0);
    });

    test('Gen 3+ and unknown/null gen store the IV as-is', () {
      expect(psIvToStored(30, 3), 30);
      expect(psIvToStored(0, 9), 0);
      expect(psIvToStored(31, null), 31);
    });
  });

  group('parsePsTeam — Gen 1/2 IVs (DV scale)', () {
    test('a real Gen 1/2 IV line parses as the PS-scale (doubled) value — '
        'gen-aware conversion to raw DVs happens at insert time, not here', () {
      const text = '''
Pikachu @ Light Ball
IVs: 26 Def
- Thunderbolt
''';
      final team = parsePsTeam(text);
      // parsePsTeam itself is gen-agnostic; it always returns the raw parsed
      // PS value. Converting it to a stored DV is the caller's job via
      // psIvToStored — this test guards against ever baking a gen-specific
      // conversion into the parser itself, which would double-convert data
      // when the caller also applies psIvToStored.
      expect(team.slots.single.ivs['defense'], 26);
    });
  });

  group('parsePsTeam — real Showdown export fixture', () {
    // Trimmed from a real Pokémon Showdown Teambuilder export.
    const text = '''
Kong (Rillaboom) (M) @ Life Orb
Ability: Grassy Surge
Gigantamax: Yes
EVs: 252 Atk / 4 SpD / 252 Spe
Jolly Nature
- Swords Dance
- Grassy Glide
- Knock Off
- Superpower

Wattson (Mr. Rime) (M) @ Heavy-Duty Boots
Ability: Screen Cleaner
EVs: 248 HP / 8 SpA / 252 SpD
Calm Nature
- Slack Off
- Rapid Spin
- Freeze-Dry
- Psychic
''';

    test('parses both blocks with nature, Gigantamax, and periods handled', () {
      final team = parsePsTeam(text);
      expect(team.slots, hasLength(2));

      final rillaboom = team.slots[0];
      expect(rillaboom.species, 'rillaboom');
      expect(rillaboom.nickname, 'Kong');
      expect(rillaboom.nature, 'Jolly');
      expect(rillaboom.isGigantamax, isTrue);
      expect(rillaboom.evs['attack'], 252);
      expect(rillaboom.moves, [
        'swords-dance', 'grassy-glide', 'knock-off', 'superpower',
      ]);

      final mrRime = team.slots[1];
      expect(mrRime.species, 'mr-rime');
      expect(mrRime.nickname, 'Wattson');
      expect(mrRime.nature, 'Calm');
      expect(mrRime.isGigantamax, isFalse);
    });
  });
}
