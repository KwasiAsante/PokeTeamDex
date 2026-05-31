import 'package:poke_team_dex/services/format/format_models.dart';

// Maps format game id → path segments into PokéAPI sprites.versions object.
// PokéAPI only has game sprites up to Gen 5; Gen 6+ falls back to HOME/artwork.
const _gameToVersionPath = <String, List<String>>{
  'rb':       ['generation-i',   'red-blue'],
  'yellow':   ['generation-i',   'yellow'],
  'gs':       ['generation-ii',  'gold'],
  'crystal':  ['generation-ii',  'crystal'],
  'rs':       ['generation-iii', 'ruby-sapphire'],
  'emerald':  ['generation-iii', 'emerald'],
  'frlg':     ['generation-iii', 'firered-leafgreen'],
  'dp':       ['generation-iv',  'diamond-pearl'],
  'platinum': ['generation-iv',  'platinum'],
  'hgss':     ['generation-iv',  'heartgold-soulsilver'],
  'bw':       ['generation-v',   'black-white'],
  'b2w2':     ['generation-v',   'black-white'], // same sprites as BW
};

// For general gen formats, use the latest game that has PokéAPI sprites.
const _genToDefaultGameId = <int, String>{
  1: 'yellow',
  2: 'crystal',
  3: 'emerald',
  4: 'hgss',
  5: 'bw',
  // Gen 6+ → no PokéAPI game sprites; falls through to HOME/artwork
};

/// Resolves the correct sprite URLs for a Pokémon given the team's format
/// and the user's sprite-style preference.
///
/// Returns a record `(defaultUrl, shinyUrl)` where either value may be null.
///
/// [sprites] is the raw `sprites` map from PokéAPI's `/pokemon/{id}` response,
/// as stored in `PokemonEntry.sprites`.
/// [pokemonId] is used as a raw-GitHub fallback when PokéAPI sprites are absent.
/// [format] is the team's assigned format, or null for "no format".
/// [useFormatSprites] — when false, always use HOME/official artwork.
({String? defaultUrl, String? shinyUrl}) resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required GameFormat? format,
  required bool useFormatSprites,
}) {
  final rawDefault = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/$pokemonId.png';
  final rawShiny = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/shiny/$pokemonId.png';

  // When no format is set or the toggle is off → HOME > official artwork > raw
  if (!useFormatSprites || format == null || sprites == null) {
    return _homeOrArtwork(sprites, rawDefault, rawShiny);
  }

  // Determine which game id to look up
  final gameId = format.type == FormatType.game
      ? format.id
      : _genToDefaultGameId[format.gen];

  if (gameId != null) {
    final path = _gameToVersionPath[gameId];
    if (path != null) {
      final section = _nav(sprites['versions'], path);
      if (section != null) {
        // Gen 5 has animated sprites — prefer them
        if (gameId == 'bw' || gameId == 'b2w2') {
          final anim = section['animated'];
          if (anim is Map) {
            final d = anim['front_default'] as String?;
            final s = anim['front_shiny'] as String?;
            if (d != null) return (defaultUrl: d, shinyUrl: s ?? rawShiny);
          }
        }
        final d = section['front_default'] as String?;
        final s = section['front_shiny'] as String?;
        if (d != null) return (defaultUrl: d, shinyUrl: s ?? rawShiny);
      }
    }
  }

  // Gen 6+ or game sprite unavailable → HOME > official artwork > raw
  return _homeOrArtwork(sprites, rawDefault, rawShiny);
}

({String? defaultUrl, String? shinyUrl}) _homeOrArtwork(
  Map<String, dynamic>? sprites,
  String rawDefault,
  String rawShiny,
) {
  final home = sprites == null ? null : _nav(sprites['other'], ['home']);
  final artwork = sprites == null
      ? null
      : _nav(sprites['other'], ['official-artwork']);
  return (
    defaultUrl: home?['front_default'] as String? ??
        artwork?['front_default'] as String? ??
        rawDefault,
    shinyUrl: home?['front_shiny'] as String? ??
        artwork?['front_shiny'] as String? ??
        rawShiny,
  );
}

/// Navigate a nested map structure safely.
Map<String, dynamic>? _nav(dynamic root, List<String> path) {
  dynamic cur = root;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  return cur is Map ? cur.cast<String, dynamic>() : null;
}
