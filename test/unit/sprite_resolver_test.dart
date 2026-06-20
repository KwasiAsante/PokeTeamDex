// test/unit/sprite_resolver_test.dart
//
// Tests for PokemonDataResolver.resolveVersionedSprite.
//
// sprite_resolver.dart (the old thin wrapper around resolveFormSprite) was
// deleted when the sprite-resolution logic was refactored to use backend
// SpriteUrlsFull data directly.  resolveVersionedSprite is the sole remaining
// client-side URL constructor — it handles gen 1-5 versioned sprites that the
// backend cannot provide without a gen parameter.

import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  // ── Gen 1 (Yellow) ─────────────────────────────────────────────────────────

  group('resolveVersionedSprite — Gen 1 Yellow', () {
    const gen1 = GameFormat(
      id: 'yellow', name: 'Yellow', short: 'Yel',
      type: FormatType.game, gen: 1,
    );

    test('defaultUrl uses transparent/ subfolder and .png extension', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.defaultUrl, contains('transparent/'));
      expect(result.defaultUrl, endsWith('.png'));
    });

    test('shinyUrl equals defaultUrl — no shinies exist in Gen 1', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.shinyUrl, equals(result.defaultUrl));
    });

    test('femaleUrl is null — no gender-specific sprites before Gen 4', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.femaleUrl, isNull);
      expect(result.femaleShinyUrl, isNull);
    });

    test('fallbackUrl and fallbackUrl2 are null for non-Crystal formats', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.fallbackUrl, isNull);
      expect(result.fallbackUrl2, isNull);
    });
  });

  // ── Gen 2 (Crystal) — fallback chain ─────────────────────────────────────

  group('resolveVersionedSprite — Gen 2 Crystal fallback chain', () {
    const crystal = GameFormat(
      id: 'crystal', name: 'Crystal', short: 'Crys',
      type: FormatType.game, gen: 2,
    );

    test('fallbackUrl points to generation-ii/gold', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 201, pokemonName: 'unown', stem: '201-a', format: crystal,
      );
      expect(result.fallbackUrl, contains('generation-ii/gold'));
    });

    test('fallbackUrl2 points to generation-ii/silver', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 201, pokemonName: 'unown', stem: '201-a', format: crystal,
      );
      expect(result.fallbackUrl2, contains('generation-ii/silver'));
    });

    test('stem appears in all fallback URLs', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 201, pokemonName: 'unown', stem: '201-a', format: crystal,
      );
      expect(result.fallbackUrl, contains('201-a'));
      expect(result.fallbackUrl2, contains('201-a'));
    });
  });

  // ── Gen 5 (Black/White animated) ─────────────────────────────────────────

  group('resolveVersionedSprite — Gen 5 BW animated', () {
    const bw = GameFormat(
      id: 'bw', name: 'BW', short: 'BW',
      type: FormatType.game, gen: 5,
    );

    test('defaultUrl uses animated/ subfolder and .gif extension', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: bw,
      );
      expect(result.defaultUrl, endsWith('.gif'));
      expect(result.defaultUrl, contains('animated/'));
    });

    test('shinyUrl uses animated/shiny/ subfolder', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: bw,
      );
      expect(result.shinyUrl, contains('animated/shiny/'));
    });

    test('stem parameter appears in URL (cosmetic form suffix)', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 412, pokemonName: 'burmy', stem: '412-sandy', format: bw,
      );
      expect(result.defaultUrl, contains('412-sandy'));
      expect(result.defaultUrl, endsWith('.gif'));
    });

    test('fallbackUrl is null for BW (not Crystal)', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: bw,
      );
      expect(result.fallbackUrl, isNull);
    });
  });

  // ── Gen 4 (HeartGold/SoulSilver) — female URLs ───────────────────────────

  group('resolveVersionedSprite — Gen 4 female URLs', () {
    const hgss = GameFormat(
      id: 'hgss', name: 'HGSS', short: 'HGSS',
      type: FormatType.game, gen: 4,
    );

    test('femaleUrl and femaleShinyUrl are non-null for Gen 4+', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 521, pokemonName: 'unfezant', stem: '521', format: hgss,
      );
      expect(result.femaleUrl, isNotNull);
      expect(result.femaleShinyUrl, isNotNull);
    });

    test('femaleUrl contains female/ subdirectory', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 521, pokemonName: 'unfezant', stem: '521', format: hgss,
      );
      expect(result.femaleUrl, contains('female/'));
    });

    test('uses static .png (not animated .gif) for Gen 4', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 521, pokemonName: 'unfezant', stem: '521', format: hgss,
      );
      expect(result.defaultUrl, endsWith('.png'));
      expect(result.defaultUrl, isNot(contains('.gif')));
    });
  });

  // ── Unsupported gen — pixel sprite fallback ───────────────────────────────

  group('resolveVersionedSprite — unsupported gen falls back to plain sprite', () {
    // Gen 8 (SWSH) has no versioned sprite directories in the PokeAPI repo.
    const swsh = GameFormat(
      id: 'swsh', name: 'Sword/Shield', short: 'SwSh',
      type: FormatType.game, gen: 8,
    );

    test('returns sprites/pokemon/{id}.png when no versioned path exists', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: swsh,
      );
      expect(result.defaultUrl, contains('/sprites/pokemon/6.png'));
    });

    test('fallbackUrl and fallbackUrl2 are null for unsupported gen', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: swsh,
      );
      expect(result.fallbackUrl, isNull);
      expect(result.fallbackUrl2, isNull);
    });
  });
}
