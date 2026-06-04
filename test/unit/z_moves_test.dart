import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/z_moves_data.dart';

void main() {
  group('ExclusiveZData.matchesSpecies', () {
    test('returns true when species starts with a listed prefix', () {
      const data = ExclusiveZData(
        speciesPrefixes: ['lycanroc'],
        requiredMoveId: 'stone-edge',
        zMove: 'splintered-stormshards',
      );
      expect(data.matchesSpecies('lycanroc-midday'), isTrue);
      expect(data.matchesSpecies('lycanroc-midnight'), isTrue);
      expect(data.matchesSpecies('lycanroc-dusk'), isTrue);
    });

    test('returns false when species does not start with any prefix', () {
      const data = ExclusiveZData(
        speciesPrefixes: ['lycanroc'],
        requiredMoveId: 'stone-edge',
        zMove: 'splintered-stormshards',
      );
      expect(data.matchesSpecies('rockruff'), isFalse);
    });

    test('returns true when speciesPrefixes is empty (any species matches)', () {
      const data = ExclusiveZData(
        speciesPrefixes: [],
        requiredMoveId: 'any-move',
        zMove: 'some-z-move',
      );
      expect(data.matchesSpecies('pikachu'), isTrue);
      expect(data.matchesSpecies('snorlax'), isTrue);
    });
  });

  group('resolveZMove — type Z-crystals', () {
    test('electrium-z + electric move → gigavolt-havoc', () {
      expect(
        resolveZMove(
          itemId: 'electrium-z',
          moveId: 'thunderbolt',
          pokemonName: 'pikachu',
          moveType: 'electric',
        ),
        'gigavolt-havoc',
      );
    });

    test('waterium-z + water move → hydro-vortex', () {
      expect(
        resolveZMove(
          itemId: 'waterium-z',
          moveId: 'surf',
          pokemonName: 'gyarados',
          moveType: 'water',
        ),
        'hydro-vortex',
      );
    });

    test('type Z-crystal + wrong move type → null', () {
      expect(
        resolveZMove(
          itemId: 'electrium-z',
          moveId: 'flamethrower',
          pokemonName: 'pikachu',
          moveType: 'fire',
        ),
        isNull,
      );
    });

    test('type Z-crystal + null moveType → null', () {
      expect(
        resolveZMove(
          itemId: 'electrium-z',
          moveId: 'thunderbolt',
          pokemonName: 'pikachu',
          moveType: null,
        ),
        isNull,
      );
    });

    test('normalium-z + normal move → breakneck-blitz', () {
      expect(
        resolveZMove(
          itemId: 'normalium-z',
          moveId: 'hyper-beam',
          pokemonName: 'snorlax',
          moveType: 'normal',
        ),
        'breakneck-blitz',
      );
    });
  });

  group('resolveZMove — -held / -bag suffix normalization', () {
    test('incinium-z-held normalizes correctly and resolves', () {
      expect(
        resolveZMove(
          itemId: 'incinium-z-held',
          moveId: 'darkest-lariat',
          pokemonName: 'incineroar',
          moveType: 'dark',
        ),
        'malicious-moonsault',
      );
    });

    test('electrium-z-bag normalizes and resolves for type Z', () {
      expect(
        resolveZMove(
          itemId: 'electrium-z-bag',
          moveId: 'thunderbolt',
          pokemonName: 'pikachu',
          moveType: 'electric',
        ),
        'gigavolt-havoc',
      );
    });
  });

  group('resolveZMove — exclusive Z-crystals', () {
    test('incinium-z + darkest-lariat + incineroar → malicious-moonsault', () {
      expect(
        resolveZMove(
          itemId: 'incinium-z',
          moveId: 'darkest-lariat',
          pokemonName: 'incineroar',
          moveType: 'dark',
        ),
        'malicious-moonsault',
      );
    });

    test('exclusive Z-crystal: wrong move → null', () {
      expect(
        resolveZMove(
          itemId: 'incinium-z',
          moveId: 'flamethrower',
          pokemonName: 'incineroar',
          moveType: 'fire',
        ),
        isNull,
      );
    });

    test('exclusive Z-crystal: wrong species → null', () {
      expect(
        resolveZMove(
          itemId: 'incinium-z',
          moveId: 'darkest-lariat',
          pokemonName: 'pikachu',
          moveType: 'dark',
        ),
        isNull,
      );
    });

    test('lycanium-z + stone-edge + lycanroc-midday → splintered-stormshards', () {
      expect(
        resolveZMove(
          itemId: 'lycanium-z',
          moveId: 'stone-edge',
          pokemonName: 'lycanroc-midday',
          moveType: 'rock',
        ),
        'splintered-stormshards',
      );
    });

    test('tapunium-z + natures-madness + tapu-koko → guardian-of-alola', () {
      expect(
        resolveZMove(
          itemId: 'tapunium-z',
          moveId: 'natures-madness',
          pokemonName: 'tapu-koko',
          moveType: 'fairy',
        ),
        'guardian-of-alola',
      );
    });

    test('mewnium-z + nasty-plot + mew → genesis-supernova', () {
      expect(
        resolveZMove(
          itemId: 'mewnium-z',
          moveId: 'nasty-plot',
          pokemonName: 'mew',
          moveType: 'psychic',
        ),
        'genesis-supernova',
      );
    });

    test('eevium-z + last-resort + eevee → extreme-evoboost', () {
      expect(
        resolveZMove(
          itemId: 'eevium-z',
          moveId: 'last-resort',
          pokemonName: 'eevee',
          moveType: 'normal',
        ),
        'extreme-evoboost',
      );
    });
  });

  group('resolveZMove — unknown item', () {
    test('non-Z-crystal item → null', () {
      expect(
        resolveZMove(
          itemId: 'leftovers',
          moveId: 'thunderbolt',
          pokemonName: 'pikachu',
          moveType: 'electric',
        ),
        isNull,
      );
    });
  });
}
