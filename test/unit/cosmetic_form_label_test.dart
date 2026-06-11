// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_screen.dart';

void main() {
  group('cosmeticFormLabel', () {
    test('single word → capitalised', () {
      expect(cosmeticFormLabel('sandy'), 'Sandy');
    });
    test('hyphenated → title case words', () {
      expect(cosmeticFormLabel('red-flower'), 'Red Flower');
    });
    test('single letter (Unown) → capitalised', () {
      expect(cosmeticFormLabel('a'), 'A');
    });
    test('multi-segment Vivillon', () {
      expect(cosmeticFormLabel('icy-snow'), 'Icy Snow');
    });
    test('empty string → Default', () {
      expect(cosmeticFormLabel(''), 'Default');
    });
  });
}
