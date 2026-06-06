import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poke_team_dex/services/format/format_models.dart';

const _versionsBase = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
    'master/sprites/pokemon/versions';

// Maps format game id → PokeAPI versions path.
// Uses raw.githubusercontent.com (CORS-safe) instead of play.pokemonshowdown.com
// which blocks browser requests from Flutter Web.
const _gameIdToVersionPath = <String, String>{
  'rb':       'generation-i/red-blue',
  'yellow':   'generation-i/yellow',
  'gs':       'generation-ii/gold',
  'crystal':  'generation-ii/crystal',
  'rs':       'generation-iii/ruby-sapphire',
  'emerald':  'generation-iii/emerald',
  'frlg':     'generation-iii/firered-leafgreen',
  'dp':       'generation-iv/diamond-pearl',
  'platinum': 'generation-iv/platinum',
  'hgss':     'generation-iv/heartgold-soulsilver',
  'bw':       'generation-v/black-white',
  'b2w2':     'generation-v/black-white',
};

// For general gen formats — use the most complete game in that gen.
const _genToDefaultGameId = <int, String>{
  1: 'yellow',
  2: 'crystal',
  3: 'emerald',
  4: 'hgss',
  5: 'bw',
};

// Gen 1-2 sprites in PokeAPI have colored backgrounds in their base folder.
// PokeAPI provides a /transparent/ subfolder where the backgrounds have been
// removed, matching the look of the Pokémon Showdown sprites.
// Gen 3-5 sprites are natively transparent PNGs/GIFs.
bool _needsTransparentSubfolder(int gen) => gen <= 2;

/// Resolves the correct sprite URLs for a Pokémon given the team's format
/// and the user's sprite-style preference.
///
/// Gen 1-5 uses PokeAPI version sprites (raw.githubusercontent.com — CORS safe,
/// transparent backgrounds via /transparent/ subfolder for Gen 1-2).
/// Gen 6+ uses PokéAPI HOME / official artwork.
///
/// [femaleUrl] and [femaleShinyUrl] are non-null for Gen 4+ formats (and HOME)
/// where female-specific sprites exist in the PokeAPI sprites repository.
({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl}) resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required String pokemonName,
  required GameFormat? format,
  required bool useFormatSprites,
}) {
  final rawDefault = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/$pokemonId.png';
  final rawShiny = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/shiny/$pokemonId.png';

  if (!useFormatSprites || format == null) {
    return _homeOrArtwork(sprites, rawDefault, rawShiny);
  }

  final gameId = format.type == FormatType.game
      ? format.id
      : _genToDefaultGameId[format.gen];

  if (gameId != null) {
    final versionPath = _gameIdToVersionPath[gameId];
    if (versionPath != null) {
      final gen = format.gen;
      // Gen 1 had no shiny mechanic — always use the default sprite.
      final noShiny = gen == 1;
      // Gen 5 BW has animated GIF sprites.
      final isAnimated = gameId == 'bw' || gameId == 'b2w2';
      final ext = isAnimated ? '.gif' : '.png';
      // Gen 1-2 need the /transparent/ subfolder for background-free sprites.
      final transparent = _needsTransparentSubfolder(gen) ? 'transparent/' : '';
      // Animated Gen 5 sprites live in a nested /animated/ subfolder.
      final animSeg = isAnimated ? 'animated/' : '';

      // Default: versions/{path}/[animated/][transparent/]{id}.ext
      final defaultUrl =
          '$_versionsBase/$versionPath/$animSeg$transparent$pokemonId$ext';

      // Shiny URL path differs by generation:
      //   Animated (Gen 5): versions/{path}/animated/shiny/{id}.gif
      //   Gen 2: Showdown gen2-shiny/{name}.png (non-web) or PokeAPI shiny/{id}.png (web)
      //   Regular (Gen 3-4): versions/{path}/shiny/{id}.png
      final String shinyUrl;
      if (noShiny) {
        shinyUrl = defaultUrl;
      } else if (isAnimated) {
        shinyUrl = '$_versionsBase/$versionPath/${animSeg}shiny/$pokemonId$ext';
      } else if (transparent.isNotEmpty) {
        // PokeAPI has no transparent/shiny subfolder for Gen 2.
        // On non-web: use Pokémon Showdown which has transparent Gen 2 shiny sprites.
        // On web: fall back to PokeAPI non-transparent shiny (Showdown is CORS-blocked in browsers).
        shinyUrl = kIsWeb
            ? '$_versionsBase/$versionPath/shiny/$pokemonId$ext'
            : 'https://play.pokemonshowdown.com/sprites/gen2-shiny/$pokemonName.png';
      } else {
        shinyUrl = '$_versionsBase/$versionPath/shiny/$pokemonId$ext';
      }

      // Female sprites exist in PokeAPI from Gen 4 onward.
      String? femaleUrl;
      String? femaleShinyUrl;
      if (gen >= 4) {
        femaleUrl = '$_versionsBase/$versionPath/${animSeg}female/$pokemonId$ext';
        femaleShinyUrl = noShiny
            ? femaleUrl
            : '$_versionsBase/$versionPath/${animSeg}shiny/female/$pokemonId$ext';
      }

      return (defaultUrl: defaultUrl, shinyUrl: shinyUrl, femaleUrl: femaleUrl, femaleShinyUrl: femaleShinyUrl);
    }
  }

  // Gen 6+ — PokéAPI HOME / official artwork
  return _homeOrArtwork(sprites, rawDefault, rawShiny);
}

({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl}) _homeOrArtwork(
  Map<String, dynamic>? sprites,
  String rawDefault,
  String rawShiny,
) {
  final home    = sprites == null ? null : _nav(sprites['other'], ['home']);
  final artwork = sprites == null ? null : _nav(sprites['other'], ['official-artwork']);
  return (
    defaultUrl: home?['front_default'] as String? ??
        artwork?['front_default'] as String? ??
        rawDefault,
    shinyUrl: home?['front_shiny'] as String? ??
        artwork?['front_shiny'] as String? ??
        rawShiny,
    femaleUrl: home?['front_female'] as String?,
    femaleShinyUrl: home?['front_shiny_female'] as String?,
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
