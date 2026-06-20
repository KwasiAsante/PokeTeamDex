// test/unit/pokemon_data_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  // ── resolveVersionedSprite ────────────────────────────────────────────────
  //
  // resolveFormSprite was removed; sprite URLs now come from backend
  // SpriteUrlsFull data.  resolveVersionedSprite is the sole remaining
  // client-side URL constructor for gen 1-5 versioned sprites.

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

    test('shinyUrl equals defaultUrl — no shinies in Gen 1', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.shinyUrl, equals(result.defaultUrl));
    });

    test('femaleUrl is null — no gender sprites before Gen 4', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: gen1,
      );
      expect(result.femaleUrl, isNull);
    });
  });

  group('resolveVersionedSprite — Gen 5 BW animated', () {
    const bw = GameFormat(
      id: 'bw', name: 'BW', short: 'BW',
      type: FormatType.game, gen: 5,
    );

    test('defaultUrl uses .gif extension and animated/ subfolder', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: bw,
      );
      expect(result.defaultUrl, endsWith('.gif'));
      expect(result.defaultUrl, contains('animated/'));
    });

    test('stem appears in URL (cosmetic form suffix)', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 412, pokemonName: 'burmy', stem: '412-sandy', format: bw,
      );
      expect(result.defaultUrl, contains('412-sandy'));
      expect(result.defaultUrl, endsWith('.gif'));
    });
  });

  group('resolveVersionedSprite — Gen 2 Crystal fallback chain', () {
    const crystal = GameFormat(
      id: 'crystal', name: 'Crystal', short: 'Crys',
      type: FormatType.game, gen: 2,
    );

    test('fallbackUrl points to gold, fallbackUrl2 to silver', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 201, pokemonName: 'unown', stem: '201-a', format: crystal,
      );
      expect(result.fallbackUrl, contains('generation-ii/gold'));
      expect(result.fallbackUrl2, contains('generation-ii/silver'));
    });
  });

  group('resolveVersionedSprite — Gen 4 female URLs', () {
    const dp = GameFormat(
      id: 'dp', name: 'DP', short: 'DP',
      type: FormatType.game, gen: 4,
    );

    test('femaleUrl and femaleShinyUrl are non-null for Gen 4+', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 521, pokemonName: 'unfezant', stem: '521', format: dp,
      );
      expect(result.femaleUrl, isNotNull);
      expect(result.femaleShinyUrl, isNotNull);
      expect(result.femaleUrl, contains('female/'));
    });
  });

  group('resolveVersionedSprite — unsupported gen falls back to plain sprite', () {
    const swsh = GameFormat(
      id: 'swsh', name: 'SwSh', short: 'SS',
      type: FormatType.game, gen: 8,
    );

    test('returns sprites/pokemon/{id}.png when no versioned path exists', () {
      final result = PokemonDataResolver.resolveVersionedSprite(
        pokemonId: 6, pokemonName: 'charizard', stem: '6', format: swsh,
      );
      expect(result.defaultUrl, contains('/sprites/pokemon/6.png'));
    });
  });

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
        pokemonId: 422,
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

    test('sprite mode: female cosmetic returns female/{id}.png sprite path', () {
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

    test('sprite mode: cosmetic entry returns spriteUrl when present', () {
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 422,
        baseSpecies: 'shellos',
        selectedFormName: 'shellos-east',
        imageType: PokedexImageType.sprite,
        formEntry: null,
        cosmeticEntry: _makeCosmeticEntry(
          name: 'shellos-east',
          formName: 'east',
          spriteUrl: 'https://example.com/shellos-east.png',
        ),
        filter: null,
      );
      expect(url, 'https://example.com/shellos-east.png');
    });
  });

  group('resolvePokedexImageUrl — variety form selected', () {
    test('artwork: uses officialArtworkUrl from formEntry', () {
      final entry = _makePokemonEntry(
        id: 10001,
        artworkUrl: 'https://example.com/10001.png',
      );
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

    test('compact mode: uses gen-8 icon URL with formEntry.id', () {
      final entry = _makePokemonEntry(id: 10143, artworkUrl: null);
      final url = PokemonDataResolver.resolvePokedexImageUrl(
        pokemonId: 778,
        baseSpecies: 'mimikyu',
        selectedFormName: 'mimikyu-busted',
        imageType: null,
        formEntry: entry,
        cosmeticEntry: null,
        filter: null,
      );
      expect(url, contains('generation-viii/icons/10143.png'));
    });
  });
}

PokemonFormEntry _makeCosmeticEntry({
  required String name,
  required String formName,
  required String? spriteUrl,
}) => PokemonFormEntry(
  id: 99999,
  name: name,
  formName: formName,
  isDefault: false,
  spriteUrl: spriteUrl,
);

PokemonEntry _makePokemonEntry({
  required int id,
  required String? artworkUrl,
  String? frontDefault,
}) => PokemonEntry(
  id: id,
  name: 'test-pokemon',
  height: 1,
  weight: 1,
  types: const [],
  officialArtworkUrl: artworkUrl,
  sprites: frontDefault != null ? {'front_default': frontDefault} : null,
);
