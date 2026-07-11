import 'package:dio/dio.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

/// Mirrors the backend's `pokemon_resolver.py` sprite-URL construction
/// (`_build_variety_sprite_urls`, `_build_base_sprite_urls`,
/// `_build_form_sprite_urls`, `_build_pokeapi_sprite_url`,
/// `_build_showdown_sprite_url`, `_build_icon_url`, `_to_showdown_name`) so
/// the offline fallback paths of `resolvedPokemonProvider`,
/// `pokemonVarietiesProvider`, and `pokemonFormsProvider` produce the same
/// [SpriteUrlsFull] shape as the backend `/resolved`, `/varieties`, and
/// `/forms` pipelines, given the same raw PokéAPI data.

const _kShowdownCdn = 'https://play.pokemonshowdown.com/sprites';
const _kPokeApiSpritesVersions =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
const _kPokeApiPlainSprites =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
const _kPokeApiHome = '$_kPokeApiPlainSprites/other/home';
const _kPokeApiOa = '$_kPokeApiPlainSprites/other/official-artwork';

/// PokéAPI form name suffix -> PokeAPI/sprites repo suffix. The sprites repo
/// uses shorter names for some forms whose PokéAPI slug is longer (e.g.
/// "shellos-east-sea" -> sprites use "422-east.png", not "422-east-sea.png").
/// Mirrors the backend's `_SPRITE_SUFFIX_REMAP`.
const Map<String, String> _kSpriteSuffixRemap = {
  'east-sea': 'east',
  'blue-flower': 'blue',
  'orange-flower': 'orange',
  'red-flower': 'red',
  'white-flower': 'white',
  'yellow-flower': 'yellow',
  'blue-petal': 'blue',
  'orange-petal': 'orange',
  'red-petal': 'red',
  'white-petal': 'white',
  'yellow-petal': 'yellow',
};

/// gen -> (gamePath, subdir, ext, shinySubdir)
const Map<int, (String, String, String, String)> _kGenSpriteConfig = {
  1: ('generation-i/yellow', 'transparent', 'png', ''),
  2: ('generation-ii/crystal', 'animated', 'gif', 'animated/shiny'),
  3: ('generation-iii/emerald', '', 'png', 'shiny'),
  4: ('generation-iv/heartgold-soulsilver', '', 'png', 'shiny'),
  5: ('generation-v/black-white', 'animated', 'gif', 'animated/shiny'),
  6: ('generation-vi/omegaruby-alphasapphire', '', 'png', 'shiny'),
  7: ('generation-vii/ultra-sun-ultra-moon', '', 'png', 'shiny'),
  // gen 8 has no versioned sprite directories — Showdown fallback only.
  9: ('generation-ix/scarlet-violet', '', 'png', ''),
};

const Map<int, String> _kShowdownGenDirs = {
  1: 'gen1',
  2: 'gen2',
  3: 'gen3',
  4: 'gen4',
  5: 'gen5',
  6: 'gen6',
};
const Map<int, String> _kShowdownGenShinyDirs = {
  2: 'gen2-shiny',
  3: 'gen3-shiny',
  4: 'gen4-shiny',
  5: 'gen5-shiny',
};

final RegExp _kMegaXySuffix = RegExp(r'-mega-([a-z])$');

/// Converts a PokéAPI pokemon name to its Showdown CDN sprite filename stem.
/// Mirrors the backend's `_to_showdown_name`.
String toShowdownName(String pokeApiName, Map<String, String> psExceptions) {
  final override = psExceptions[pokeApiName];
  if (override != null) return override;
  return pokeApiName.replaceAllMapped(_kMegaXySuffix, (m) => '-mega${m[1]}');
}

/// Derives the PokeAPI/sprites suffix from a form name (e.g. "unown-b" +
/// "unown" -> "b"). Mirrors the backend's `_extract_form_suffix`.
String? extractFormSuffix(String formName, String speciesName) {
  final prefix = '$speciesName-';
  if (formName.startsWith(prefix)) return formName.substring(prefix.length);
  return null;
}

/// Mirrors the backend's `_build_pokeapi_sprite_url`.
String? _buildPokeApiSpriteUrl(
  String spriteId,
  int gen, {
  bool shiny = false,
  bool female = false,
}) {
  final config = _kGenSpriteConfig[gen];
  if (config == null) return null;
  final (gamePath, subdir, ext, shinySubdir) = config;
  List<String> parts;
  if (shiny) {
    if (shinySubdir.isEmpty) return null;
    parts = [_kPokeApiSpritesVersions, gamePath, shinySubdir, '$spriteId.$ext'];
  } else if (subdir.isNotEmpty) {
    parts = [_kPokeApiSpritesVersions, gamePath, subdir, '$spriteId.$ext'];
  } else {
    parts = [_kPokeApiSpritesVersions, gamePath, '$spriteId.$ext'];
  }
  if (female) {
    if (gen < 4) return null;
    parts.insert(parts.length - 1, 'female');
  }
  return parts.join('/');
}

/// Mirrors the backend's `_build_showdown_sprite_url`.
String? _buildShowdownSpriteUrl(String psName, int gen, {bool shiny = false}) {
  if (shiny && gen == 1) return null;
  if (gen <= 5) {
    final genDir = _kShowdownGenDirs[gen] ?? 'dex';
    if (shiny) {
      final shinyDir = _kShowdownGenShinyDirs[gen] ?? 'dex-shiny';
      return '$_kShowdownCdn/$shinyDir/$psName.png';
    }
    return '$_kShowdownCdn/$genDir/$psName.png';
  } else if (gen == 6) {
    final dirName = shiny ? 'gen6-shiny' : 'gen6';
    return '$_kShowdownCdn/$dirName/$psName.png';
  } else {
    final dirName = shiny ? 'dex-shiny' : 'dex';
    return '$_kShowdownCdn/$dirName/$psName.png';
  }
}

/// Mirrors the backend's `_build_icon_url`.
String buildIconUrl(Object pokemonId, int? gen, {bool female = false}) {
  if (gen == null || gen >= 8) {
    final subdir = female ? 'female/' : '';
    return '$_kPokeApiSpritesVersions/generation-viii/icons/$subdir$pokemonId.png';
  } else if (gen >= 7) {
    final subdir = female ? 'female/' : '';
    return '$_kPokeApiSpritesVersions/generation-vii/icons/$subdir$pokemonId.png';
  } else if (gen == 5) {
    final suffix = female ? '-female' : '';
    return '$_kPokeApiSpritesVersions/generation-v/icons/$pokemonId$suffix.png';
  } else {
    final subdir = female ? 'female/' : '';
    return '$_kPokeApiPlainSprites/$subdir$pokemonId.png';
  }
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

/// Builds full sprite URLs for a Pokémon that has its own `/pokemon` resource
/// — either the base Pokémon or one of its varieties. Mirrors the backend's
/// `_build_variety_sprite_urls` (reused by `_build_base_sprite_urls` for the
/// base Pokémon call site).
///
/// [genSpriteIdOverride] replaces the numeric ID in the versioned sprite path
/// only — home and official artwork still use [varietyId]. Pass this for the
/// base Pokémon when its default form has a suffix in the PokeAPI/sprites repo
/// (e.g. Unown "201-a" instead of "201").
SpriteUrlsFull buildVarietySpriteUrls({
  required Map<String, dynamic>? sprites,
  required String psName,
  required int varietyId,
  required int? gen,
  String? genSpriteIdOverride,
  String varietyName = '',
  int? basePokemonId,
  Map<String, String> varietyIconIdOverrides = const {},
}) {
  final s = sprites ?? {};
  final other = _asMap(s['other']) ?? {};
  final artwork = _asMap(other['official-artwork']) ?? {};
  final home = _asMap(other['home']) ?? {};

  final spriteId = genSpriteIdOverride ?? '$varietyId';
  String? gameFront, gameFrontShiny, gameFrontFemale, gameFrontFemaleShiny;
  if (gen != null && _kGenSpriteConfig.containsKey(gen)) {
    final (gamePath, subdir, _, _) = _kGenSpriteConfig[gen]!;
    final split = gamePath.split('/');
    final genKey = split[0];
    final gameKey = gamePath.substring(genKey.length + 1);
    final versioned = _asMap(_asMap(s['versions'])?[genKey])?[gameKey];
    final versionedMap = _asMap(versioned) ?? {};
    final pool = subdir.isNotEmpty ? (_asMap(versionedMap[subdir]) ?? {}) : versionedMap;
    gameFront = pool['front_default'] as String? ??
        _buildPokeApiSpriteUrl(spriteId, gen) ??
        _buildShowdownSpriteUrl(psName, gen);
    gameFrontShiny = pool['front_shiny'] as String? ??
        _buildPokeApiSpriteUrl(spriteId, gen, shiny: true) ??
        _buildShowdownSpriteUrl(psName, gen, shiny: true);
    gameFrontFemale = pool['front_female'] as String? ??
        _buildPokeApiSpriteUrl(spriteId, gen, female: true);
    gameFrontFemaleShiny = pool['front_shiny_female'] as String? ??
        pool['front_female_shiny'] as String? ??
        _buildPokeApiSpriteUrl(spriteId, gen, shiny: true, female: true);
  } else {
    // gen == null: use root sprites — always non-null for existing Pokémon
    // and represent the canonical current-gen artwork.
    gameFront = s['front_default'] as String?;
    gameFrontShiny = s['front_shiny'] as String?;
    gameFrontFemale = s['front_female'] as String?;
    gameFrontFemaleShiny =
        s['front_shiny_female'] as String? ?? s['front_female_shiny'] as String?;
  }

  final hasFemaleHome = (home['front_female'] as String?)?.isNotEmpty ?? false;

  final versions = _asMap(s['versions']) ?? {};
  final gen8Icon =
      _asMap(_asMap(versions['generation-viii'])?['icons'])?['front_default'] as String?;
  final gen5IconFemale =
      _asMap(_asMap(versions['generation-v'])?['icons'])?['front_female'] as String?;
  final iconOverrideId = varietyIconIdOverrides[varietyName];

  String? icon;
  if (gen8Icon != null && gen8Icon.isNotEmpty) {
    icon = gen8Icon;
  } else if (iconOverrideId != null) {
    icon = buildIconUrl(iconOverrideId, gen);
  } else if (varietyName.endsWith('-female') && basePokemonId != null) {
    icon = buildIconUrl(basePokemonId, gen, female: true);
  } else {
    icon = buildIconUrl(varietyId, gen);
  }

  return SpriteUrlsFull(
    officialArtwork: artwork['front_default'] as String?,
    officialArtworkShiny: artwork['front_shiny'] as String?,
    officialArtworkFemale: artwork['front_female'] as String?,
    officialArtworkFemaleShiny: artwork['front_shiny_female'] as String?,
    home: home['front_default'] as String?,
    homeShiny: home['front_shiny'] as String?,
    homeFemale: home['front_female'] as String?,
    homeFemaleShiny: home['front_female_shiny'] as String? ?? home['front_shiny_female'] as String?,
    gameFront: gameFront,
    gameFrontShiny: gameFrontShiny,
    gameFrontFemale: gameFrontFemale,
    gameFrontFemaleShiny: gameFrontFemaleShiny,
    icon: icon,
    iconShiny: gameFrontShiny,
    iconFemale: gen5IconFemale ??
        (hasFemaleHome ? buildIconUrl(varietyId, gen, female: true) : null),
    iconFemaleShiny: null,
  );
}

/// Derives the `genSpriteIdOverride` for the base Pokémon call site. Mirrors
/// the backend's gen_sprite_id computation in `resolve()` (see the docstring
/// on `_build_base_sprite_urls` for the Unown rationale).
String? baseGenSpriteIdOverride({
  required int pokemonId,
  required List<String> formNames,
  required String speciesName,
}) {
  final firstForm = formNames.isNotEmpty ? formNames.first : '';
  var suffix = (firstForm.isNotEmpty && formNames.length > 1)
      ? extractFormSuffix(firstForm, speciesName)
      : null;
  if (suffix == 'male' || suffix == 'female') suffix = null;
  return suffix != null ? '$pokemonId-$suffix' : null;
}

final Dio _probeDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 5),
));

/// HEAD-checks a URL. Returns the URL on 200, null otherwise. Mirrors the
/// backend's `_probe_url`.
Future<String?> probeSpriteUrl(String url) async {
  try {
    final response = await _probeDio.head(url);
    return response.statusCode == 200 ? url : null;
  } catch (_) {
    return null;
  }
}

/// (homeUrl, homeShinyUrl) for a cosmetic form-entry, to be HEAD-probed
/// before use. Mirrors the backend's `_form_home_paths`.
///
/// Female forms live at `home/female/{id}.png`, not `home/{id}-female.png` —
/// same subdirectory pattern as `icons/female/{id}.png`. All other forms use
/// the `{id}-{mappedSuffix}.png` pattern.
(String, String) formHomeProbePaths(String formName, String speciesName, int baseId) {
  final sfx = extractFormSuffix(formName, speciesName);
  final mapped = sfx != null ? (_kSpriteSuffixRemap[sfx] ?? sfx) : null;
  if (mapped == 'female') {
    return ('$_kPokeApiHome/female/$baseId.png', '$_kPokeApiHome/shiny/female/$baseId.png');
  }
  final homeId = mapped != null ? '$baseId-$mapped' : '$baseId';
  return ('$_kPokeApiHome/$homeId.png', '$_kPokeApiHome/shiny/$homeId.png');
}

/// Official-artwork URL for a cosmetic form-entry, to be HEAD-probed before
/// use. Mirrors the backend's `_form_oa_url`.
String formOaProbeUrl(String formName, String speciesName, int baseId) {
  final sfx = extractFormSuffix(formName, speciesName);
  final mapped = sfx != null ? (_kSpriteSuffixRemap[sfx] ?? sfx) : null;
  final oaId = mapped != null ? '$baseId-$mapped' : '$baseId';
  return '$_kPokeApiOa/$oaId.png';
}

/// Builds full sprite URLs for a cosmetic form-entry (no `/pokemon` resource
/// of its own). Mirrors the backend's `_build_form_sprite_urls`.
///
/// [pokeapiHome]/[pokeapiHomeShiny]/[pokeapiOa] must be pre-probed (see
/// [formHomeProbePaths] / [formOaProbeUrl] / [probeSpriteUrl]) — this
/// function itself does no network I/O, exactly like its backend
/// counterpart.
///
/// [isDefaultForm] = true means the form IS the base Pokémon (index 0 in
/// `forms[]`). PokeAPI root sprites and Showdown HOME/dex directories store
/// the default form under the base name — NOT the suffixed name — but the
/// versioned PokeAPI sprite directories (gen 2 Crystal animated, gen 5 BW
/// animated) DO use the suffixed ID regardless of [isDefaultForm].
SpriteUrlsFull buildFormSpriteUrls({
  required String formName,
  required int baseId,
  required String speciesName,
  required String psName,
  required int gen,
  bool isDefaultForm = false,
  String? pokeapiHome,
  String? pokeapiHomeShiny,
  String? pokeapiOa,
}) {
  final suffix = extractFormSuffix(formName, speciesName);
  final repoSuffix = suffix != null ? (_kSpriteSuffixRemap[suffix] ?? suffix) : null;
  final spriteId = repoSuffix != null ? '$baseId-$repoSuffix' : '$baseId';

  // HOME and dex Showdown paths: default form uses base species name.
  final homePsName = isDefaultForm ? speciesName : psName;

  // Versioned PokeAPI sprites (primary) still use the suffixed sprite_id —
  // crystal/animated/201-a.gif is correct even for the default/A form.
  // Showdown fallback uses homePsName (base name for default form).
  final gameFront =
      _buildPokeApiSpriteUrl(spriteId, gen) ?? _buildShowdownSpriteUrl(homePsName, gen);
  final gameFrontShiny = _buildPokeApiSpriteUrl(spriteId, gen, shiny: true) ??
      _buildShowdownSpriteUrl(homePsName, gen, shiny: true);

  // Prefer PokeAPI CDN (no CORS on web). Fall back to Showdown (works on
  // mobile/desktop but blocked by CORS policy in browsers).
  final homeUrl = pokeapiHome ?? '$_kShowdownCdn/home/$homePsName.png';
  final homeShinyUrl = pokeapiHomeShiny ?? '$_kShowdownCdn/home-shiny/$homePsName.png';

  return SpriteUrlsFull(
    officialArtwork: pokeapiOa,
    officialArtworkShiny: null,
    home: homeUrl,
    homeShiny: homeShinyUrl,
    homeFemale: null,
    homeFemaleShiny: null,
    gameFront: gameFront,
    gameFrontShiny: gameFrontShiny,
    gameFrontFemale: null,
    gameFrontFemaleShiny: null,
    // Female form entries live at icons/female/{base_id}.png, not
    // icons/{base_id}-female.png — use the female=True path for those.
    icon: repoSuffix == 'female'
        ? buildIconUrl(baseId, gen, female: true)
        : buildIconUrl(spriteId, gen),
    iconShiny: gameFrontShiny,
  );
}

/// Fallback front-sprite URL for a cosmetic form-entry, used when neither the
/// `pokemon-form` API response nor the probed HOME URL has a sprite. Mirrors
/// the backend's `fallback_front` computation in `_fetch_forms`.
String formFallbackFrontUrl(String formName, String speciesName, int baseId) {
  final suffix = extractFormSuffix(formName, speciesName);
  final repoSuffix = suffix != null ? (_kSpriteSuffixRemap[suffix] ?? suffix) : null;
  if (repoSuffix == 'female') {
    return '$_kPokeApiPlainSprites/female/$baseId.png';
  }
  final spriteId = suffix != null ? '$baseId-$suffix' : '$baseId';
  return '$_kPokeApiPlainSprites/$spriteId.png';
}

/// Builds sprite URLs for a cosmetic form-entry, HEAD-probing the
/// home/home-shiny/official-artwork PokeAPI CDN paths first — full parity
/// with the backend's `_fetch_forms` + `_build_form_sprite_urls` pipeline.
Future<SpriteUrlsFull> buildFormSpriteUrlsProbed({
  required String formName,
  required int baseId,
  required String speciesName,
  required int gen,
  required Map<String, String> psExceptions,
  bool isDefaultForm = false,
}) async {
  final psName = toShowdownName(formName, psExceptions);
  final (homePath, homeShinyPath) = formHomeProbePaths(formName, speciesName, baseId);
  final oaPath = formOaProbeUrl(formName, speciesName, baseId);

  final probed = await Future.wait([
    probeSpriteUrl(homePath),
    probeSpriteUrl(homeShinyPath),
    probeSpriteUrl(oaPath),
  ]);

  return buildFormSpriteUrls(
    formName: formName,
    baseId: baseId,
    speciesName: speciesName,
    psName: psName,
    gen: gen,
    isDefaultForm: isDefaultForm,
    pokeapiHome: probed[0],
    pokeapiHomeShiny: probed[1],
    pokeapiOa: probed[2],
  );
}
