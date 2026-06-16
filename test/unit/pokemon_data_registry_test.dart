// test/unit/pokemon_data_registry_test.dart
//
// Tests for PokemonDataRegistry — the singleton that loads all override maps
// from assets/data/pokemon_registry.json at startup.
//
// These tests verify:
//   • JSON is parsed into the correct Dart types (int keys, Sets, named records)
//   • Spot-check values match the JSON source
//   • Missing keys return null rather than throwing
//   • Data-integrity invariants hold (disjoint sets, consistent coverage)

import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  // ── Initialization ─────────────────────────────────────────────────────────

  group('PokemonDataRegistry initialization', () {
    test('instance is non-null after initialize()', () {
      expect(PokemonDataRegistry.instance, isNotNull);
    });

    test('all 23 fields are populated', () {
      final r = PokemonDataRegistry.instance;
      expect(r.psFormExceptions, isNotEmpty);
      expect(r.cosmeticSpriteStems, isNotEmpty);
      expect(r.abilityGatingRules, isNotEmpty);
      expect(r.itemGatingRules, isNotEmpty);
      expect(r.mutableFormSpeciesIds, isNotEmpty);
      expect(r.baseFormNameOverrides, isNotEmpty);
      expect(r.cosmeticFormLabels, isNotEmpty);
      expect(r.cosmeticFormHomeUrlOverrides, isNotEmpty);
      expect(r.cosmeticFormHomeShinyUrlOverrides, isNotEmpty);
      expect(r.baseFormCosmeticHomeUrls, isNotEmpty);
      expect(r.baseFormSuffixOverrides, isNotEmpty);
      expect(r.regionalFormLookup, isNotEmpty);
      expect(r.battleMeaningfulNames, isNotEmpty);
      expect(r.cosmeticVarietyNames, isNotEmpty);
      expect(r.noCosmeticFormsPokemon, isNotEmpty);
      expect(r.cosmeticGenderDiffPokemon, isNotEmpty);
      expect(r.megaStoneMap, isNotEmpty);
      expect(r.formatToVersionGroup, isNotEmpty);
      expect(r.genToVersionGroups, isNotEmpty);
      expect(r.gameIdToVersionPath, isNotEmpty);
      expect(r.genToDefaultGameId, isNotEmpty);
      expect(r.vgToSubpath, isNotEmpty);
      expect(r.genToLastVg, isNotEmpty);
    });
  });

  // ── Type coercion — int-keyed maps ────────────────────────────────────────

  group('int-keyed map parsing', () {
    test('genToVersionGroups keys are ints, not strings', () {
      final r = PokemonDataRegistry.instance;
      // If key coercion failed, int 1 would return null and '1' would succeed.
      expect(r.genToVersionGroups[1], isNotNull);
      expect(r.genToVersionGroups['1' as dynamic], isNull);
    });

    test('genToDefaultGameId keys are ints', () {
      final r = PokemonDataRegistry.instance;
      expect(r.genToDefaultGameId[1], isNotNull);
      expect(r.genToDefaultGameId['1' as dynamic], isNull);
    });

    test('genToLastVg keys are ints', () {
      final r = PokemonDataRegistry.instance;
      expect(r.genToLastVg[1], isNotNull);
      expect(r.genToLastVg['1' as dynamic], isNull);
    });
  });

  // ── Set fields ────────────────────────────────────────────────────────────

  group('Set field types', () {
    test('mutableFormSpeciesIds is a Set<int>', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds, isA<Set<int>>());
    });

    test('battleMeaningfulNames is a Set<String>', () {
      expect(PokemonDataRegistry.instance.battleMeaningfulNames, isA<Set<String>>());
    });

    test('cosmeticVarietyNames is a Set<String>', () {
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isA<Set<String>>());
    });

    test('noCosmeticFormsPokemon is a Set<String>', () {
      expect(PokemonDataRegistry.instance.noCosmeticFormsPokemon, isA<Set<String>>());
    });

    test('cosmeticGenderDiffPokemon is a Set<String>', () {
      expect(PokemonDataRegistry.instance.cosmeticGenderDiffPokemon, isA<Set<String>>());
    });

    test('itemGatingRules values are Set<String>, not List<String>', () {
      final items = PokemonDataRegistry.instance.itemGatingRules['giratina-origin'];
      expect(items, isA<Set<String>>());
    });
  });

  // ── Named record fields ───────────────────────────────────────────────────

  group('named record field access', () {
    test('baseFormCosmeticHomeUrls values expose .homeUrl and .shinyUrl', () {
      final entry = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown'];
      expect(entry, isNotNull);
      expect(entry!.homeUrl, isNotEmpty);
      expect(entry.shinyUrl, isNotEmpty);
    });

    test('megaStoneMap values expose .baseSpecies and .megaForm', () {
      final entry = PokemonDataRegistry.instance.megaStoneMap['charizardite-x'];
      expect(entry, isNotNull);
      expect(entry!.baseSpecies, isNotEmpty);
      expect(entry.megaForm, isNotEmpty);
    });
  });

  // ── psFormExceptions ──────────────────────────────────────────────────────

  group('psFormExceptions', () {
    test('ogerpon-teal maps to ogerpon-teal-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-teal'],
        'ogerpon-teal-mask',
      );
    });

    test('ogerpon-wellspring maps to ogerpon-wellspring-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-wellspring'],
        'ogerpon-wellspring-mask',
      );
    });

    test('ogerpon-hearthflame maps to ogerpon-hearthflame-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-hearthflame'],
        'ogerpon-hearthflame-mask',
      );
    });

    test('ogerpon-cornerstone maps to ogerpon-cornerstone-mask', () {
      expect(
        PokemonDataRegistry.instance.psFormExceptions['ogerpon-cornerstone'],
        'ogerpon-cornerstone-mask',
      );
    });

    test('unknown PS name returns null', () {
      expect(PokemonDataRegistry.instance.psFormExceptions['bulbasaur'], isNull);
    });

    test('all keys are lowercase-hyphenated (no spaces, no uppercase)', () {
      for (final key in PokemonDataRegistry.instance.psFormExceptions.keys) {
        expect(key, equals(key.toLowerCase()), reason: '$key must be lowercase');
        expect(key.contains(' '), isFalse, reason: '$key must use hyphens not spaces');
      }
    });
  });

  // ── cosmeticSpriteStems ───────────────────────────────────────────────────

  group('cosmeticSpriteStems', () {
    test('burmy sandy cloak stem is 412-sandy', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['burmy']?['burmy-sandy'],
        '412-sandy',
      );
    });

    test('burmy trash cloak stem is 412-trash', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['burmy']?['burmy-trash'],
        '412-trash',
      );
    });

    test('shellos east sea stem is 422-east', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['shellos']?['shellos-east'],
        '422-east',
      );
    });

    test('unown-a stem is 201-a', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['unown']?['unown-a'],
        '201-a',
      );
    });

    test('unown has 28 entries (26 letters + ! + ?)', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['unown']?.length,
        28,
      );
    });

    test('unknown species returns null', () {
      expect(
        PokemonDataRegistry.instance.cosmeticSpriteStems['pikachu'],
        isNull,
      );
    });

    test('all stem values follow {id}-{suffix} format', () {
      for (final speciesEntry in PokemonDataRegistry.instance.cosmeticSpriteStems.entries) {
        for (final stem in speciesEntry.value.values) {
          expect(
            stem.contains('-'),
            isTrue,
            reason: 'stem "$stem" for ${speciesEntry.key} must follow {id}-{suffix} format',
          );
        }
      }
    });
  });

  // ── abilityGatingRules ────────────────────────────────────────────────────

  group('abilityGatingRules', () {
    test('aegislash-blade requires stance-change', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['aegislash-blade'],
        'stance-change',
      );
    });

    test('darmanitan-zen requires zen-mode', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['darmanitan-zen'],
        'zen-mode',
      );
    });

    test('darmanitan-galar-zen also requires zen-mode', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['darmanitan-galar-zen'],
        'zen-mode',
      );
    });

    test('morpeko-hangry requires hunger-switch', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['morpeko-hangry'],
        'hunger-switch',
      );
    });

    test('minior-red-core requires shields-down', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['minior-red-core'],
        'shields-down',
      );
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.abilityGatingRules['giratina-origin'],
        isNull,
      );
    });
  });

  // ── itemGatingRules ───────────────────────────────────────────────────────

  group('itemGatingRules', () {
    test('giratina-origin accepts griseous-orb and griseous-core', () {
      final items = PokemonDataRegistry.instance.itemGatingRules['giratina-origin'];
      expect(items, containsAll({'griseous-orb', 'griseous-core'}));
    });

    test('zacian-crowned accepts only rusted-sword', () {
      final items = PokemonDataRegistry.instance.itemGatingRules['zacian-crowned'];
      expect(items, equals({'rusted-sword'}));
    });

    test('calyrex-ice-rider and shadow-rider share reins-of-unity', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['calyrex-ice-rider'],
        contains('reins-of-unity'),
      );
      expect(
        PokemonDataRegistry.instance.itemGatingRules['calyrex-shadow-rider'],
        contains('reins-of-unity'),
      );
    });

    test('groudon-primal accepts red-orb', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['groudon-primal'],
        contains('red-orb'),
      );
    });

    test('kyogre-primal accepts blue-orb but not red-orb', () {
      final items = PokemonDataRegistry.instance.itemGatingRules['kyogre-primal'];
      expect(items, contains('blue-orb'));
      expect(items, isNot(contains('red-orb')));
    });

    test('arceus-fire requires flame-plate', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['arceus-fire'],
        contains('flame-plate'),
      );
    });

    test('arceus-fairy requires pixie-plate', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['arceus-fairy'],
        contains('pixie-plate'),
      );
    });

    test('silvally-water requires water-memory', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['silvally-water'],
        contains('water-memory'),
      );
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.itemGatingRules['bulbasaur'],
        isNull,
      );
    });

    test('ability-gated forms do not appear in item rules', () {
      // Aegislash is ability-gated (stance-change), not item-gated.
      expect(
        PokemonDataRegistry.instance.itemGatingRules['aegislash-blade'],
        isNull,
      );
    });
  });

  // ── mutableFormSpeciesIds ─────────────────────────────────────────────────

  group('mutableFormSpeciesIds', () {
    test('contains Cherrim (421) — toggleable Sunshine form', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds.contains(421), isTrue);
    });

    test('contains Aegislash (681) — toggleable Blade form', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds.contains(681), isTrue);
    });

    test('contains Minior (774) — toggleable Core forms', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds.contains(774), isTrue);
    });

    test('contains Morpeko (877) — toggleable Hangry form', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds.contains(877), isTrue);
    });

    test('does not contain Bulbasaur (1) — no alternate forms', () {
      expect(PokemonDataRegistry.instance.mutableFormSpeciesIds.contains(1), isFalse);
    });
  });

  // ── baseFormNameOverrides ─────────────────────────────────────────────────

  group('baseFormNameOverrides', () {
    test('ogerpon base label is Teal Mask', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['ogerpon'],
        'Teal Mask',
      );
    });

    test('aegislash-shield base label is Shield', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['aegislash-shield'],
        'Shield',
      );
    });

    test('zacian base label is Hero', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['zacian'],
        'Hero',
      );
    });

    test('unown base label is A', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['unown'],
        'A',
      );
    });

    test('giratina-altered base label is Altered', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['giratina-altered'],
        'Altered',
      );
    });

    test('zygarde base label is 50%', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['zygarde'],
        '50%',
      );
    });

    test('unknown species returns null', () {
      expect(
        PokemonDataRegistry.instance.baseFormNameOverrides['pikachu'],
        isNull,
      );
    });
  });

  // ── cosmeticFormLabels ────────────────────────────────────────────────────

  group('cosmeticFormLabels', () {
    test('xerneas-active label is Neutral', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormLabels['xerneas-active'],
        'Neutral',
      );
    });

    test('eiscue-noice label is Noice Face', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormLabels['eiscue-noice'],
        'Noice Face',
      );
    });

    test('magearna-original label is Original Color', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormLabels['magearna-original'],
        'Original Color',
      );
    });

    test('all minior colour variants have a label', () {
      final colours = ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet'];
      for (final colour in colours) {
        expect(
          PokemonDataRegistry.instance.cosmeticFormLabels['minior-$colour'],
          isNotNull,
          reason: 'minior-$colour should have a label',
        );
      }
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormLabels['charizard-mega-x'],
        isNull,
      );
    });
  });

  // ── cosmeticFormHomeUrlOverrides ──────────────────────────────────────────

  group('cosmeticFormHomeUrlOverrides', () {
    test('mimikyu-busted override points to HOME sprite 10143', () {
      final url = PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['mimikyu-busted'];
      expect(url, isNotNull);
      expect(url, contains('10143.png'));
    });

    test('xerneas-active override points to 716-neutral HOME sprite', () {
      final url = PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['pikachu'],
        isNull,
      );
    });
  });

  // ── cosmeticFormHomeShinyUrlOverrides ─────────────────────────────────────

  group('cosmeticFormHomeShinyUrlOverrides', () {
    test('xerneas-active shiny override is in the shiny path', () {
      final url =
          PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
      expect(url, contains('shiny'));
    });

    test('mimikyu-busted shiny override is in the shiny path', () {
      final url =
          PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides['mimikyu-busted'];
      expect(url, isNotNull);
      expect(url, contains('10143.png'));
      expect(url, contains('shiny'));
    });

    test('shiny and non-shiny overrides differ for the same form', () {
      final normal =
          PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['xerneas-active'];
      final shiny =
          PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides['xerneas-active'];
      expect(normal, isNot(equals(shiny)));
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides['pikachu'],
        isNull,
      );
    });
  });

  // ── baseFormCosmeticHomeUrls ──────────────────────────────────────────────

  group('baseFormCosmeticHomeUrls', () {
    test('unown homeUrl points to the A form HOME sprite', () {
      final url = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown']?.homeUrl;
      expect(url, isNotNull);
      expect(url, contains('201-a.png'));
    });

    test('unown shinyUrl is in the shiny path', () {
      final url = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown']?.shinyUrl;
      expect(url, isNotNull);
      expect(url, contains('shiny'));
      expect(url, contains('201-a.png'));
    });

    test('homeUrl and shinyUrl differ', () {
      final entry = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown'];
      expect(entry!.homeUrl, isNot(equals(entry.shinyUrl)));
    });

    test('named fields .homeUrl/.shinyUrl work — positional .\$1/.\$2 would not compile', () {
      // This test serves as a compile-time guard: if the record were positional,
      // .homeUrl would not exist and the file would fail to build.
      final entry = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown']!;
      expect(entry.homeUrl, isA<String>());
      expect(entry.shinyUrl, isA<String>());
    });

    test('unknown species returns null', () {
      expect(
        PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['pikachu'],
        isNull,
      );
    });
  });

  // ── baseFormSuffixOverrides ───────────────────────────────────────────────

  group('baseFormSuffixOverrides', () {
    test('basculin-white-striped suffix is hisui', () {
      expect(
        PokemonDataRegistry.instance.baseFormSuffixOverrides['basculin-white-striped'],
        'hisui',
      );
    });

    test('unknown form returns null', () {
      expect(
        PokemonDataRegistry.instance.baseFormSuffixOverrides['pikachu'],
        isNull,
      );
    });
  });

  // ── regionalFormLookup ────────────────────────────────────────────────────

  group('regionalFormLookup', () {
    test('basculin-hisui resolves to basculin-white-striped', () {
      expect(
        PokemonDataRegistry.instance.regionalFormLookup['basculin-hisui'],
        'basculin-white-striped',
      );
    });

    test('unknown regional name returns null', () {
      expect(
        PokemonDataRegistry.instance.regionalFormLookup['pikachu-hisui'],
        isNull,
      );
    });
  });

  // ── battleMeaningfulNames ─────────────────────────────────────────────────

  group('battleMeaningfulNames', () {
    test('contains meowstic-female', () {
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('meowstic-female'),
        isTrue,
      );
    });

    test('contains all 5 Rotom appliances', () {
      for (final form in ['rotom-heat', 'rotom-wash', 'rotom-frost', 'rotom-fan', 'rotom-mow']) {
        expect(
          PokemonDataRegistry.instance.battleMeaningfulNames.contains(form),
          isTrue,
          reason: '$form should be battle-meaningful',
        );
      }
    });

    test('contains urshifu-rapid-strike', () {
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('urshifu-rapid-strike'),
        isTrue,
      );
    });

    test('contains Ogerpon masked forms (battle-meaningful, not cosmetic)', () {
      for (final form in [
        'ogerpon-wellspring-mask',
        'ogerpon-hearthflame-mask',
        'ogerpon-cornerstone-mask',
      ]) {
        expect(
          PokemonDataRegistry.instance.battleMeaningfulNames.contains(form),
          isTrue,
          reason: '$form should be battle-meaningful',
        );
      }
    });

    test('does not contain cosmetic-only forms', () {
      // Wormadam cloaks are cosmetic, not battle-meaningful.
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('wormadam-sandy'),
        isFalse,
      );
    });

    test('does not contain mega or gmax forms (handled by separate toggle)', () {
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('charizard-mega-x'),
        isFalse,
      );
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('charizard-gmax'),
        isFalse,
      );
    });

    test('contains necrozma-dusk and necrozma-dawn (not -dusk-mane or -dawn-wings)', () {
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('necrozma-dusk'),
        isTrue,
      );
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('necrozma-dawn'),
        isTrue,
      );
      // Verify the common trap names are NOT present.
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('necrozma-dusk-mane'),
        isFalse,
      );
      expect(
        PokemonDataRegistry.instance.battleMeaningfulNames.contains('necrozma-dawn-wings'),
        isFalse,
      );
    });
  });

  // ── cosmeticVarietyNames ──────────────────────────────────────────────────

  group('cosmeticVarietyNames', () {
    test('contains Wormadam cosmetic cloaks', () {
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames,
        containsAll({'wormadam-sandy', 'wormadam-trash'}),
      );
    });

    test('contains Minior core colour variants', () {
      for (final colour in ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet']) {
        expect(
          PokemonDataRegistry.instance.cosmeticVarietyNames.contains('minior-$colour'),
          isTrue,
          reason: 'minior-$colour should be in cosmeticVarietyNames',
        );
      }
    });

    test('contains morpeko-hangry', () {
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames.contains('morpeko-hangry'),
        isTrue,
      );
    });

    test('contains mimikyu-busted', () {
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames.contains('mimikyu-busted'),
        isTrue,
      );
    });

    test('contains keldeo-resolute', () {
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames.contains('keldeo-resolute'),
        isTrue,
      );
    });

    test('does not contain battle-meaningful forms', () {
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames.contains('giratina-origin'),
        isFalse,
      );
      expect(
        PokemonDataRegistry.instance.cosmeticVarietyNames.contains('meowstic-female'),
        isFalse,
      );
    });
  });

  // ── noCosmeticFormsPokemon ────────────────────────────────────────────────

  group('noCosmeticFormsPokemon', () {
    test('contains mothim — its form entries are male-only, not cosmetic', () {
      expect(
        PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains('mothim'),
        isTrue,
      );
    });

    test('does not contain burmy — burmy HAS cosmetic cloak forms', () {
      expect(
        PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains('burmy'),
        isFalse,
      );
    });
  });

  // ── cosmeticGenderDiffPokemon ─────────────────────────────────────────────

  group('cosmeticGenderDiffPokemon', () {
    test('contains unfezant — female has a distinct breast pattern', () {
      expect(
        PokemonDataRegistry.instance.cosmeticGenderDiffPokemon.contains('unfezant'),
        isTrue,
      );
    });
  });

  // ── megaStoneMap ──────────────────────────────────────────────────────────

  group('megaStoneMap', () {
    test('charizardite-x → charizard + charizard-mega-x', () {
      final e = PokemonDataRegistry.instance.megaStoneMap['charizardite-x'];
      expect(e?.baseSpecies, 'charizard');
      expect(e?.megaForm, 'charizard-mega-x');
    });

    test('charizardite-y → charizard + charizard-mega-y', () {
      final e = PokemonDataRegistry.instance.megaStoneMap['charizardite-y'];
      expect(e?.baseSpecies, 'charizard');
      expect(e?.megaForm, 'charizard-mega-y');
    });

    test('mewtwonite-x → mewtwo + mewtwo-mega-x', () {
      final e = PokemonDataRegistry.instance.megaStoneMap['mewtwonite-x'];
      expect(e?.baseSpecies, 'mewtwo');
      expect(e?.megaForm, 'mewtwo-mega-x');
    });

    test('diancite → diancie + diancie-mega (last entry)', () {
      final e = PokemonDataRegistry.instance.megaStoneMap['diancite'];
      expect(e?.baseSpecies, 'diancie');
      expect(e?.megaForm, 'diancie-mega');
    });

    test('venusaurite → venusaur + venusaur-mega', () {
      final e = PokemonDataRegistry.instance.megaStoneMap['venusaurite'];
      expect(e?.baseSpecies, 'venusaur');
      expect(e?.megaForm, 'venusaur-mega');
    });

    test('unknown item returns null', () {
      expect(PokemonDataRegistry.instance.megaStoneMap['leftovers'], isNull);
    });

    test('all megaForm values end in -mega, -mega-x, or -mega-y', () {
      for (final entry in PokemonDataRegistry.instance.megaStoneMap.entries) {
        final form = entry.value.megaForm;
        final valid = form.endsWith('-mega') ||
            form.endsWith('-mega-x') ||
            form.endsWith('-mega-y');
        expect(valid, isTrue, reason: '"${entry.key}" has unexpected megaForm "$form"');
      }
    });

    test('all entries have non-empty baseSpecies and megaForm', () {
      for (final entry in PokemonDataRegistry.instance.megaStoneMap.entries) {
        expect(
          entry.value.baseSpecies,
          isNotEmpty,
          reason: '${entry.key} has empty baseSpecies',
        );
        expect(
          entry.value.megaForm,
          isNotEmpty,
          reason: '${entry.key} has empty megaForm',
        );
      }
    });
  });

  // ── formatToVersionGroup ──────────────────────────────────────────────────

  group('formatToVersionGroup', () {
    test('sv maps to scarlet-violet', () {
      expect(PokemonDataRegistry.instance.formatToVersionGroup['sv'], 'scarlet-violet');
    });

    test('rb maps to red-blue', () {
      expect(PokemonDataRegistry.instance.formatToVersionGroup['rb'], 'red-blue');
    });

    test('bw maps to black-white', () {
      expect(PokemonDataRegistry.instance.formatToVersionGroup['bw'], 'black-white');
    });

    test('unknown format id returns null', () {
      expect(PokemonDataRegistry.instance.formatToVersionGroup['gen1'], isNull);
    });
  });

  // ── genToVersionGroups ────────────────────────────────────────────────────

  group('genToVersionGroups', () {
    test('gen 1 contains red-blue and yellow', () {
      expect(
        PokemonDataRegistry.instance.genToVersionGroups[1],
        containsAll(['red-blue', 'yellow']),
      );
    });

    test('gen 9 contains scarlet-violet', () {
      expect(
        PokemonDataRegistry.instance.genToVersionGroups[9],
        contains('scarlet-violet'),
      );
    });

    test('gen 8 contains sword-shield and legends-arceus', () {
      expect(
        PokemonDataRegistry.instance.genToVersionGroups[8],
        containsAll(['sword-shield', 'legends-arceus']),
      );
    });

    test('covers all 9 generations', () {
      expect(PokemonDataRegistry.instance.genToVersionGroups.length, 9);
    });

    test('unknown generation returns null', () {
      expect(PokemonDataRegistry.instance.genToVersionGroups[0], isNull);
    });
  });

  // ── gameIdToVersionPath ───────────────────────────────────────────────────

  group('gameIdToVersionPath', () {
    test('bw maps to generation-v/black-white', () {
      expect(
        PokemonDataRegistry.instance.gameIdToVersionPath['bw'],
        'generation-v/black-white',
      );
    });

    test('b2w2 maps to the same path as bw (shared sprite folder)', () {
      expect(
        PokemonDataRegistry.instance.gameIdToVersionPath['b2w2'],
        PokemonDataRegistry.instance.gameIdToVersionPath['bw'],
      );
    });

    test('yellow maps to generation-i/yellow', () {
      expect(
        PokemonDataRegistry.instance.gameIdToVersionPath['yellow'],
        'generation-i/yellow',
      );
    });

    test('Gen 6+ game ids are absent (they use HOME artwork)', () {
      expect(PokemonDataRegistry.instance.gameIdToVersionPath['xy'], isNull);
      expect(PokemonDataRegistry.instance.gameIdToVersionPath['oras'], isNull);
      expect(PokemonDataRegistry.instance.gameIdToVersionPath['sv'], isNull);
    });
  });

  // ── genToDefaultGameId ────────────────────────────────────────────────────

  group('genToDefaultGameId', () {
    test('gen 1 default is yellow', () {
      expect(PokemonDataRegistry.instance.genToDefaultGameId[1], 'yellow');
    });

    test('gen 2 default is crystal', () {
      expect(PokemonDataRegistry.instance.genToDefaultGameId[2], 'crystal');
    });

    test('gen 5 default is bw', () {
      expect(PokemonDataRegistry.instance.genToDefaultGameId[5], 'bw');
    });

    test('gen 6 has no default game (uses HOME artwork, not versioned sprites)', () {
      expect(PokemonDataRegistry.instance.genToDefaultGameId[6], isNull);
    });

    test('covers exactly gens 1–5', () {
      expect(PokemonDataRegistry.instance.genToDefaultGameId.length, 5);
    });
  });

  // ── vgToSubpath ───────────────────────────────────────────────────────────

  group('vgToSubpath', () {
    test('Gen 1-5 version groups have non-null subpaths', () {
      for (final vg in [
        'red-blue', 'yellow', 'gold-silver', 'crystal',
        'ruby-sapphire', 'emerald', 'firered-leafgreen',
        'diamond-pearl', 'platinum', 'heartgold-soulsilver',
        'black-white', 'black-2-white-2',
      ]) {
        expect(
          PokemonDataRegistry.instance.vgToSubpath[vg],
          isNotNull,
          reason: '$vg should have a sprite subpath',
        );
      }
    });

    test('Gen 6+ version groups have null subpaths (use HOME artwork)', () {
      for (final vg in [
        'x-y', 'omega-ruby-alpha-sapphire',
        'sun-moon', 'ultra-sun-ultra-moon',
        'sword-shield', 'brilliant-diamond-and-shining-pearl',
        'legends-arceus', 'scarlet-violet',
      ]) {
        expect(
          PokemonDataRegistry.instance.vgToSubpath[vg],
          isNull,
          reason: '$vg should have a null subpath (HOME/artwork path)',
        );
      }
    });

    test('contains an entry for lets-go-pikachu-lets-go-eevee (null — uses HOME)', () {
      expect(
        PokemonDataRegistry.instance.vgToSubpath.containsKey('lets-go-pikachu-lets-go-eevee'),
        isTrue,
      );
      expect(
        PokemonDataRegistry.instance.vgToSubpath['lets-go-pikachu-lets-go-eevee'],
        isNull,
      );
    });

    test('absent version group key returns null (not throws)', () {
      expect(PokemonDataRegistry.instance.vgToSubpath['not-a-game'], isNull);
    });
  });

  // ── genToLastVg ───────────────────────────────────────────────────────────

  group('genToLastVg', () {
    test('gen 1 last vg is yellow', () {
      expect(PokemonDataRegistry.instance.genToLastVg[1], 'yellow');
    });

    test('gen 5 last vg is black-white', () {
      expect(PokemonDataRegistry.instance.genToLastVg[5], 'black-white');
    });

    test('gen 9 last vg is scarlet-violet', () {
      expect(PokemonDataRegistry.instance.genToLastVg[9], 'scarlet-violet');
    });

    test('covers all 9 generations', () {
      expect(PokemonDataRegistry.instance.genToLastVg.length, 9);
    });

    test('each last vg is present in genToVersionGroups for the same gen', () {
      for (final entry in PokemonDataRegistry.instance.genToLastVg.entries) {
        final groups = PokemonDataRegistry.instance.genToVersionGroups[entry.key];
        expect(
          groups,
          contains(entry.value),
          reason: '${entry.value} should be in genToVersionGroups[${entry.key}]',
        );
      }
    });
  });

  // ── Data integrity ────────────────────────────────────────────────────────

  group('data integrity', () {
    test('battleMeaningfulNames and cosmeticVarietyNames are disjoint', () {
      final battle = PokemonDataRegistry.instance.battleMeaningfulNames;
      final cosmetic = PokemonDataRegistry.instance.cosmeticVarietyNames;
      final overlap = battle.intersection(cosmetic);
      expect(
        overlap,
        isEmpty,
        reason: 'Forms in both sets would appear as both a tab chip and a cosmetic chip',
      );
    });

    test('all genToLastVg values are in vgToSubpath', () {
      for (final vg in PokemonDataRegistry.instance.genToLastVg.values) {
        expect(
          PokemonDataRegistry.instance.vgToSubpath.containsKey(vg),
          isTrue,
          reason: '$vg (from genToLastVg) has no entry in vgToSubpath',
        );
      }
    });

    test('all genToDefaultGameId values are keys in gameIdToVersionPath', () {
      for (final gameId in PokemonDataRegistry.instance.genToDefaultGameId.values) {
        expect(
          PokemonDataRegistry.instance.gameIdToVersionPath.containsKey(gameId),
          isTrue,
          reason: 'Default game "$gameId" has no sprite path in gameIdToVersionPath',
        );
      }
    });

    test('genToVersionGroups version groups all appear in vgToSubpath or formatToVersionGroup', () {
      final allVgs =
          PokemonDataRegistry.instance.genToVersionGroups.values.expand((l) => l).toSet();
      final knownVgs = {
        ...PokemonDataRegistry.instance.vgToSubpath.keys,
        ...PokemonDataRegistry.instance.formatToVersionGroup.values,
      };
      for (final vg in allVgs) {
        expect(
          knownVgs.contains(vg),
          isTrue,
          reason: 'Version group "$vg" is in genToVersionGroups but has no sprite or format entry',
        );
      }
    });
  });
}
