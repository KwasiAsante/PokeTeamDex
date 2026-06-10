import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

EvolutionDetail _detail({String? baseFormName, int? baseFormId, int? minLevel}) =>
    EvolutionDetail(
      trigger: 'level-up',
      minLevel: minLevel,
      baseForm: baseFormName != null && baseFormId != null
          ? (name: baseFormName, id: baseFormId)
          : null,
    );

EvolutionNode _zigzagoonChain() {
  return EvolutionNode(
    speciesId: 263,
    speciesName: 'zigzagoon',
    details: const [],
    evolvesTo: [
      EvolutionNode(
        speciesId: 264,
        speciesName: 'linoone',
        details: [
          _detail(minLevel: 20),
          _detail(baseFormName: 'zigzagoon-galar', baseFormId: 10174, minLevel: 20),
        ],
        evolvesTo: [
          EvolutionNode(
            speciesId: 862,
            speciesName: 'obstagoon',
            details: [
              _detail(baseFormName: 'linoone-galar', baseFormId: 10175, minLevel: 35),
            ],
            evolvesTo: const [],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('isRegionalVariety', () {
    test('returns false for default variety', () {
      const v = PokemonVariety(isDefault: true, name: 'zigzagoon');
      expect(isRegionalVariety(v), isFalse);
    });

    test('returns true for -galar variety', () {
      const v = PokemonVariety(isDefault: false, name: 'zigzagoon-galar');
      expect(isRegionalVariety(v), isTrue);
    });

    test('returns true for -alola, -hisui, -paldea varieties', () {
      for (final suffix in ['-alola', '-hisui', '-paldea']) {
        final v = PokemonVariety(isDefault: false, name: 'meowth$suffix');
        expect(isRegionalVariety(v), isTrue, reason: suffix);
      }
    });

    test('returns false for non-regional forms', () {
      for (final name in ['charizard-mega-x', 'pikachu-alola-cap', 'venusaur-gmax']) {
        final v = PokemonVariety(isDefault: false, name: name);
        expect(isRegionalVariety(v), isFalse, reason: name);
      }
    });
  });

  group('regionalSuffixOf', () {
    test('returns galar for zigzagoon-galar', () {
      expect(regionalSuffixOf('zigzagoon-galar'), equals('galar'));
    });

    test('returns null for plain name', () {
      expect(regionalSuffixOf('zigzagoon'), isNull);
    });

    test('returns null for pikachu-alola-cap', () {
      expect(regionalSuffixOf('pikachu-alola-cap'), isNull);
    });
  });

  group('chainHasFormDetails', () {
    test('returns false when no edge has a base_form', () {
      final root = EvolutionNode(
        speciesId: 1,
        speciesName: 'bulbasaur',
        details: const [],
        evolvesTo: [
          EvolutionNode(
            speciesId: 2,
            speciesName: 'ivysaur',
            details: [_detail(minLevel: 16)],
            evolvesTo: const [],
          ),
        ],
      );
      expect(chainHasFormDetails(root), isFalse);
    });

    test('returns true when any edge has a base_form', () {
      expect(chainHasFormDetails(_zigzagoonChain()), isTrue);
    });
  });

  group('buildFormChain — default chain', () {
    test('stops before Obstagoon (no default edge from Linoone)', () {
      final result = buildFormChain(_zigzagoonChain(), null, 263);
      expect(result.displayId, equals(263));
      expect(result.evolvesTo.length, equals(1));
      final linoone = result.evolvesTo.first;
      expect(linoone.source.speciesName, equals('linoone'));
      expect(linoone.displayId, equals(264));
      expect(linoone.evolvesTo, isEmpty);
    });
  });

  group('buildFormChain — Galarian chain', () {
    test('uses override IDs and includes Obstagoon', () {
      final result = buildFormChain(_zigzagoonChain(), 'galar', 10174);
      expect(result.displayId, equals(10174));
      expect(result.evolvesTo.length, equals(1));
      final linoone = result.evolvesTo.first;
      expect(linoone.source.speciesName, equals('linoone'));
      expect(linoone.displayId, equals(10175));
      expect(linoone.evolvesTo.length, equals(1));
      final obstagoon = linoone.evolvesTo.first;
      expect(obstagoon.source.speciesName, equals('obstagoon'));
      expect(obstagoon.displayId, equals(862));
    });
  });

  group('formLabel', () {
    test('default gen-iii returns Hoennian Form', () {
      expect(formLabel(isDefault: true, varietyName: 'zigzagoon', generationName: 'generation-iii'),
          equals('Hoennian Form'));
    });

    test('default gen-i returns Kantonian Form', () {
      expect(formLabel(isDefault: true, varietyName: 'bulbasaur', generationName: 'generation-i'),
          equals('Kantonian Form'));
    });

    test('galar suffix returns Galarian Form', () {
      expect(formLabel(isDefault: false, varietyName: 'zigzagoon-galar', generationName: null),
          equals('Galarian Form'));
    });

    test('hisui suffix returns Hisuian Form', () {
      expect(formLabel(isDefault: false, varietyName: 'voltorb-hisui', generationName: null),
          equals('Hisuian Form'));
    });

    test('unknown generation falls back to Original Form', () {
      expect(formLabel(isDefault: true, varietyName: 'zigzagoon', generationName: null),
          equals('Original Form'));
    });
  });
}
