import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/dynamax_data.dart';

void main() {
  group('gmaxMoveForSpecies', () {
    test('exact match returns correct G-Max move', () {
      expect(gmaxMoveForSpecies('charizard')?.moveName, 'g-max-wildfire');
      expect(gmaxMoveForSpecies('gengar')?.moveName, 'g-max-terror');
      expect(gmaxMoveForSpecies('snorlax')?.moveName, 'g-max-replenish');
    });

    test('exact match returns correct type', () {
      expect(gmaxMoveForSpecies('charizard')?.type, 'fire');
      expect(gmaxMoveForSpecies('pikachu')?.type, 'electric');
      expect(gmaxMoveForSpecies('urshifu-rapid-strike')?.type, 'water');
    });

    test('urshifu-single-strike returns g-max-one-blow (exact)', () {
      expect(gmaxMoveForSpecies('urshifu-single-strike')?.moveName, 'g-max-one-blow');
    });

    test('urshifu-rapid-strike returns g-max-rapid-flow (exact)', () {
      expect(gmaxMoveForSpecies('urshifu-rapid-strike')?.moveName, 'g-max-rapid-flow');
    });

    test('prefix match works for unlisted form variants', () {
      // 'pikachu-original' not in map; should prefix-match 'pikachu'
      expect(gmaxMoveForSpecies('pikachu-original')?.moveName, 'g-max-volt-crash');
    });

    test('prefix match works for rillaboom (DLC species)', () {
      expect(gmaxMoveForSpecies('rillaboom')?.moveName, 'g-max-drum-solo');
    });

    test('non-Gigantamax species returns null', () {
      expect(gmaxMoveForSpecies('mewtwo'), isNull);
      expect(gmaxMoveForSpecies('rayquaza'), isNull);
    });

    test('species with no prefix match returns null', () {
      expect(gmaxMoveForSpecies(''), isNull);
      expect(gmaxMoveForSpecies('bulbasaur'), isNull);
    });
  });

  group('resolveMaxMove — status moves', () {
    test('status category always returns max-guard', () {
      expect(
        resolveMaxMove(
          moveType: 'electric',
          moveCategory: 'status',
          speciesName: 'pikachu',
        ),
        'max-guard',
      );
    });

    test('status category returns max-guard even with useGMax=true', () {
      expect(
        resolveMaxMove(
          moveType: 'fire',
          moveCategory: 'status',
          speciesName: 'charizard',
          useGMax: true,
        ),
        'max-guard',
      );
    });

    test('status category with null moveType still returns max-guard', () {
      expect(
        resolveMaxMove(
          moveType: null,
          moveCategory: 'status',
          speciesName: 'snorlax',
        ),
        'max-guard',
      );
    });
  });

  group('resolveMaxMove — type-based (no G-Max)', () {
    test('fire physical move → max-flare', () {
      expect(
        resolveMaxMove(
          moveType: 'fire',
          moveCategory: 'physical',
          speciesName: 'arcanine',
        ),
        'max-flare',
      );
    });

    test('water special move → max-geyser', () {
      expect(
        resolveMaxMove(
          moveType: 'water',
          moveCategory: 'special',
          speciesName: 'vaporeon',
        ),
        'max-geyser',
      );
    });

    test('dragon move → max-wyrmwind', () {
      expect(
        resolveMaxMove(
          moveType: 'dragon',
          moveCategory: 'physical',
          speciesName: 'dragonite',
        ),
        'max-wyrmwind',
      );
    });

    test('null moveType non-status → null', () {
      expect(
        resolveMaxMove(
          moveType: null,
          moveCategory: 'physical',
          speciesName: 'mewtwo',
        ),
        isNull,
      );
    });
  });

  group('resolveMaxMove — G-Max path', () {
    test('useGMax=true + Gmax species → G-Max move', () {
      expect(
        resolveMaxMove(
          moveType: 'fire',
          moveCategory: 'special',
          speciesName: 'charizard',
          useGMax: true,
        ),
        'g-max-wildfire',
      );
    });

    test('useGMax=true + non-Gmax species falls back to type-based', () {
      expect(
        resolveMaxMove(
          moveType: 'electric',
          moveCategory: 'special',
          speciesName: 'raichu',  // no G-Max
          useGMax: true,
        ),
        'max-lightning',
      );
    });

    test('useGMax=false + Gmax species returns type-based', () {
      expect(
        resolveMaxMove(
          moveType: 'fire',
          moveCategory: 'special',
          speciesName: 'charizard',
          useGMax: false,
        ),
        'max-flare',
      );
    });

    test('urshifu-rapid-strike G-Max is g-max-rapid-flow', () {
      expect(
        resolveMaxMove(
          moveType: 'water',
          moveCategory: 'physical',
          speciesName: 'urshifu-rapid-strike',
          useGMax: true,
        ),
        'g-max-rapid-flow',
      );
    });

    test('charizard + flying move → max-airstream (not g-max-wildfire)', () {
      expect(
        resolveMaxMove(
          moveType: 'flying',
          moveCategory: 'physical',
          speciesName: 'charizard',
          useGMax: true,
        ),
        'max-airstream',
      );
    });

    test('pikachu + grass move → max-overgrowth (not g-max-volt-crash)', () {
      expect(
        resolveMaxMove(
          moveType: 'grass',
          moveCategory: 'special',
          speciesName: 'pikachu',
          useGMax: true,
        ),
        'max-overgrowth',
      );
    });

    test('urshifu-rapid-strike + fire move → max-flare (not g-max-rapid-flow)', () {
      expect(
        resolveMaxMove(
          moveType: 'fire',
          moveCategory: 'physical',
          speciesName: 'urshifu-rapid-strike',
          useGMax: true,
        ),
        'max-flare',
      );
    });
  });
}
