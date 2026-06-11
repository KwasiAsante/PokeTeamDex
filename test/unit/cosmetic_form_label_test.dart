// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';

void main() {
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
    // via kCosmeticFormLabels, not inside cosmeticFormLabel itself.
    test('raw active → Active (override applied separately)', () =>
        expect(cosmeticFormLabel('active'), 'Active'));
  });

  // ── kCosmeticFormLabels overrides ─────────────────────────────────────────

  group('kCosmeticFormLabels', () {
    test('xerneas-active chip relabeled Neutral', () =>
        expect(kCosmeticFormLabels['xerneas-active'], 'Neutral'));
    test('forms without overrides return null', () {
      expect(kCosmeticFormLabels['sandy'], isNull);
      expect(kCosmeticFormLabels['frillish-female'], isNull);
      expect(kCosmeticFormLabels['unown-b'], isNull);
    });
  });

  // ── kBaseFormCosmeticHomeUrls ──────────────────────────────────────────────

  group('kBaseFormCosmeticHomeUrls', () {
    test('unown maps to form-A HOME artwork', () {
      final entry = kBaseFormCosmeticHomeUrls['unown'];
      expect(entry, isNotNull);
      expect(entry!.$1, contains('201-a.png'));
      expect(entry.$1, isNot(contains('/shiny/')));
      expect(entry.$2, contains('201-a.png'));
      expect(entry.$2, contains('/shiny/'));
    });
    test('non-overridden species return null', () {
      expect(kBaseFormCosmeticHomeUrls['pikachu'], isNull);
      expect(kBaseFormCosmeticHomeUrls['frillish'], isNull);
      expect(kBaseFormCosmeticHomeUrls['burmy'], isNull);
    });
  });

  // ── kCosmeticFormHomeUrlOverrides ─────────────────────────────────────────

  group('kCosmeticFormHomeUrlOverrides', () {
    test('xerneas-active → neutral HOME URL (not active)', () {
      final url = kCosmeticFormHomeUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
      expect(url, isNot(contains('active')));
    });
    test('xerneas-active shiny → neutral shiny HOME URL', () {
      final url = kCosmeticFormHomeShinyUrlOverrides['xerneas-active'];
      expect(url, isNotNull);
      expect(url, contains('716-neutral.png'));
      expect(url, contains('/shiny/'));
    });
    test('forms without overrides return null', () {
      expect(kCosmeticFormHomeUrlOverrides['burmy-sandy'], isNull);
      expect(kCosmeticFormHomeUrlOverrides['unown-b'], isNull);
      expect(kCosmeticFormHomeUrlOverrides['frillish-female'], isNull);
    });
  });

  // ── kCosmeticVarietyNames ─────────────────────────────────────────────────

  group('kCosmeticVarietyNames', () {
    test('Wormadam cloaks included', () =>
        expect(kCosmeticVarietyNames, containsAll(['wormadam-sandy', 'wormadam-trash'])));
    test('Squawkabilly plumages included (non-default only)', () {
      expect(kCosmeticVarietyNames, containsAll([
        'squawkabilly-blue-plumage', 'squawkabilly-yellow-plumage', 'squawkabilly-white-plumage',
      ]));
      expect(kCosmeticVarietyNames, isNot(contains('squawkabilly-green-plumage')));
    });
    test('Tatsugiri shapes included (non-default only)', () {
      expect(kCosmeticVarietyNames, containsAll(['tatsugiri-droopy', 'tatsugiri-stretchy']));
      expect(kCosmeticVarietyNames, isNot(contains('tatsugiri-curly')));
    });
    test('Dudunsparce three-segment included', () {
      expect(kCosmeticVarietyNames, contains('dudunsparce-three-segment'));
      expect(kCosmeticVarietyNames, isNot(contains('dudunsparce-two-segment')));
    });
    test('Basculin blue-striped included (Unovan stripe variant)', () =>
        expect(kCosmeticVarietyNames, contains('basculin-blue-striped')));
    test('Regional forms NOT in cosmetic varieties (handled by battle switcher)', () {
      expect(kCosmeticVarietyNames, isNot(contains('meowth-galar')));
      expect(kCosmeticVarietyNames, isNot(contains('zigzagoon-galar')));
      expect(kCosmeticVarietyNames, isNot(contains('basculin-white-striped')));
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

  // ── kBaseFormNameOverrides — PokéAPI name accuracy ─────────────────────────

  group('kBaseFormNameOverrides — PokéAPI name accuracy', () {
    // Keys must match exactly what GET /pokemon/{id} returns as `name`.
    test('lycanroc default is lycanroc-midday (not lycanroc)', () {
      expect(kBaseFormNameOverrides['lycanroc-midday'], 'Midday');
      expect(kBaseFormNameOverrides['lycanroc'], isNull);
    });
    test('urshifu default is urshifu-single-strike (not urshifu)', () {
      expect(kBaseFormNameOverrides['urshifu-single-strike'], 'Single Strike');
      expect(kBaseFormNameOverrides['urshifu'], isNull);
    });
    test('palafin default is palafin-zero (not palafin)', () {
      expect(kBaseFormNameOverrides['palafin-zero'], 'Zero');
      expect(kBaseFormNameOverrides['palafin'], isNull);
    });
    test('oricorio default is oricorio-baile (not oricorio)', () {
      expect(kBaseFormNameOverrides['oricorio-baile'], 'Baile');
      expect(kBaseFormNameOverrides['oricorio'], isNull);
    });
    test('zacian and zamazenta are plain species names', () {
      expect(kBaseFormNameOverrides['zacian'], 'Hero');
      expect(kBaseFormNameOverrides['zamazenta'], 'Hero');
      expect(kBaseFormNameOverrides['zacian-hero'], isNull);
    });
    test('frillish-male and jellicent-male → Male', () {
      expect(kBaseFormNameOverrides['frillish-male'], 'Male');
      expect(kBaseFormNameOverrides['jellicent-male'], 'Male');
    });
    test('basculin default is basculin-red-striped', () =>
        expect(kBaseFormNameOverrides['basculin-red-striped'], 'Red-Striped'));
    test('variety cosmetic form defaults', () {
      expect(kBaseFormNameOverrides['wormadam-plant'], 'Plant');
      expect(kBaseFormNameOverrides['squawkabilly-green-plumage'], 'Green Plumage');
      expect(kBaseFormNameOverrides['tatsugiri-curly'], 'Curly');
      expect(kBaseFormNameOverrides['dudunsparce-two-segment'], 'Two Segment');
      expect(kBaseFormNameOverrides['floette'], 'Red Flower');
    });
  });
}
