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

    test('cosmetic form not in registry but name follows baseSpecies-suffix pattern: uses suffix-based HOME url', () {
      // cherrim-sunshine is NOT in cosmeticSpriteStems (only 7 species are),
      // but its name starts with 'cherrim-' so the fallback must kick in.
      final result = PokemonDataResolver.resolveFormSprite(
        sprites: null,
        pokemonId: 421,
        pokemonName: 'cherrim-sunshine',
        baseSpecies: 'cherrim',
        formName: 'cherrim-sunshine',
        format: null,
        useFormatSprites: false,
      );
      expect(result.defaultUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/421-sunshine.png');
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
  types: const {},
  officialArtworkUrl: artworkUrl,
  sprites: frontDefault != null ? {'front_default': frontDefault} : null,
);
