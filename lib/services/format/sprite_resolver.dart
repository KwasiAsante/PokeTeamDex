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

/// Resolves the correct sprite URLs for a Pokémon given the team's format
/// and the user's sprite-style preference.
///
/// Gen 1-5 uses PokeAPI version sprites (raw.githubusercontent.com — CORS safe).
/// Gen 6+ uses PokéAPI HOME / official artwork.
({String? defaultUrl, String? shinyUrl}) resolveSprite({
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
      // Gen 1 had no shiny mechanic — always use the default sprite.
      final noShiny = format.gen == 1;
      // Gen 5 BW has animated GIF sprites.
      final isAnimated = gameId == 'bw' || gameId == 'b2w2';
      final ext = isAnimated ? '.gif' : '.png';
      final animatedSegment = isAnimated ? '/animated' : '';

      final defaultUrl =
          '$_versionsBase/$versionPath$animatedSegment/$pokemonId$ext';
      final shinyUrl = noShiny
          ? defaultUrl
          : '$_versionsBase/$versionPath${isAnimated ? '/animated' : ''}/shiny/$pokemonId$ext';

      return (defaultUrl: defaultUrl, shinyUrl: shinyUrl);
    }
  }

  // Gen 6+ — PokéAPI HOME / official artwork
  return _homeOrArtwork(sprites, rawDefault, rawShiny);
}

({String? defaultUrl, String? shinyUrl}) _homeOrArtwork(
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
