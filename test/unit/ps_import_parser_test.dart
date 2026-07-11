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
