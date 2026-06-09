import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

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

/// Resolves sprite URLs for a Pokémon given the team's format and sprite preference.
///
/// Pass a [SpriteHint] from [FormDescriptor.spriteHint] to supply cosmetic-form
/// overrides (stem, homeUrl, homeShinyUrl). For all other forms, pass [SpriteHint()].
///
/// Gen 1-5 uses PokeAPI version sprites (raw.githubusercontent.com — CORS safe,
/// transparent backgrounds via /transparent/ subfolder for Gen 1-2).
/// Gen 6+ uses PokéAPI HOME / official artwork.
///
/// [femaleUrl] and [femaleShinyUrl] are non-null for Gen 4+ formats (and HOME)
/// where female-specific sprites exist in the PokeAPI sprites repository.
///
/// [fallbackUrl] and [fallbackUrl2] are non-null for Gen 2 crystal format: they
/// hold the gold and silver paths respectively. Crystal's transparent/ subfolder
/// lacks some form-variant sprites (e.g. Unown letter forms) that exist in gold
/// and silver, so callers should pass these through to PokemonSprite's fallback
/// chain.
({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl, String? fallbackUrl, String? fallbackUrl2})
    resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required String pokemonName,
  required GameFormat? format,
  required bool useFormatSprites,
  required SpriteHint hint,
}) {
  final stem = hint.stem ?? '$pokemonId';
  AppLogger().d('resolveSprite: $pokemonName | id=$pokemonId | format=${format?.id} | stem=$stem | hint.stem=${hint.stem}');
  final rawDefault = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/$stem.png';
  final rawShiny = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/shiny/$stem.png';

  if (!useFormatSprites || format == null) {
    final result = _homeOrArtwork(sprites, rawDefault, rawShiny, hint: hint);
    AppLogger().d('resolveSprite: → HOME | default=${result.defaultUrl}');
    return result;
  }

  final gameId = format.type == FormatType.game
      ? format.id
      : _genToDefaultGameId[format.gen];

  if (gameId != null) {
    final versionPath = _gameIdToVersionPath[gameId];
    if (versionPath != null) {
      final gen        = format.gen;
      // Gen 5 BW has animated GIF sprites.
      final isAnimated = gameId == 'bw' || gameId == 'b2w2';
      final ext        = isAnimated ? '.gif' : '.png';
      // Gen 1-2 need the /transparent/ subfolder for background-free sprites.
      final transparent = _needsTransparentSubfolder(gen) ? 'transparent/' : '';
      // Animated Gen 5 sprites live in a nested /animated/ subfolder.
      final animSeg    = isAnimated ? 'animated/' : '';

      final defaultUrl = _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
      final shinyUrl   = _versionedShinyUrl(versionPath, gen, animSeg, transparent, stem, ext, pokemonName);
      final (femaleUrl, femaleShinyUrl) = _versionedFemaleUrls(versionPath, gen, animSeg, stem, ext);

      // Gen 2 crystal lacks transparent form-variant sprites (e.g. Unown letter
      // forms). Gold and silver have full coverage, so provide them as fallbacks.
      String? fallbackUrl;
      String? fallbackUrl2;
      if (gameId == 'crystal') {
        fallbackUrl  = _versionedDefaultUrl('generation-ii/gold',   animSeg, transparent, stem, ext);
        fallbackUrl2 = _versionedDefaultUrl('generation-ii/silver', animSeg, transparent, stem, ext);
      }

      AppLogger().d('resolveSprite: → versioned | default=$defaultUrl | shiny=$shinyUrl');
      return (defaultUrl: defaultUrl, shinyUrl: shinyUrl, femaleUrl: femaleUrl, femaleShinyUrl: femaleShinyUrl, fallbackUrl: fallbackUrl, fallbackUrl2: fallbackUrl2);
    }
  }

  // Gen 6+ or unrecognised game — PokéAPI HOME / official artwork
  return _homeOrArtwork(sprites, rawDefault, rawShiny, hint: hint);
}

// ── Named URL helpers ─────────────────────────────────────────────────────

String _versionedDefaultUrl(
  String versionPath, String animSeg, String transparent, String stem, String ext,
) => '$_versionsBase/$versionPath/$animSeg$transparent$stem$ext';

String _versionedShinyUrl(
  String versionPath, int gen, String animSeg, String transparent,
  String stem, String ext, String pokemonName,
) {
  if (gen == 1) return _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
  if (animSeg.isNotEmpty) return '$_versionsBase/$versionPath/${animSeg}shiny/$stem$ext';
  if (transparent.isNotEmpty) {
    // PokeAPI has no transparent/shiny subfolder for Gen 2.
    // On non-web: use Pokémon Showdown which has transparent Gen 2 shiny sprites.
    // On web: fall back to PokeAPI non-transparent shiny (Showdown is CORS-blocked in browsers).
    return kIsWeb
        ? '$_versionsBase/$versionPath/shiny/$stem$ext'
        : 'https://play.pokemonshowdown.com/sprites/gen2-shiny/$pokemonName.png';
  }
  return '$_versionsBase/$versionPath/shiny/$stem$ext';
}

(String? femaleUrl, String? femaleShinyUrl) _versionedFemaleUrls(
  String versionPath, int gen, String animSeg, String stem, String ext,
) {
  if (gen < 4) return (null, null);
  final femaleUrl = '$_versionsBase/$versionPath/${animSeg}female/$stem$ext';
  final femaleShinyUrl = '$_versionsBase/$versionPath/${animSeg}shiny/female/$stem$ext';
  return (femaleUrl, femaleShinyUrl);
}

({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl, String? fallbackUrl, String? fallbackUrl2})
    _homeOrArtwork(
  Map<String, dynamic>? sprites,
  String rawDefault,
  String rawShiny, {
  required SpriteHint hint,
}) {
  final home    = sprites == null ? null : _nav(sprites['other'], ['home']);
  final artwork = sprites == null ? null : _nav(sprites['other'], ['official-artwork']);
  return (
    defaultUrl: hint.homeUrl ??
        home?['front_default'] as String? ??
        artwork?['front_default'] as String? ??
        rawDefault,
    shinyUrl: hint.homeShinyUrl ??
        home?['front_shiny'] as String? ??
        artwork?['front_shiny'] as String? ??
        rawShiny,
    femaleUrl: home?['front_female'] as String?,
    femaleShinyUrl: home?['front_shiny_female'] as String?,
    fallbackUrl: null,
    fallbackUrl2: null,
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
