import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/logic/ps_import_resolvers.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

void main() {
  group('resolveTeamName', () {
    test('returns override when non-empty', () {
      expect(resolveTeamName('Sun Team', 'Imported Team'), 'Sun Team');
    });

    test('returns parsed when override is empty', () {
      expect(resolveTeamName('', 'Parsed Name'), 'Parsed Name');
    });

    test('returns parsed when override is whitespace-only', () {
      expect(resolveTeamName('   ', 'Parsed Name'), 'Parsed Name');
    });

    test('trims whitespace from override', () {
      expect(resolveTeamName('  Trimmed  ', 'Parsed Name'), 'Trimmed');
    });
  });

  group('resolveFormatId', () {
    const gen9ou = GameFormat(
      id: 'gen9ou',
      name: 'Gen 9 OU',
      short: 'Gen 9 OU',
      type: FormatType.game,
      gen: 9,
    );
    const vgc = GameFormat(
      id: 'gen9vgc2025',
      name: 'VGC 2025',
      short: 'VGC 2025',
      type: FormatType.game,
      gen: 9,
    );

    test('returns null when no override and no parsed', () {
      expect(resolveFormatId(null, null), isNull);
    });

    test('returns parsed when no override', () {
      expect(resolveFormatId(null, 'gen9ou'), 'gen9ou');
    });

    test('returns override id when override is selected', () {
      expect(resolveFormatId(vgc, gen9ou.id), 'gen9vgc2025');
    });
  });
}
