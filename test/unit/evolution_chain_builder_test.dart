import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

EvolutionDetail _detail({
  String? baseFormName,
  int? baseFormId,
  String? regionName,
  int? minLevel,
}) =>
    EvolutionDetail(
      trigger: 'level-up',
      minLevel: minLevel,
      baseForm: baseFormName != null && baseFormId != null
          ? (name: baseFormName, id: baseFormId)
          : null,
      region: regionName != null ? (name: regionName) : null,
    );

// Zigzagoon chain: two details on Linoone edge (default + galar base_form),
// one galar-only detail on Obstagoon edge.
EvolutionNode _zigzagoonChain() => EvolutionNode(
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

// Mime Jr chain: region-keyed edge to Mr. Mime, then base_form edge to Mr. Rime.
EvolutionNode _mimeJrChain() => EvolutionNode(
      speciesId: 439,
      speciesName: 'mime-jr',
      details: const [],
      evolvesTo: [
        EvolutionNode(
          speciesId: 122,
          speciesName: 'mr-mime',
          details: [
            _detail(minLevel: 1),
            _detail(regionName: 'galar', minLevel: 1),
          ],
          evolvesTo: [
            EvolutionNode(
              speciesId: 866,
              speciesName: 'mr-rime',
              details: [
                _detail(baseFormName: 'mr-mime-galar', baseFormId: 10168, minLevel: 42),
              ],
              evolvesTo: const [],
            ),
          ],
        ),
      ],
    );

void main() {
  group('isRegionalVariety', () {
    test('false for default', () {
      expect(isRegionalVariety(const PokemonVariety(isDefault: true, name: 'zigzagoon')), isFalse);
    });
    test('true for -galar', () {
      expect(isRegionalVariety(const PokemonVariety(isDefault: false, name: 'zigzagoon-galar')), isTrue);
    });
    test('true for -alola, -hisui, -paldea', () {
      for (final s in ['-alola', '-hisui', '-paldea']) {
        expect(isRegionalVariety(PokemonVariety(isDefault: false, name: 'meowth$s')), isTrue);
      }
    });
    test('false for -mega, -gmax, cap', () {
      for (final n in ['charizard-mega-x', 'pikachu-alola-cap', 'venusaur-gmax']) {
        expect(isRegionalVariety(PokemonVariety(isDefault: false, name: n)), isFalse);
      }
    });
  });

  group('regionalSuffixOf', () {
    test('returns galar', () => expect(regionalSuffixOf('zigzagoon-galar'), 'galar'));
    test('null for plain', () => expect(regionalSuffixOf('zigzagoon'), isNull));
    test('null for cap', () => expect(regionalSuffixOf('pikachu-alola-cap'), isNull));
  });

  group('chainHasFormDetails', () {
    test('false for plain chain', () {
      final root = EvolutionNode(
        speciesId: 1, speciesName: 'bulbasaur', details: const [],
        evolvesTo: [
          EvolutionNode(speciesId: 2, speciesName: 'ivysaur',
              details: [_detail(minLevel: 16)], evolvesTo: const []),
        ],
      );
      expect(chainHasFormDetails(root), isFalse);
    });
    test('true for zigzagoon (base_form on edge)', () {
      expect(chainHasFormDetails(_zigzagoonChain()), isTrue);
    });
  });

  group('formSuffixForSpecies', () {
    test('returns galar for obstagoon (only galar edge reaches it)', () {
      expect(formSuffixForSpecies(_zigzagoonChain(), 862), 'galar');
    });
    test('returns galar for mr-rime', () {
      expect(formSuffixForSpecies(_mimeJrChain(), 866), 'galar');
    });
    test('null for species reachable via default edge', () {
      expect(formSuffixForSpecies(_zigzagoonChain(), 264), isNull);
    });
  });

  group('buildFormChain — default (null suffix)', () {
    test('zigzagoon: stops before obstagoon', () {
      final result = buildFormChain(_zigzagoonChain(), null, 263);
      expect(result.displayId, 263);
      expect(result.evolvesTo.length, 1);
      final linoone = result.evolvesTo.first;
      expect(linoone.displayId, 264);
      expect(linoone.evolvesTo, isEmpty);
    });
  });

  group('buildFormChain — galar suffix', () {
    test('zigzagoon: uses override IDs, includes obstagoon', () {
      final result = buildFormChain(_zigzagoonChain(), 'galar', 10174);
      expect(result.displayId, 10174);
      final linoone = result.evolvesTo.first;
      expect(linoone.displayId, 10175);
      expect(linoone.evolvesTo.first.displayId, 862);
    });
    test('mime-jr: galar chain via region edge → mr-mime-galar → mr-rime', () {
      final formIds = {'mr-mime-galar': 10168};
      final result = buildFormChain(_mimeJrChain(), 'galar', 439, formIds: formIds);
      expect(result.displayId, 439);
      final mrMime = result.evolvesTo.first;
      expect(mrMime.displayId, 10168);
      expect(mrMime.evolvesTo.first.source.speciesId, 866);
    });
  });

  group('formLabel', () {
    test('gen-iii → Hoennian Form', () {
      expect(formLabel(isDefault: true, varietyName: 'zigzagoon', generationName: 'generation-iii'),
          'Hoennian Form');
    });
    test('gen-i → Kantonian Form', () {
      expect(formLabel(isDefault: true, varietyName: 'meowth', generationName: 'generation-i'),
          'Kantonian Form');
    });
    test('-galar → Galarian Form', () {
      expect(formLabel(isDefault: false, varietyName: 'zigzagoon-galar', generationName: null),
          'Galarian Form');
    });
    test('unknown gen → Original Form', () {
      expect(formLabel(isDefault: true, varietyName: 'x', generationName: null), 'Original Form');
    });
  });

  group('shortFormLabel', () {
    test('plain galar suffix → Galarian', () {
      expect(shortFormLabel('zigzagoon-galar'), 'Galarian');
    });
    test('plain alola suffix → Alolan', () {
      expect(shortFormLabel('vulpix-alola'), 'Alolan');
    });
    test('paldea sub-form → regional adjective + sub-form label', () {
      expect(shortFormLabel('tauros-paldea-combat-breed'), 'Paldean Combat Breed');
      expect(shortFormLabel('tauros-paldea-blaze-breed'), 'Paldean Blaze Breed');
      expect(shortFormLabel('tauros-paldea-aqua-breed'), 'Paldean Aqua Breed');
    });
    test('mr-mime-galar → Galarian (not just last segment)', () {
      expect(shortFormLabel('mr-mime-galar'), 'Galarian');
    });
    test('darmanitan-galar-standard → Galarian (override)', () {
      expect(shortFormLabel('darmanitan-galar-standard'), 'Galarian');
    });
    test('darmanitan-galar-zen → Galarian Zen', () {
      expect(shortFormLabel('darmanitan-galar-zen'), 'Galarian Zen');
    });
    test('darmanitan-zen → Unovan Zen (override)', () {
      expect(shortFormLabel('darmanitan-zen'), 'Unovan Zen');
    });
  });

  group('regionalSuffixOf — compound forms', () {
    test('darmanitan-galar-standard → galar', () {
      expect(regionalSuffixOf('darmanitan-galar-standard'), 'galar');
    });
    test('darmanitan-galar-zen → galar', () {
      expect(regionalSuffixOf('darmanitan-galar-zen'), 'galar');
    });
    test('tauros-paldea-combat-breed → paldea', () {
      expect(regionalSuffixOf('tauros-paldea-combat-breed'), 'paldea');
    });
    test('darmanitan-zen → null (no regional infix)', () {
      expect(regionalSuffixOf('darmanitan-zen'), isNull);
    });
  });
}
