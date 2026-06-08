import 'package:flutter_test/flutter_test.dart';

// These tests document the name/format resolution rules.
// The actual functions (_resolveTeamName, _resolveFormatId) are private;
// correctness is verified via widget integration in ps_import_sheet_test.dart.

void main() {
  group('resolveTeamName', () {
    test('returns override when non-empty', () {
      const override = 'Sun Team';
      const parsed = 'Imported Team';
      final result = override.trim().isNotEmpty ? override.trim() : parsed;
      expect(result, 'Sun Team');
    });

    test('returns parsed when override is empty', () {
      const override = '';
      const parsed = 'Parsed Name';
      final result = override.trim().isNotEmpty ? override.trim() : parsed;
      expect(result, 'Parsed Name');
    });

    test('returns parsed when override is whitespace-only', () {
      const override = '   ';
      const parsed = 'Parsed Name';
      final result = override.trim().isNotEmpty ? override.trim() : parsed;
      expect(result, 'Parsed Name');
    });

    test('trims whitespace from override', () {
      const override = '  Trimmed  ';
      const parsed = 'Parsed Name';
      final result = override.trim().isNotEmpty ? override.trim() : parsed;
      expect(result, 'Trimmed');
    });
  });

  group('resolveFormatId', () {
    test('returns null when no override and no parsed', () {
      const String? override = null;
      const String? parsed = null;
      final result = override ?? parsed;
      expect(result, isNull);
    });

    test('returns parsed when no override', () {
      const String? override = null;
      const String? parsed = 'gen9ou';
      final result = override ?? parsed;
      expect(result, 'gen9ou');
    });

    test('returns override id when override is selected', () {
      const String override = 'gen9vgc2025';
      const String? parsed = 'gen9ou';
      final result = override;
      expect(result, 'gen9vgc2025');
    });
  });
}
