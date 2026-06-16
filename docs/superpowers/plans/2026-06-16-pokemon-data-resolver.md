# PokemonDataResolver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `PokemonDataResolver` as a single entry point for all sprite URL construction, replacing the 4 divergent implementations across `sprite_resolver.dart`, `pokemon_grid_card.dart`, `pokemon_list_tile.dart`, and `form_descriptor.dart`.

**Architecture:** Static methods on `PokemonDataResolver` in `lib/data/` read `PokemonDataRegistry` internally. The format-aware `resolveFormSprite()` absorbs `FormDescriptor.spriteHint()` so callers pass `formName` + `baseSpecies` instead of constructing a `SpriteHint`. A separate `resolvePokedexImageUrl()` replaces the near-identical `_buildImageUrl()` methods in the grid card and list tile. `sprite_resolver.dart` becomes a thin wrapper; `SpriteHint` and `spriteHint()` are deleted once all callers are updated.

**Tech Stack:** Dart, Flutter, `PokemonDataRegistry` singleton, `flutter_test`

---

## File map

| Action | Path | Change |
|--------|------|--------|
| Create | `lib/features/pokedex/models/pokedex_image_type.dart` | Extract `PokedexImageType` enum from grid card |
| Create | `lib/data/pokemon_data_resolver.dart` | New resolver class |
| Create | `test/unit/pokemon_data_resolver_test.dart` | Tests for both public methods |
| Modify | `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` | Remove enum def + import, replace `_buildImageUrl` |
| Modify | `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` | Update import, replace `_buildImageUrl` + `_compactIconUrl` |
| Modify | `lib/features/pokedex/presentation/pokedex_screen.dart` | Update `PokedexImageType` import |
| Modify | `lib/services/format/sprite_resolver.dart` | Thin to delegate; remove all internals |
| Modify | `lib/features/teams/data/form_descriptor.dart` | Remove `SpriteHint`, `spriteHint()`, private URL helpers |
| Modify | `lib/features/teams/presentation/team_detail_screen.dart` | Replace `resolveSprite(hint: SpriteHint())` calls |
| Modify | `lib/features/teams/presentation/slot_config_screen.dart` | Replace `resolveSprite(hint: SpriteHint())` calls |
| Modify | `test/unit/sprite_resolver_test.dart` | Update call signature after thin |
| Modify | `test/unit/form_descriptor_test.dart` | Remove `SpriteHint` / `spriteHint` tests |

---

## Task 1: Move `PokedexImageType` to a shared models file

`PokedexImageType` is currently defined inside a presentation widget and re-exported via a `show` import. `PokemonDataResolver` needs to accept it as a parameter; a data-layer file must not import a presentation widget to get an enum. Moving it to the existing `models/` directory removes this coupling.

**Files:**
- Create: `lib/features/pokedex/models/pokedex_image_type.dart`
- Modify: `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart`
- Modify: `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart`
- Modify: `lib/features/pokedex/presentation/pokedex_screen.dart`

- [ ] **Step 1: Create the enum file**

```dart
// lib/features/pokedex/models/pokedex_image_type.dart
enum PokedexImageType { artwork, sprite }
```

- [ ] **Step 2: Update `pokemon_grid_card.dart`**

Remove the enum declaration:
```dart
// DELETE this line:
enum PokedexImageType { artwork, sprite }
```
Add import at the top (with other imports):
```dart
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
```

- [ ] **Step 3: Update `pokemon_list_tile.dart`**

Replace:
```dart
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_grid_card.dart'
    show PokedexImageType;
```
With:
```dart
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
```

- [ ] **Step 4: Update `pokedex_screen.dart`**

Find the import that brings in `PokedexImageType` (it comes via `pokemon_grid_card.dart` import). Add a direct import:
```dart
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
```
The existing `pokemon_grid_card.dart` import can stay; `PokedexImageType` is now just also available from the models file.

- [ ] **Step 5: Verify no compile errors**

```bash
flutter analyze lib/
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/pokedex/models/pokedex_image_type.dart \
        lib/features/pokedex/presentation/widget/pokemon_grid_card.dart \
        lib/features/pokedex/presentation/widget/pokemon_list_tile.dart \
        lib/features/pokedex/presentation/pokedex_screen.dart
git commit -m "refactor: move PokedexImageType to pokedex models"
```

---

## Task 2: Write failing tests for `PokemonDataResolver.resolveFormSprite()`

TDD: write the tests before the class exists so the test run confirms the red phase.

**Files:**
- Create: `test/unit/pokemon_data_resolver_test.dart`

- [ ] **Step 1: Create the test file**

```dart
// test/unit/pokemon_data_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  // ── resolveFormSprite ─────────────────────────────────────────────────────

  group('resolveFormSprite — no format (HOME/artwork path)', () {
    test('uses HOME url from sprites when present', () {
      final sprites = {
        'other': {
          'home': {
            'front_default': 'https://example.com/home/6.png',
            'front_shiny': 'https://example.com/home/shiny/6.png',
          }
        }
      };
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: sprites,
        pokemonId: 6,
        pokemonName: 'charizard',
        baseSpecies: 'charizard',
        formName: null,
        format: null,
        useFormatSprites: false,
      );
      expect(result.defaultUrl, 'https://example.com/home/6.png');
      expect(result.shinyUrl, 'https://example.com/home/shiny/6.png');
    });

    test('uses official-artwork when HOME is absent', () {
      final sprites = {
        'other': {
          'official-artwork': {
            'front_default': 'https://example.com/artwork/6.png',
          }
        }
      };
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: sprites,
        pokemonId: 6,
        pokemonName: 'charizard',
        baseSpecies: 'charizard',
        formName: null,
        format: null,
        useFormatSprites: false,
      );
      expect(result.defaultUrl, 'https://example.com/artwork/6.png');
    });

    test('cosmetic form: homeUrl built from registry cosmeticSpriteStems', () {
      // burmy-sandy is in cosmeticSpriteStems['burmy'] with stem '412-sandy'
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null,
        pokemonId: 412,
        pokemonName: 'burmy-sandy',
        baseSpecies: 'burmy',
        formName: 'burmy-sandy',
        format: null,
        useFormatSprites: false,
      );
      expect(result.defaultUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/412-sandy.png');
      expect(result.shinyUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/412-sandy.png');
    });

    test('no sprites and no cosmetic match: raw front sprite fallback', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null,
        pokemonId: 6,
        pokemonName: 'charizard',
        baseSpecies: 'charizard',
        formName: null,
        format: null,
        useFormatSprites: false,
      );
      expect(result.defaultUrl, contains('/sprites/pokemon/6.png'));
    });
  });

  group('resolveFormSprite — Gen 1 (no shiny mechanic)', () {
    const gen1 = GameFormat(
      id: 'yellow', name: 'Yellow', short: 'Yel',
      type: FormatType.game, gen: 1,
    );

    test('shinyUrl equals defaultUrl', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 6, pokemonName: 'charizard',
        baseSpecies: 'charizard', formName: null,
        format: gen1, useFormatSprites: true,
      );
      expect(result.shinyUrl, equals(result.defaultUrl));
    });

    test('femaleUrl is null', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 6, pokemonName: 'charizard',
        baseSpecies: 'charizard', formName: null,
        format: gen1, useFormatSprites: true,
      );
      expect(result.femaleUrl, isNull);
    });
  });

  group('resolveFormSprite — Gen 5 BW animated sprites', () {
    const bw = GameFormat(
      id: 'bw', name: 'BW', short: 'BW',
      type: FormatType.game, gen: 5,
    );

    test('defaultUrl uses .gif extension and animated/ subfolder', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 6, pokemonName: 'charizard',
        baseSpecies: 'charizard', formName: null,
        format: bw, useFormatSprites: true,
      );
      expect(result.defaultUrl, endsWith('.gif'));
      expect(result.defaultUrl, contains('animated/'));
    });

    test('cosmetic form: stem from registry used in BW path', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 412, pokemonName: 'burmy-sandy',
        baseSpecies: 'burmy', formName: 'burmy-sandy',
        format: bw, useFormatSprites: true,
      );
      expect(result.defaultUrl, contains('412-sandy'));
      expect(result.defaultUrl, endsWith('.gif'));
    });
  });

  group('resolveFormSprite — Gen 2 crystal fallback chain', () {
    const crystal = GameFormat(
      id: 'crystal', name: 'Crystal', short: 'Crys',
      type: FormatType.game, gen: 2,
    );

    test('fallbackUrl points to gold, fallbackUrl2 to silver', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 201, pokemonName: 'unown',
        baseSpecies: 'unown', formName: null,
        format: crystal, useFormatSprites: true,
      );
      expect(result.fallbackUrl, contains('generation-ii/gold'));
      expect(result.fallbackUrl2, contains('generation-ii/silver'));
    });
  });

  group('resolveFormSprite — Gen 4 female URLs', () {
    const dp = GameFormat(
      id: 'dp', name: 'DP', short: 'DP',
      type: FormatType.game, gen: 4,
    );

    test('femaleUrl and femaleShinyUrl are non-null for Gen 4', () {
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null, pokemonId: 521, pokemonName: 'unfezant',
        baseSpecies: 'unfezant', formName: null,
        format: dp, useFormatSprites: true,
      );
      expect(result.femaleUrl, isNotNull);
      expect(result.femaleShinyUrl, isNotNull);
      expect(result.femaleUrl, contains('female/'));
    });
  });

  group('resolveFormSprite — useFormatSprites: false ignores format', () {
    const bw = GameFormat(
      id: 'bw', name: 'BW', short: 'BW',
      type: FormatType.game, gen: 5,
    );

    test('falls back to HOME/artwork when useFormatSprites is false', () {
      final sprites = {
        'other': {
          'home': {'front_default': 'https://example.com/home/6.png'}
        }
      };
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: sprites, pokemonId: 6, pokemonName: 'charizard',
        baseSpecies: 'charizard', formName: null,
        format: bw, useFormatSprites: false,
      );
      expect(result.defaultUrl, 'https://example.com/home/6.png');
    });
  });

  // ── resolvePokedexImageUrl ────────────────────────────────────────────────
  // (added in Task 4)
}
```

- [ ] **Step 2: Run test — expect compile failure**

```bash
flutter test test/unit/pokemon_data_resolver_test.dart
```
Expected: error "Target of URI doesn't exist: pokemon_data_resolver.dart"

- [ ] **Step 3: Commit the failing test file**

```bash
git add test/unit/pokemon_data_resolver_test.dart
git commit -m "test: failing tests for PokemonDataResolver.resolveFormSprite"
```

---

## Task 3: Implement `PokemonDataResolver` with `resolveFormSprite()`

**Files:**
- Create: `lib/data/pokemon_data_resolver.dart`

- [ ] **Step 1: Create the resolver file**

```dart
// lib/data/pokemon_data_resolver.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart'
    show cosmeticFormHomeUrl, cosmeticFormHomeShinyUrl, pokemonHomeFemaleUrl;

const _versionsBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
const _spritesBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

class PokemonDataResolver {
  PokemonDataResolver._();

  /// Resolves all sprite URLs for a Pokémon form.
  ///
  /// Replaces `resolveSprite()` from `sprite_resolver.dart` and absorbs the
  /// cosmetic-form hint building from `FormDescriptor.spriteHint()`.
  ///
  /// Pass [baseSpecies] + [formName] instead of constructing a `SpriteHint`.
  /// For Gen 1–5 the full versioned URL set is returned. For Gen 6+ (or when
  /// [useFormatSprites] is false) the HOME / official-artwork path is used.
  ///
  /// For Pokédex list/grid display (no format awareness), pass
  /// `format: null, useFormatSprites: false` and use [defaultUrl].
  static ({
    String? defaultUrl,
    String? shinyUrl,
    String? femaleUrl,
    String? femaleShinyUrl,
    String? fallbackUrl,
    String? fallbackUrl2,
  }) resolveFormSprite({
    required Map<String, dynamic>? sprites,
    required int pokemonId,
    required String pokemonName,
    required String baseSpecies,
    required String? formName,
    required GameFormat? format,
    required bool useFormatSprites,
  }) {
    final registry = PokemonDataRegistry.instance;

    // Build cosmetic hint internally (replaces FormDescriptor.spriteHint).
    // Cosmetic forms share the base species' /pokemon resource and are filed
    // under "{baseSpeciesId}-{suffix}" in every sprite tier.
    String? cosmeticStem;
    String? cosmeticHome;
    String? cosmeticHomeShiny;
    if (formName != null) {
      final stems = registry.cosmeticSpriteStems[baseSpecies];
      if (stems != null && stems.containsKey(formName)) {
        final s = stems[formName]!;
        final suffix = s.split('-').last;
        cosmeticStem = s;
        cosmeticHome = cosmeticFormHomeUrl(pokemonId, suffix);
        cosmeticHomeShiny = cosmeticFormHomeShinyUrl(pokemonId, suffix);
      }
    }

    final stem = cosmeticStem ?? '$pokemonId';
    final rawDefault = '${_spritesBase}$stem.png';
    final rawShiny = '${_spritesBase}shiny/$stem.png';

    if (!useFormatSprites || format == null) {
      return _homeOrArtwork(
        sprites, rawDefault, rawShiny,
        cosmeticHome: cosmeticHome,
        cosmeticHomeShiny: cosmeticHomeShiny,
      );
    }

    final gameId = format.type == FormatType.game
        ? format.id
        : registry.genToDefaultGameId[format.gen];

    if (gameId != null) {
      final versionPath = registry.gameIdToVersionPath[gameId];
      if (versionPath != null) {
        final gen = format.gen;
        final isAnimated = gameId == 'bw' || gameId == 'b2w2';
        final ext = isAnimated ? '.gif' : '.png';
        final transparent = gen <= 2 ? 'transparent/' : '';
        final animSeg = isAnimated ? 'animated/' : '';

        final defaultUrl =
            '$_versionsBase/$versionPath/$animSeg${transparent}$stem$ext';
        final shinyUrl = _versionedShinyUrl(
            versionPath, gen, animSeg, transparent, stem, ext, pokemonName);
        final (femaleUrl, femaleShinyUrl) =
            _versionedFemaleUrls(versionPath, gen, animSeg, stem, ext);

        String? fallbackUrl;
        String? fallbackUrl2;
        if (gameId == 'crystal') {
          fallbackUrl =
              '$_versionsBase/generation-ii/gold/$animSeg${transparent}$stem$ext';
          fallbackUrl2 =
              '$_versionsBase/generation-ii/silver/$animSeg${transparent}$stem$ext';
        }

        return (
          defaultUrl: defaultUrl,
          shinyUrl: shinyUrl,
          femaleUrl: femaleUrl,
          femaleShinyUrl: femaleShinyUrl,
          fallbackUrl: fallbackUrl,
          fallbackUrl2: fallbackUrl2,
        );
      }
    }

    return _homeOrArtwork(
      sprites, rawDefault, rawShiny,
      cosmeticHome: cosmeticHome,
      cosmeticHomeShiny: cosmeticHomeShiny,
    );
  }

  /// Version-group compact icon URL for list tile compact display mode.
  /// Replaces `_compactIconUrl()` from `pokemon_list_tile.dart`.
  static String compactIconUrl(int pokemonId, PokedexFilter filter) {
    final registry = PokemonDataRegistry.instance;
    String? vg;
    if (filter.game != null) {
      vg = registry.formatToVersionGroup[filter.game];
    } else if (filter.generation != null) {
      vg = registry.genToLastVg[filter.generation];
    }
    final subpath = vg != null ? registry.vgToSubpath[vg] : null;
    if (subpath == null) return '$_spritesBase$pokemonId.png';
    return '$_spritesBase$subpath/$pokemonId.png';
  }

  /// Single URL for Pokédex grid/list display.
  /// Replaces `_buildImageUrl()` from both `PokemonGridCard` and `PokemonListTile`.
  ///
  /// [imageType] is nullable: null means compact list mode (gen-8 icon).
  /// [filter] must be non-null when [imageType] is [PokedexImageType.sprite].
  static String resolvePokedexImageUrl({
    required int pokemonId,
    required String baseSpecies,
    required String? selectedFormName,
    required PokedexImageType? imageType,
    required PokemonEntry? formEntry,
    required PokemonFormEntry? cosmeticEntry,
    required PokedexFilter? filter,
  }) {
    final registry = PokemonDataRegistry.instance;

    if (selectedFormName != null) {
      if (cosmeticEntry != null) {
        if (imageType == PokedexImageType.artwork) {
          final override =
              registry.cosmeticFormHomeUrlOverrides[cosmeticEntry.name];
          if (override != null) return override;
          // Female HOME artwork lives at home/female/{id}.png — not {id}-female.png.
          if (cosmeticEntry.formName == 'female') {
            return pokemonHomeFemaleUrl(pokemonId);
          }
          if (cosmeticEntry.name.startsWith('$baseSpecies-')) {
            final suffix =
                cosmeticEntry.name.substring(baseSpecies.length + 1);
            return cosmeticFormHomeUrl(pokemonId, suffix);
          }
        }
        if (cosmeticEntry.formName == 'female') {
          return '${_spritesBase}female/$pokemonId.png';
        }
        return cosmeticEntry.spriteUrl ?? '$_spritesBase$pokemonId.png';
      }

      if (formEntry != null) {
        if (imageType == PokedexImageType.artwork) {
          final homeOverride =
              registry.cosmeticFormHomeUrlOverrides[selectedFormName];
          return homeOverride ??
              formEntry.officialArtworkUrl ??
              '${_spritesBase}other/official-artwork/$pokemonId.png';
        }
        if (imageType == PokedexImageType.sprite) {
          return (formEntry.sprites?['front_default'] as String?) ??
              '$_spritesBase$pokemonId.png';
        }
        // compact (null imageType)
        return '${_spritesBase}versions/generation-viii/icons/${formEntry.id}.png';
      }
    }

    return switch (imageType) {
      PokedexImageType.artwork =>
        '${_spritesBase}other/official-artwork/$pokemonId.png',
      PokedexImageType.sprite => compactIconUrl(pokemonId, filter!),
      null => '${_spritesBase}versions/generation-viii/icons/$pokemonId.png',
    };
  }

  /// Fallback URL for list tile compact mode.
  /// Returns the form sprite (if any) or the base sprite.
  static String resolvePokedexFallbackUrl({
    required int pokemonId,
    required PokedexImageType? imageType,
    required String? selectedFormName,
    required PokemonEntry? formEntry,
    required PokemonFormEntry? cosmeticEntry,
  }) {
    if (imageType == null && selectedFormName != null) {
      final formSprite = cosmeticEntry?.spriteUrl ??
          (formEntry?.sprites?['front_default'] as String?);
      if (formSprite != null) return formSprite;
    }
    return '$_spritesBase$pokemonId.png';
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

({
  String? defaultUrl,
  String? shinyUrl,
  String? femaleUrl,
  String? femaleShinyUrl,
  String? fallbackUrl,
  String? fallbackUrl2,
}) _homeOrArtwork(
  Map<String, dynamic>? sprites,
  String rawDefault,
  String rawShiny, {
  String? cosmeticHome,
  String? cosmeticHomeShiny,
}) {
  final home =
      sprites == null ? null : _nav(sprites['other'], ['home']);
  final artwork =
      sprites == null ? null : _nav(sprites['other'], ['official-artwork']);
  return (
    defaultUrl: cosmeticHome ??
        home?['front_default'] as String? ??
        artwork?['front_default'] as String? ??
        rawDefault,
    shinyUrl: cosmeticHomeShiny ??
        home?['front_shiny'] as String? ??
        artwork?['front_shiny'] as String? ??
        rawShiny,
    femaleUrl: home?['front_female'] as String?,
    femaleShinyUrl: home?['front_shiny_female'] as String?,
    fallbackUrl: null,
    fallbackUrl2: null,
  );
}

String _versionedShinyUrl(
  String versionPath,
  int gen,
  String animSeg,
  String transparent,
  String stem,
  String ext,
  String pokemonName,
) {
  if (gen == 1) {
    return '$_versionsBase/$versionPath/$animSeg${transparent}$stem$ext';
  }
  if (animSeg.isNotEmpty) {
    return '$_versionsBase/$versionPath/${animSeg}shiny/$stem$ext';
  }
  if (transparent.isNotEmpty) {
    // No transparent/shiny subfolder in Gen 2. Use Pokémon Showdown on native
    // (CORS-safe); fall back to non-transparent PokeAPI shiny on web.
    return kIsWeb
        ? '$_versionsBase/$versionPath/shiny/$stem$ext'
        : 'https://play.pokemonshowdown.com/sprites/gen2-shiny/$pokemonName.png';
  }
  return '$_versionsBase/$versionPath/shiny/$stem$ext';
}

(String? femaleUrl, String? femaleShinyUrl) _versionedFemaleUrls(
  String versionPath,
  int gen,
  String animSeg,
  String stem,
  String ext,
) {
  if (gen < 4) return (null, null);
  return (
    '$_versionsBase/$versionPath/${animSeg}female/$stem$ext',
    '$_versionsBase/$versionPath/${animSeg}shiny/female/$stem$ext',
  );
}

Map<String, dynamic>? _nav(dynamic root, List<String> path) {
  dynamic cur = root;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  return cur is Map ? cur.cast<String, dynamic>() : null;
}
```

- [ ] **Step 2: Run the tests — expect green**

```bash
flutter test test/unit/pokemon_data_resolver_test.dart
```
Expected: all 11 tests pass.

- [ ] **Step 3: Run full analyzer**

```bash
flutter analyze lib/data/pokemon_data_resolver.dart
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/data/pokemon_data_resolver.dart
git commit -m "feat: add PokemonDataResolver with resolveFormSprite"
```

---

## Task 4: Write failing tests for `resolvePokedexImageUrl()`

Add a new group to the existing test file. These tests exercise the pokedex-display URL logic.

**Files:**
- Modify: `test/unit/pokemon_data_resolver_test.dart`

- [ ] **Step 1: Append test group after the last closing `}`**

Add the following group at the end of `main()`, before the final `}`:

```dart
  // ── resolvePokedexImageUrl ─────────────────────────────────────────────────

  group('resolvePokedexImageUrl — no form selected', () {
    test('artwork mode: returns official-artwork URL', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 6,
        baseSpecies: 'charizard',
        selectedFormName: null,
        imageType: PokedexImageType.artwork,
        formEntry: null,
        cosmeticEntry: null,
        filter: null,
      );
      expect(url, contains('other/official-artwork/6.png'));
    });

    test('compact mode (null imageType): returns gen-8 icon URL', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 6,
        baseSpecies: 'charizard',
        selectedFormName: null,
        imageType: null,
        formEntry: null,
        cosmeticEntry: null,
        filter: null,
      );
      expect(url, contains('generation-viii/icons/6.png'));
    });
  });

  group('resolvePokedexImageUrl — cosmetic form selected', () {
    test('artwork: returns cosmeticFormHomeUrlOverride when present', () {
      // xerneas-active has an entry in cosmeticFormHomeUrlOverrides
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 716,
        baseSpecies: 'xerneas',
        selectedFormName: 'xerneas-active',
        imageType: PokedexImageType.artwork,
        formEntry: null,
        cosmeticEntry: _makeCosmeticEntry(
          name: 'xerneas-active',
          formName: 'active',
          spriteUrl: 'https://example.com/xerneas-active.png',
        ),
        filter: null,
      );
      // override value from registry — just assert it is NOT the sprite URL
      expect(url, isNot('https://example.com/xerneas-active.png'));
    });

    test('artwork: female cosmetic returns home/female/{id}.png path', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 592,
        baseSpecies: 'frillish',
        selectedFormName: 'frillish-female',
        imageType: PokedexImageType.artwork,
        formEntry: null,
        cosmeticEntry: _makeCosmeticEntry(
          name: 'frillish-female',
          formName: 'female',
          spriteUrl: null,
        ),
        filter: null,
      );
      expect(url, contains('home/female/592.png'));
      expect(url, isNot(contains('592-female.png')));
    });

    test('artwork: suffix-based cosmetic returns home/{id}-{suffix}.png', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 422, // Shellos
        baseSpecies: 'shellos',
        selectedFormName: 'shellos-east',
        imageType: PokedexImageType.artwork,
        formEntry: null,
        cosmeticEntry: _makeCosmeticEntry(
          name: 'shellos-east',
          formName: 'east',
          spriteUrl: 'https://example.com/shellos-east.png',
        ),
        filter: null,
      );
      expect(url, contains('home/422-east.png'));
    });

    test('sprite mode: female cosmetic returns female/{id}.png sprite', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 592,
        baseSpecies: 'frillish',
        selectedFormName: 'frillish-female',
        imageType: PokedexImageType.sprite,
        formEntry: null,
        cosmeticEntry: _makeCosmeticEntry(
          name: 'frillish-female',
          formName: 'female',
          spriteUrl: null,
        ),
        filter: null,
      );
      expect(url, contains('female/592.png'));
    });
  });

  group('resolvePokedexImageUrl — variety form selected', () {
    test('artwork: uses officialArtworkUrl from formEntry', () {
      final entry = _makePokemonEntry(id: 10001, artworkUrl: 'https://example.com/10001.png');
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 250,
        baseSpecies: 'ho-oh',
        selectedFormName: 'ho-oh',
        imageType: PokedexImageType.artwork,
        formEntry: entry,
        cosmeticEntry: null,
        filter: null,
      );
      expect(url, 'https://example.com/10001.png');
    });

    test('sprite mode: uses front_default from formEntry sprites', () {
      final entry = _makePokemonEntry(
        id: 10001,
        artworkUrl: null,
        frontDefault: 'https://example.com/sprite.png',
      );
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 250,
        baseSpecies: 'ho-oh',
        selectedFormName: 'ho-oh',
        imageType: PokedexImageType.sprite,
        formEntry: entry,
        cosmeticEntry: null,
        filter: null,
      );
      expect(url, 'https://example.com/sprite.png');
    });
  });
```

Add these helper factory functions at the end of the file (outside `main()`):

```dart
PokemonFormEntry _makeCosmeticEntry({
  required String name,
  required String? formName,
  required String? spriteUrl,
}) => PokemonFormEntry(
  id: 99999,
  name: name,
  formName: formName,
  isDefault: false,
  spriteUrl: spriteUrl,
  spriteShinyUrl: null,
);

PokemonEntry _makePokemonEntry({
  required int id,
  required String? artworkUrl,
  String? frontDefault,
}) => PokemonEntry(
  id: id,
  name: 'test-pokemon',
  types: const {},
  stats: const [],
  abilities: const [],
  moves: const [],
  formNames: const [],
  officialArtworkUrl: artworkUrl,
  sprites: frontDefault != null
      ? {'front_default': frontDefault}
      : null,
);
```

Note: `PokemonEntry` constructor params may differ — check `lib/services/pokeapi/models/pokemon_entry.dart` and adjust field names to match.

- [ ] **Step 2: Run tests — expect failures only in the new group**

```bash
flutter test test/unit/pokemon_data_resolver_test.dart
```
Expected: the `resolvePokedexImageUrl` group fails; the `resolveFormSprite` group still passes.

- [ ] **Step 3: Commit**

```bash
git add test/unit/pokemon_data_resolver_test.dart
git commit -m "test: failing tests for resolvePokedexImageUrl"
```

---

## Task 5: Verify `resolvePokedexImageUrl()` tests pass (already implemented in Task 3)

`resolvePokedexImageUrl()` and `resolvePokedexFallbackUrl()` were included in the `lib/data/pokemon_data_resolver.dart` file written in Task 3. Run the tests to confirm they're already green.

- [ ] **Step 1: Run all resolver tests**

```bash
flutter test test/unit/pokemon_data_resolver_test.dart
```
Expected: all tests pass. If the `_makePokemonEntry` helper needed constructor adjustments (Task 4 note), fix those now in the test file.

- [ ] **Step 2: If any tests fail due to PokemonEntry constructor, check the actual constructor**

```bash
grep -n "PokemonEntry(" lib/services/pokeapi/models/pokemon_entry.dart | head -5
```

Adjust `_makePokemonEntry` in the test to use the correct parameter names.

- [ ] **Step 3: Commit test fix (if needed)**

```bash
git add test/unit/pokemon_data_resolver_test.dart
git commit -m "test: fix PokemonEntry constructor in resolver test helpers"
```

---

## Task 6: Update `team_detail_screen.dart` and `slot_config_screen.dart`

Replace `resolveSprite(hint: SpriteHint(...))` with `PokemonDataResolver.resolveFormSprite(...)`. These are the only remaining callers of `resolveSprite` after this task — `sprite_resolver.dart` can then be safely thinned in Task 7.

**Files:**
- Modify: `lib/features/teams/presentation/team_detail_screen.dart`
- Modify: `lib/features/teams/presentation/slot_config_screen.dart`

### `team_detail_screen.dart` — two call sites

- [ ] **Step 1: Add import, remove old imports**

At the top of `team_detail_screen.dart`, add:
```dart
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
```

Remove (once no longer used after the replacements below):
```dart
import 'package:poke_team_dex/services/format/sprite_resolver.dart';
```

The `form_descriptor.dart` import stays (still uses `FormDescriptor`).

- [ ] **Step 2: Replace cosmetic form sprite call (line ~972)**

Find the block starting with:
```dart
final cosmeticFormChangeSuffix =
    cosmeticFormChange?.name.substring(pokemon.name.length + 1);
final cosmeticFormChangeSpriteUrls = cosmeticFormChangeSuffix != null
    ? resolveSprite(
        sprites: null,
        pokemonId: pokemon.id,
        pokemonName: cosmeticFormChange!.name,
        format: format,
        useFormatSprites: useFormatSprites,
        hint: SpriteHint(
          stem: '${pokemon.id}-$cosmeticFormChangeSuffix',
          homeUrl: cosmeticFormHomeUrl(pokemon.id, cosmeticFormChangeSuffix),
          homeShinyUrl: cosmeticFormHomeShinyUrl(pokemon.id, cosmeticFormChangeSuffix),
        ),
      )
    : null;
```

Replace with:
```dart
final cosmeticFormChangeSpriteUrls = cosmeticFormChange != null
    ? PokemonDataResolver.resolveFormSprite(
        sprites: null,
        pokemonId: pokemon.id,
        pokemonName: cosmeticFormChange!.name,
        baseSpecies: pokemon.name,
        formName: cosmeticFormChange!.name,
        format: format,
        useFormatSprites: useFormatSprites,
      )
    : null;
```

Remove the now-unused `cosmeticFormChangeSuffix` variable declaration too.

- [ ] **Step 3: Replace base sprite call (line ~1068)**

Find:
```dart
final spriteUrls = resolveSprite(
  sprites: pokemon.sprites,
  pokemonId: slot.pokemonId,
  pokemonName: pokemon.name,
  format: format,
  useFormatSprites: useFormatSprites,
  hint: descriptor.spriteHint(pokemon.name, pokemon.id),
);
```

Replace with:
```dart
final spriteUrls = PokemonDataResolver.resolveFormSprite(
  sprites: pokemon.sprites,
  pokemonId: slot.pokemonId,
  pokemonName: pokemon.name,
  baseSpecies: pokemon.name,
  formName: descriptor.formName,
  format: format,
  useFormatSprites: useFormatSprites,
);
```

- [ ] **Step 4: Remove `cosmeticFormHomeUrl` / `cosmeticFormHomeShinyUrl` imports from team_detail_screen**

If those were imported from `pokemon_sprite.dart` specifically for the `SpriteHint` construction, remove them. Check that `pokemonHomeUrl`, `pokemonHomeShinyUrl`, `pokemonHomeFemaleUrl` are still imported (they're still used for mega/gmax artwork).

### `slot_config_screen.dart` — two call sites

- [ ] **Step 5: Add resolver import, remove sprite_resolver import**

Add:
```dart
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
```

Remove:
```dart
import 'package:poke_team_dex/services/format/sprite_resolver.dart';
```

- [ ] **Step 6: Replace base sprite call (line ~651)**

Find:
```dart
final spriteUrls = resolveSprite(
  sprites: pokemon.sprites,
  pokemonId: slot.pokemonId,
  pokemonName: pokemon.name,
  format: format,
  useFormatSprites: useFormatSprites,
  hint: const SpriteHint(),
);
```

Replace with:
```dart
final spriteUrls = PokemonDataResolver.resolveFormSprite(
  sprites: pokemon.sprites,
  pokemonId: slot.pokemonId,
  pokemonName: pokemon.name,
  baseSpecies: pokemon.name,
  formName: null,
  format: format,
  useFormatSprites: useFormatSprites,
);
```

- [ ] **Step 7: Replace cosmetic form sprite call (line ~914)**

Find:
```dart
final cosmeticFormSpriteUrls = cosmeticFormSuffix != null
    ? resolveSprite(
        sprites: null,
        pokemonId: pokemon.id,
        pokemonName: cosmeticForm!.name,
        format: format,
        useFormatSprites: useFormatSprites,
        hint: SpriteHint(
          stem: '${pokemon.id}-$cosmeticFormSuffix',
          homeUrl: cosmeticFormHomeUrl(pokemon.id, cosmeticFormSuffix),
          homeShinyUrl: cosmeticFormHomeShinyUrl(pokemon.id, cosmeticFormSuffix),
        ),
      )
    : null;
```

Replace with:
```dart
final cosmeticFormSpriteUrls = cosmeticForm != null
    ? PokemonDataResolver.resolveFormSprite(
        sprites: null,
        pokemonId: pokemon.id,
        pokemonName: cosmeticForm!.name,
        baseSpecies: pokemon.name,
        formName: cosmeticForm!.name,
        format: format,
        useFormatSprites: useFormatSprites,
      )
    : null;
```

Remove the now-unused `cosmeticFormSuffix` variable declaration.

- [ ] **Step 8: Verify compilation**

```bash
flutter analyze lib/features/teams/presentation/
```
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add lib/features/teams/presentation/team_detail_screen.dart \
        lib/features/teams/presentation/slot_config_screen.dart
git commit -m "refactor: replace resolveSprite/SpriteHint with PokemonDataResolver in teams screens"
```

---

## Task 7: Thin `sprite_resolver.dart` + remove `SpriteHint` from `form_descriptor.dart`

No callers of the old `resolveSprite(hint: SpriteHint())` remain after Task 6. Thin `sprite_resolver.dart` to a delegation wrapper and delete `SpriteHint` and `spriteHint()` from `form_descriptor.dart`.

**Files:**
- Modify: `lib/services/format/sprite_resolver.dart`
- Modify: `lib/features/teams/data/form_descriptor.dart`
- Modify: `test/unit/sprite_resolver_test.dart`
- Modify: `test/unit/form_descriptor_test.dart`

- [ ] **Step 1: Replace `sprite_resolver.dart` body**

Overwrite the entire file with:
```dart
// lib/services/format/sprite_resolver.dart
//
// Thin wrapper retained for call-site compatibility.
// All logic lives in PokemonDataResolver.resolveFormSprite().

import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

({
  String? defaultUrl,
  String? shinyUrl,
  String? femaleUrl,
  String? femaleShinyUrl,
  String? fallbackUrl,
  String? fallbackUrl2,
}) resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required String pokemonName,
  required String baseSpecies,
  required String? formName,
  required GameFormat? format,
  required bool useFormatSprites,
}) =>
    PokemonDataResolver.resolveFormSprite(
      sprites: sprites,
      pokemonId: pokemonId,
      pokemonName: pokemonName,
      baseSpecies: baseSpecies,
      formName: formName,
      format: format,
      useFormatSprites: useFormatSprites,
    );
```

- [ ] **Step 2: Remove `SpriteHint` and `spriteHint()` from `form_descriptor.dart`**

In `lib/features/teams/data/form_descriptor.dart`:

Delete the entire `SpriteHint` class (lines 1–15 approx):
```dart
/// Overrides the sprite resolver needs for a form's sprite paths.
/// All fields are null for non-cosmetic forms — the resolver uses pokemonId as stem.
class SpriteHint {
  final String? stem;
  final String? homeUrl;
  final String? homeShinyUrl;
  const SpriteHint({this.stem, this.homeUrl, this.homeShinyUrl});
}
```

Delete the `spriteHint()` method from `FormDescriptor`:
```dart
SpriteHint spriteHint(String baseSpecies, int baseSpeciesId) {
  if (formName != null) {
    final cosmeticStems = PokemonDataRegistry.instance.cosmeticSpriteStems[baseSpecies];
    if (cosmeticStems != null && cosmeticStems.containsKey(formName)) {
      final stem = cosmeticStems[formName]!;
      final suffix = stem.split('-').last;
      return SpriteHint(
        stem: stem,
        homeUrl: _cosmeticHomeUrl(baseSpeciesId, suffix),
        homeShinyUrl: _cosmeticHomeShinyUrl(baseSpeciesId, suffix),
      );
    }
  }
  return const SpriteHint();
}
```

Delete the private URL helpers at the bottom of the file:
```dart
String _cosmeticHomeUrl(int id, String suffix) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/$id-$suffix.png';

String _cosmeticHomeShinyUrl(int id, String suffix) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/$id-$suffix.png';
```

Also remove the `PokemonDataRegistry` import from `form_descriptor.dart` if it was only used by `spriteHint()` (check whether `effectiveApiName` still needs `PokemonDataRegistry.instance.megaStoneMap` — it does, so keep the import).

- [ ] **Step 3: Update `sprite_resolver_test.dart`**

The tests currently call `resolveSprite(hint: ...)`. Update them to use the new signature (`baseSpecies` + `formName`). Replace all:
```dart
resolveSprite(
  sprites: ...,
  pokemonId: ...,
  pokemonName: ...,
  format: ...,
  useFormatSprites: ...,
  hint: const SpriteHint(),
)
```
with:
```dart
resolveSprite(
  sprites: ...,
  pokemonId: ...,
  pokemonName: ...,
  baseSpecies: '...',  // add base species
  formName: null,
  format: ...,
  useFormatSprites: ...,
)
```
And replace the cosmetic hint test:
```dart
hint: const SpriteHint(
  stem: '412-sandy',
  homeUrl: 'https://example.com/home/412-sandy.png',
  homeShinyUrl: 'https://example.com/home/shiny/412-sandy.png',
),
```
with:
```dart
baseSpecies: 'burmy',
formName: 'burmy-sandy',
```
and remove the sprite-hint-specific assertions — those are now covered by `pokemon_data_resolver_test.dart`.

- [ ] **Step 4: Update `form_descriptor_test.dart`**

Remove the `spriteHint` group tests (lines for the `spriteHint()` method). These behaviors are now verified in `pokemon_data_resolver_test.dart`. Keep all other tests in `form_descriptor_test.dart`.

- [ ] **Step 5: Run all unit tests**

```bash
flutter test test/unit/
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/services/format/sprite_resolver.dart \
        lib/features/teams/data/form_descriptor.dart \
        test/unit/sprite_resolver_test.dart \
        test/unit/form_descriptor_test.dart
git commit -m "refactor: thin sprite_resolver to wrapper; remove SpriteHint from form_descriptor"
```

---

## Task 8: Replace `_buildImageUrl()` in `pokemon_grid_card.dart` and `pokemon_list_tile.dart`

Both widgets have nearly identical `_buildImageUrl()` private methods. Replace them with calls to `PokemonDataResolver.resolvePokedexImageUrl()` and `resolvePokedexFallbackUrl()`.

**Files:**
- Modify: `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart`
- Modify: `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart`

### `pokemon_grid_card.dart`

- [ ] **Step 1: Add resolver import, remove `cosmeticFormHomeUrl` import**

Add:
```dart
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
```

Remove:
```dart
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart' show cosmeticFormHomeUrl;
```

- [ ] **Step 2: Update the `_buildImageUrl()` call site**

In `build()`, find:
```dart
final imageUrl = _buildImageUrl(formEntry, selectedCosmeticEntry, basePokemon);
```

Replace with:
```dart
final imageUrl = PokemonDataResolver.resolvePokedexImageUrl(
  pokemonId: widget.pokemon.id,
  baseSpecies: basePokemon?.speciesName ?? widget.pokemon.name,
  selectedFormName: _selectedFormName,
  imageType: widget.imageType,
  formEntry: formEntry,
  cosmeticEntry: selectedCosmeticEntry,
  filter: null,
);
```

- [ ] **Step 3: Delete the `_buildImageUrl()` method**

Remove the entire `String _buildImageUrl(...)` method from `_PokemonGridCardState` (lines ~315–353).

- [ ] **Step 4: Verify no other references to deleted method**

```bash
flutter analyze lib/features/pokedex/presentation/widget/pokemon_grid_card.dart
```

### `pokemon_list_tile.dart`

- [ ] **Step 5: Add resolver import, remove `cosmeticFormHomeUrl` import**

Add:
```dart
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
```

Remove:
```dart
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart' show cosmeticFormHomeUrl;
```

- [ ] **Step 6: Update call sites for `_buildImageUrl` and `_buildFallbackUrl`**

Find:
```dart
final imageUrl = _buildImageUrl(formEntry, selectedCosmeticEntry, filter, basePokemon);
final fallbackUrl = _buildFallbackUrl(formEntry, selectedCosmeticEntry);
```

Replace with:
```dart
final imageUrl = PokemonDataResolver.resolvePokedexImageUrl(
  pokemonId: widget.pokemon.id,
  baseSpecies: basePokemon?.speciesName ?? widget.pokemon.name,
  selectedFormName: _selectedFormName,
  imageType: widget.imageType,
  formEntry: formEntry,
  cosmeticEntry: selectedCosmeticEntry,
  filter: filter,
);
final fallbackUrl = PokemonDataResolver.resolvePokedexFallbackUrl(
  pokemonId: widget.pokemon.id,
  imageType: widget.imageType,
  selectedFormName: _selectedFormName,
  formEntry: formEntry,
  cosmeticEntry: selectedCosmeticEntry,
);
```

- [ ] **Step 7: Delete `_buildImageUrl()`, `_buildFallbackUrl()`, and `_compactIconUrl()` from the file**

Remove:
- The top-level `String _compactIconUrl(int pokemonId, PokedexFilter filter)` function (~lines 26–37)
- The `_buildImageUrl(...)` method from `_PokemonListTileState` (~lines 388–443)
- The `_buildFallbackUrl(...)` method from `_PokemonListTileState` (~lines 445–456)

- [ ] **Step 8: Run full test suite**

```bash
flutter test test/unit/
flutter analyze lib/
```
Expected: all tests pass, no analysis errors.

- [ ] **Step 9: Commit**

```bash
git add lib/features/pokedex/presentation/widget/pokemon_grid_card.dart \
        lib/features/pokedex/presentation/widget/pokemon_list_tile.dart
git commit -m "refactor: replace _buildImageUrl with PokemonDataResolver in grid card and list tile"
```

---

## Final verification

- [ ] Run all unit tests: `flutter test test/unit/`
- [ ] Run widget test: `flutter test test/widget/`
- [ ] Run analyzer: `flutter analyze lib/`
- [ ] Build to check no runtime issues: `flutter build apk --debug` (or run on device/simulator)
- [ ] Open a PR referencing issue #235

---

## Self-review checklist

**Spec coverage:**
- ✅ `lib/data/pokemon_data_resolver.dart` created with `resolveFormSprite()` — Task 3
- ✅ Reads cosmetic stems, HOME overrides, versioned paths from `PokemonDataRegistry` — Task 3
- ✅ `sprite_resolver.dart` thinned to call resolver — Task 7
- ✅ `pokemon_list_tile.dart` `_kVgToSubpath` inline logic replaced — Task 8 (`_compactIconUrl` deleted; now in resolver)
- ✅ `pokemon_grid_card.dart` `_buildImageUrl` replaced — Task 8
- ✅ `form_descriptor.dart` `spriteHint()` removed — Task 7
- ✅ `team_detail_screen.dart` `resolveSprite` calls updated — Task 6
- ✅ `slot_config_screen.dart` `resolveSprite` calls updated — Task 6
- ✅ All call sites use `PokemonDataResolver` — Tasks 6, 7, 8
- ✅ Gen 2 crystal fallback chain preserved — `_versionedShinyUrl` logic ported verbatim
- ✅ Female HOME URL pattern (`/home/female/{id}.png`) preserved — `pokemonHomeFemaleUrl()` used
- ✅ Cosmetic form stem logic preserved — internal registry lookup in `resolveFormSprite`
- ✅ Versioned Gen 1–5 paths preserved — same logic as original `sprite_resolver.dart`

**Notes:**
- `SpriteHint` is fully deleted after Task 7 — no backward-compat shim left.
- `resolveSprite()` remains in `sprite_resolver.dart` as a thin wrapper with the updated signature (no `hint` param).
- `_cosmeticHomeUrl` / `_cosmeticHomeShinyUrl` from `form_descriptor.dart` are replaced by `cosmeticFormHomeUrl` / `cosmeticFormHomeShinyUrl` from `pokemon_sprite.dart` (same URL, already public).
