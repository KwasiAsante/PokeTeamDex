import 'package:poke_team_dex/services/format/format_models.dart';

const _psBase = 'https://play.pokemonshowdown.com/sprites';

// Maps format game id → PS sprite directory name (for Gen 1-5 where PS
// sprites have transparent backgrounds unlike PokéAPI's white-bg originals).
const _gameIdToPsDir = <String, String>{
  'rb':       'gen1',
  'yellow':   'gen1',
  'gs':       'gen2',
  'crystal':  'gen2',
  'rs':       'gen3',
  'emerald':  'gen3',
  'frlg':     'gen3',
  'dp':       'gen4',
  'platinum': 'gen4',
  'hgss':     'gen4',
  'bw':       'gen5ani',  // animated GIFs
  'b2w2':     'gen5ani',
};

// For general gen formats — use the latest game in that gen's PS sprites.
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
/// Gen 1-5 uses Pokémon Showdown sprites (transparent backgrounds).
/// Gen 6+ uses PokéAPI HOME / official artwork.
///
/// [pokemonName] must be the PokéAPI/PS name (e.g. "umbreon", "charizard-mega-x").
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
    final psDir = _gameIdToPsDir[gameId];
    if (psDir != null) {
      // Gen 1 has no shiny mechanic — use same sprite
      final noShiny = format.gen == 1;
      final ext = psDir.contains('ani') ? '.gif' : '.png';
      final shinyDir = noShiny ? psDir : '$psDir-shiny';
      return (
        defaultUrl: '$_psBase/$psDir/$pokemonName$ext',
        shinyUrl: '$_psBase/$shinyDir/$pokemonName$ext',
      );
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
