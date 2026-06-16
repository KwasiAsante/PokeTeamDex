import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/sprite_resolver.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  group('resolveSprite — no format (HOME / artwork path)', () {
    test('returns HOME url when sprites json has home entry', () {
      final sprites = {
        'other': {
          'home': {
            'front_default': 'https://example.com/home/6.png',
            'front_shiny': 'https://example.com/home/shiny/6.png',
          }
        }
      };
      final result = resolveSprite(
        sprites: sprites,
        pokemonId: 6,
        pokemonName: 'charizard',
        format: null,
        useFormatSprites: false,
        hint: const SpriteHint(),
      );
      expect(result.defaultUrl, 'https://example.com/home/6.png');
      expect(result.shinyUrl, 'https://example.com/home/shiny/6.png');
    });

    test('uses hint.homeUrl when provided (cosmetic form)', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 412,
        pokemonName: 'burmy',
        format: null,
        useFormatSprites: false,
        hint: const SpriteHint(
          stem: '412-sandy',
          homeUrl: 'https://example.com/home/412-sandy.png',
          homeShinyUrl: 'https://example.com/home/shiny/412-sandy.png',
        ),
      );
      expect(result.defaultUrl, 'https://example.com/home/412-sandy.png');
      expect(result.shinyUrl, 'https://example.com/home/shiny/412-sandy.png');
    });
  });

  group('resolveSprite — Gen 1 (no shiny)', () {
    const gen1Format = GameFormat(
      id: 'yellow',
      name: 'Gen 1 Yellow',
      short: 'Yellow',
      type: FormatType.game,
      gen: 1,
    );

    test('shinyUrl equals defaultUrl in Gen 1 (no shiny mechanic)', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 6,
        pokemonName: 'charizard',
        format: gen1Format,
        useFormatSprites: true,
        hint: const SpriteHint(),
      );
      expect(result.shinyUrl, equals(result.defaultUrl));
    });
  });

  group('resolveSprite — hint.stem overrides pokemonId in sprite path', () {
    const gen5Format = GameFormat(
      id: 'bw',
      name: 'Gen 5 BW',
      short: 'BW',
      type: FormatType.game,
      gen: 5,
    );

    test('versioned path uses hint.stem when provided', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 412,
        pokemonName: 'burmy',
        format: gen5Format,
        useFormatSprites: true,
        hint: const SpriteHint(stem: '412-sandy'),
      );
      expect(result.defaultUrl, contains('412-sandy'));
    });
  });
}
