// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  // ── cosmeticFormLabel ──────────────────────────────────────────────────────

  group('cosmeticFormLabel', () {
    test('single word → capitalised', () => expect(cosmeticFormLabel('sandy'), 'Sandy'));
    test('hyphenated → title case words', () => expect(cosmeticFormLabel('red-flower'), 'Red Flower'));
    test('single letter (Unown A)', () => expect(cosmeticFormLabel('a'), 'A'));
    test('single letter (Unown Z)', () => expect(cosmeticFormLabel('z'), 'Z'));
    test('punctuation form names', () {
      expect(cosmeticFormLabel('exclamation'), 'Exclamation');
      expect(cosmeticFormLabel('question'), 'Question');
    });
    test('multi-segment Vivillon', () => expect(cosmeticFormLabel('icy-snow'), 'Icy Snow'));
    test('empty string → Default', () => expect(cosmeticFormLabel(''), 'Default'));
    test('female gender form', () => expect(cosmeticFormLabel('female'), 'Female'));
    test('trash cloak', () => expect(cosmeticFormLabel('trash'), 'Trash'));
    test('east sea', () => expect(cosmeticFormLabel('east'), 'East'));
    // Note: "active" returns "Active" — the Xerneas label override is applied externally
    // via cosmeticFormLabels, not inside cosmeticFormLabel itself.
    test('raw active → Active (override applied separately)', () =>
        expect(cosmeticFormLabel('active'), 'Active'));
  });

  // ── cosmeticFormLabels overrides ──────────────────────────────────────────

  group('cosmeticFormLabels', () {
    test('xerneas-active chip relabeled Neutral', () =>
        expect(PokemonDataRegistry.instance.cosmeticFormLabels['xerneas-active'], 'Neutral'));
    test('forms without overrides return null', () {
      expect(PokemonDataRegistry.instance.cosmeticFormLabels['sandy'], isNull);
      expect(PokemonDataRegistry.instance.cosmeticFormLabels['frillish-female'], isNull);
      expect(PokemonDataRegistry.instance.cosmeticFormLabels['unown-b'], isNull);
    });
  });

  // ── baseFormCosmeticHomeUrls ───────────────────────────────────────────────

  group('baseFormCosmeticHomeUrls', () {
    test('unown maps to form-A HOME artwork', () {
      final entry = PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['unown'];
      expect(entry, isNotNull);
      expect(entry!.homeUrl, contains('201-a.png'));
      expect(entry.homeUrl, isNot(contains('/shiny/')));
      expect(entry.shinyUrl, contains('201-a.png'));
      expect(entry.shinyUrl, contains('/shiny/'));
    });
    test('non-overridden species return null', () {
      expect(PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['pikachu'], isNull);
      expect(PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['frillish'], isNull);
      expect(PokemonDataRegistry.instance.baseFormCosmeticHomeUrls['burmy'], isNull);
    });
  });

  // ── cosmeticFormHomeUrlOverrides ──────────────────────────────────────────

  group('cosmeticFormHomeUrlOverrides', () {
    test('xerneas-active → neutral HOME URL (not active)', () {
      final url = PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
      expect(url, isNot(contains('active')));
    });
    test('xerneas-active shiny → neutral shiny HOME URL', () {
      final url = PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
      expect(url, contains('/shiny/'));
    });
    test('forms without overrides return null', () {
      expect(PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['burmy-sandy'], isNull);
      expect(PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['unown-b'], isNull);
      expect(PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides['frillish-female'], isNull);
    });
  });

  // ── cosmeticVarietyNames ──────────────────────────────────────────────────

  group('cosmeticVarietyNames', () {
    test('Wormadam cloaks included', () =>
        expect(PokemonDataRegistry.instance.cosmeticVarietyNames, containsAll(['wormadam-sandy', 'wormadam-trash'])));
    test('Squawkabilly plumages included (non-default only)', () {
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, containsAll([
        'squawkabilly-blue-plumage', 'squawkabilly-yellow-plumage', 'squawkabilly-white-plumage',
      ]));
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('squawkabilly-green-plumage')));
    });
    test('Tatsugiri shapes included (non-default only)', () {
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, containsAll(['tatsugiri-droopy', 'tatsugiri-stretchy']));
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('tatsugiri-curly')));
    });
    test('Dudunsparce three-segment included', () {
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, contains('dudunsparce-three-segment'));
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('dudunsparce-two-segment')));
    });
    test('Basculin blue-striped included (Unovan stripe variant)', () =>
        expect(PokemonDataRegistry.instance.cosmeticVarietyNames, contains('basculin-blue-striped')));
    test('Regional forms NOT in cosmetic varieties (handled by battle switcher)', () {
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('meowth-galar')));
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('zigzagoon-galar')));
      expect(PokemonDataRegistry.instance.cosmeticVarietyNames, isNot(contains('basculin-white-striped')));
    });
  });

  // ── cosmeticFormHomeUrl / cosmeticFormHomeShinyUrl ────────────────────────

  group('cosmeticFormHomeUrl', () {
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    test('Burmy Sandy cloak HOME URL', () =>
        expect(cosmeticFormHomeUrl(412, 'sandy'), '$base/other/home/412-sandy.png'));
    test('Burmy Trash cloak HOME URL', () =>
        expect(cosmeticFormHomeUrl(412, 'trash'), '$base/other/home/412-trash.png'));
    test('Shellos East Sea HOME URL', () =>
        expect(cosmeticFormHomeUrl(422, 'east'), '$base/other/home/422-east.png'));
    test('Unown B HOME URL', () =>
        expect(cosmeticFormHomeUrl(201, 'b'), '$base/other/home/201-b.png'));
    test('Shiny Burmy Sandy HOME URL', () =>
        expect(cosmeticFormHomeShinyUrl(412, 'sandy'), '$base/other/home/shiny/412-sandy.png'));
    test('Shiny Unown B HOME URL', () =>
        expect(cosmeticFormHomeShinyUrl(201, 'b'), '$base/other/home/shiny/201-b.png'));
  });

  // ── shortFormLabel ────────────────────────────────────────────────────────

  group('shortFormLabel', () {
    test('plain regional suffix → adjective', () {
      expect(shortFormLabel('zigzagoon-galar'), 'Galarian');
      expect(shortFormLabel('vulpix-alola'), 'Alolan');
      expect(shortFormLabel('voltorb-hisui'), 'Hisuian');
      expect(shortFormLabel('tauros-paldea'), 'Paldean');
    });
    test('Paldean sub-forms → regional adjective + label', () {
      expect(shortFormLabel('tauros-paldea-combat-breed'), 'Paldean Combat Breed');
      expect(shortFormLabel('tauros-paldea-blaze-breed'), 'Paldean Blaze Breed');
      expect(shortFormLabel('tauros-paldea-aqua-breed'), 'Paldean Aqua Breed');
    });
    test('Galarian sub-forms → Galarian + label', () {
      expect(shortFormLabel('darmanitan-galar-zen'), 'Galarian Zen');
    });
    test('hyphenated base name (mr-mime-galar) → Galarian', () =>
        expect(shortFormLabel('mr-mime-galar'), 'Galarian'));
    test('specific overrides', () {
      expect(shortFormLabel('darmanitan-zen'), 'Unovan Zen');
      expect(shortFormLabel('darmanitan-galar-standard'), 'Galarian');
      expect(shortFormLabel('urshifu-rapid-strike'), 'Rapid Strike');
      expect(shortFormLabel("oricorio-pau"), "Pa'u");
      expect(shortFormLabel('oricorio-pom-pom'), 'Pom-Pom');
      expect(shortFormLabel('toxtricity-low-key'), 'Low Key');
    });
    test('pikachu-alola-cap NOT treated as Alolan (cap suffix blocks it)', () =>
        expect(shortFormLabel('pikachu-alola-cap'), isNot('Alolan')));
    test('fallback capitalises last segment', () {
      expect(shortFormLabel('somespecies-trash'), 'Trash');
      expect(shortFormLabel('somespecies-east'), 'East');
    });
  });

  // ── shortBaseFormLabel ─────────────────────────────────────────────────────

  group('shortBaseFormLabel', () {
    test('generation-i → Kantonian', () => expect(shortBaseFormLabel('generation-i'), 'Kantonian'));
    test('generation-ii → Johtonian', () => expect(shortBaseFormLabel('generation-ii'), 'Johtonian'));
    test('generation-iii → Hoennian', () => expect(shortBaseFormLabel('generation-iii'), 'Hoennian'));
    test('generation-iv → Sinnohian', () => expect(shortBaseFormLabel('generation-iv'), 'Sinnohian'));
    test('generation-v → Unovan', () => expect(shortBaseFormLabel('generation-v'), 'Unovan'));
    test('generation-vi → Kalosian', () => expect(shortBaseFormLabel('generation-vi'), 'Kalosian'));
    test('generation-vii → Alolan', () => expect(shortBaseFormLabel('generation-vii'), 'Alolan'));
    test('generation-viii → Galarian', () => expect(shortBaseFormLabel('generation-viii'), 'Galarian'));
    test('generation-ix → Paldean', () => expect(shortBaseFormLabel('generation-ix'), 'Paldean'));
    test('null → Original', () => expect(shortBaseFormLabel(null), 'Original'));
    test('unknown generation → Original', () => expect(shortBaseFormLabel('generation-x'), 'Original'));
  });

  // ── baseFormNameOverrides — PokéAPI name accuracy ──────────────────────────

  group('baseFormNameOverrides — PokéAPI name accuracy', () {
    // Keys must match exactly what GET /pokemon/{id} returns as `name`.
    test('lycanroc default is lycanroc-midday (not lycanroc)', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['lycanroc-midday'], 'Midday');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['lycanroc'], isNull);
    });
    test('urshifu default is urshifu-single-strike (not urshifu)', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['urshifu-single-strike'], 'Single Strike');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['urshifu'], isNull);
    });
    test('palafin default is palafin-zero (not palafin)', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['palafin-zero'], 'Zero');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['palafin'], isNull);
    });
    test('oricorio default is oricorio-baile (not oricorio)', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['oricorio-baile'], 'Baile');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['oricorio'], isNull);
    });
    test('zacian and zamazenta are plain species names', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['zacian'], 'Hero');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['zamazenta'], 'Hero');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['zacian-hero'], isNull);
    });
    test('frillish-male and jellicent-male → Male', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['frillish-male'], 'Male');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['jellicent-male'], 'Male');
    });
    test('basculin default is basculin-red-striped', () =>
        expect(PokemonDataRegistry.instance.baseFormNameOverrides['basculin-red-striped'], 'Red-Striped'));
    test('variety cosmetic form defaults', () {
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['wormadam-plant'], 'Plant');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['squawkabilly-green-plumage'], 'Green Plumage');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['tatsugiri-curly'], 'Curly');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['dudunsparce-two-segment'], 'Two Segment');
      expect(PokemonDataRegistry.instance.baseFormNameOverrides['floette'], 'Red Flower');
    });
  });
}
