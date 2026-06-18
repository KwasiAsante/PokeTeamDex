// lib/data/pokemon_data_resolver.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart' show SpriteUrlsFull;
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart'
    show cosmeticFormHomeUrl, cosmeticFormHomeShinyUrl, pokemonHomeFemaleUrl;

const _versionsBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
const _spritesBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

class PokemonDataResolver {
  PokemonDataResolver._();

  /// Resolves all sprite URLs for a Pokémon form.
  ///
  /// Replaces `resolveSprite()` from `sprite_resolver.dart`.
  ///
  /// Pass [baseSpecies] + [formName] instead of constructing a SpriteHint —
  /// this method handles the registry lookup internally.
  /// For Gen 1–5 the full versioned URL set is returned.
  /// For Gen 6+ (or useFormatSprites false) HOME/official-artwork is used.
  ///
  /// [fallbackUrl] and [fallbackUrl2] are only non-null for the Crystal game
  /// format: they hold the Gold and Silver paths for the Crystal → Gold → Silver
  /// fallback chain (Crystal's transparent/ subfolder lacks some form-variant
  /// sprites, e.g. Unown letter forms).
  ///
  /// [femaleUrl] and [femaleShinyUrl] are non-null for Gen 4+ versioned formats
  /// where female-specific sprites exist in the PokeAPI sprites repository.
  /// They are null for Gen 1–3 versioned formats and for the HOME/artwork path.
  static ({
    String? defaultUrl,
    String? shinyUrl,
    String? femaleUrl,
    String? femaleShinyUrl,
    String? fallbackUrl,
    String? fallbackUrl2,
  }) resolveFormSprite({
    required Map<String, dynamic>? sprites,
    required int pokemonId,
    required String pokemonName,
    required String baseSpecies,
    required String? formName,
    required GameFormat? format,
    required bool useFormatSprites,
  }) {
    final registry = PokemonDataRegistry.instance;

    // Build cosmetic hint internally (replaces FormDescriptor.spriteHint).
    String? cosmeticStem;
    String? cosmeticHome;
    String? cosmeticHomeShiny;
    if (formName != null) {
      final stems = registry.cosmeticSpriteStems[baseSpecies];
      if (stems != null && stems.containsKey(formName)) {
        // Registry entry: stem may differ from id-suffix pattern (e.g. unown letters).
        final s = stems[formName]!;
        final suffix = s.split('-').last;
        cosmeticStem = s;
        cosmeticHome = cosmeticFormHomeUrl(pokemonId, suffix);
        cosmeticHomeShiny = cosmeticFormHomeShinyUrl(pokemonId, suffix);
      } else if (formName.startsWith('$baseSpecies-')) {
        // Fallback for cosmetic species not in the registry (cherrim, frillish, etc.).
        // The sprite naming convention is "{baseSpeciesId}-{suffix}" for all cosmetic
        // forms, so we can derive the stem directly from the form name.
        final suffix = formName.substring(baseSpecies.length + 1);
        cosmeticStem = '$pokemonId-$suffix';
        cosmeticHome = cosmeticFormHomeUrl(pokemonId, suffix);
        cosmeticHomeShiny = cosmeticFormHomeShinyUrl(pokemonId, suffix);
      }
    }

    final stem = cosmeticStem ?? '$pokemonId';
    final rawDefault = '$_spritesBase$stem.png';
    final rawShiny = '${_spritesBase}shiny/$stem.png';

    if (!useFormatSprites || format == null) {
      return _homeOrArtwork(
        sprites, rawDefault, rawShiny,
        cosmeticHome: cosmeticHome,
        cosmeticHomeShiny: cosmeticHomeShiny,
      );
    }

    final gameId = format.type == FormatType.game
        ? format.id
        : registry.genToDefaultGameId[format.gen];

    if (gameId != null) {
      final versionPath = registry.gameIdToVersionPath[gameId];
      if (versionPath != null) {
        final gen = format.gen;
        final isAnimated = gameId == 'bw' || gameId == 'b2w2';
        final ext = isAnimated ? '.gif' : '.png';
        final transparent = gen <= 2 ? 'transparent/' : '';
        final animSeg = isAnimated ? 'animated/' : '';

        final defaultUrl =
            _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
        final shinyUrl = _versionedShinyUrl(
            versionPath, gen, animSeg, transparent, stem, ext, pokemonName);
        final (femaleUrl, femaleShinyUrl) =
            _versionedFemaleUrls(versionPath, gen, animSeg, stem, ext);

        String? fallbackUrl;
        String? fallbackUrl2;
        if (gameId == 'crystal') {
          fallbackUrl = _versionedDefaultUrl(
              'generation-ii/gold', animSeg, transparent, stem, ext);
          fallbackUrl2 = _versionedDefaultUrl(
              'generation-ii/silver', animSeg, transparent, stem, ext);
        }

        return (
          defaultUrl: defaultUrl,
          shinyUrl: shinyUrl,
          femaleUrl: femaleUrl,
          femaleShinyUrl: femaleShinyUrl,
          fallbackUrl: fallbackUrl,
          fallbackUrl2: fallbackUrl2,
        );
      }
    }

    return _homeOrArtwork(
      sprites, rawDefault, rawShiny,
      cosmeticHome: cosmeticHome,
      cosmeticHomeShiny: cosmeticHomeShiny,
    );
  }

  /// Version-group compact icon URL for list tile compact display mode.
  /// Replaces `_compactIconUrl()` from `pokemon_list_tile.dart`.
  static String compactIconUrl(int pokemonId, PokedexFilter filter) {
    final registry = PokemonDataRegistry.instance;
    String? vg;
    if (filter.game != null) {
      vg = registry.formatToVersionGroup[filter.game];
    } else if (filter.generation != null) {
      vg = registry.genToLastVg[filter.generation];
    }
    final subpath = vg != null ? registry.vgToSubpath[vg] : null;
    if (subpath == null) return '$_spritesBase$pokemonId.png';
    return '$_spritesBase$subpath/$pokemonId.png';
  }

  /// Single URL for Pokédex grid/list display.
  /// Replaces `_buildImageUrl()` from both `PokemonGridCard` and `PokemonListTile`.
  ///
  /// [imageType] is nullable: null means compact list mode (gen-8 icon).
  /// [filter] must be non-null when [imageType] is [PokedexImageType.sprite].
  static String resolvePokedexImageUrl({
    required int pokemonId,
    required String baseSpecies,
    required String? selectedFormName,
    required PokedexImageType? imageType,
    required PokemonEntry? formEntry,
    required PokemonFormEntry? cosmeticEntry,
    required PokedexFilter? filter,
    SpriteUrlsFull? spriteUrls,
  }) {
    final registry = PokemonDataRegistry.instance;

    if (selectedFormName != null) {
      if (cosmeticEntry != null) {
        if (imageType == PokedexImageType.artwork) {
          final override =
              registry.cosmeticFormHomeUrlOverrides[cosmeticEntry.name];
          if (override != null) return override;
          // Female HOME artwork lives at home/female/{id}.png — not {id}-female.png.
          if (cosmeticEntry.formName == 'female') {
            return pokemonHomeFemaleUrl(pokemonId);
          }
          if (cosmeticEntry.name.startsWith('$baseSpecies-')) {
            final suffix =
                cosmeticEntry.name.substring(baseSpecies.length + 1);
            return cosmeticFormHomeUrl(pokemonId, suffix);
          }
        }
        if (cosmeticEntry.formName == 'female') {
          return '${_spritesBase}female/$pokemonId.png';
        }
        return cosmeticEntry.spriteUrl ?? '$_spritesBase$pokemonId.png';
      }

      if (formEntry != null) {
        if (imageType == PokedexImageType.artwork) {
          final homeOverride =
              registry.cosmeticFormHomeUrlOverrides[selectedFormName];
          return homeOverride ??
              formEntry.officialArtworkUrl ??
              '${_spritesBase}other/official-artwork/$pokemonId.png';
        }
        if (imageType == PokedexImageType.sprite) {
          return (formEntry.sprites?['front_default'] as String?) ??
              '$_spritesBase$pokemonId.png';
        }
        // compact (null imageType)
        return '${_spritesBase}versions/generation-viii/icons/${formEntry.id}.png';
      }
    }

    assert(
      imageType != PokedexImageType.sprite || filter != null,
      'filter must be non-null when imageType is PokedexImageType.sprite',
    );
    final baseHomeOverride = PokemonDataRegistry.instance
        .baseFormCosmeticHomeUrls[baseSpecies];
    return switch (imageType) {
      PokedexImageType.artwork =>
        baseHomeOverride?.homeUrl ??
        '${_spritesBase}other/official-artwork/$pokemonId.png',
      // sprite: filter-aware icon. When no gen/game filter is active,
      // compactIconUrl returns the plain front sprite — use spriteUrls.icon
      // (gen-8 icon) as a better compact representation when available.
      PokedexImageType.sprite => (() {
        final genIcon = compactIconUrl(pokemonId, filter!);
        // compactIconUrl falls back to plain sprite when there's no subpath;
        // prefer the gen-aware icon from the backend in that case.
        if (!genIcon.contains('/versions/') && spriteUrls?.icon != null) {
          return spriteUrls!.icon!;
        }
        return genIcon;
      })(),
      null => spriteUrls?.icon ??
          '${_spritesBase}versions/generation-viii/icons/$pokemonId.png',
    };
  }

  /// Fallback URL used when the primary image URL fails to load.
  static String resolvePokedexFallbackUrl({
    required int pokemonId,
    required PokedexImageType? imageType,
    required String? selectedFormName,
    required PokemonEntry? formEntry,
    required PokemonFormEntry? cosmeticEntry,
  }) {
    if (selectedFormName != null) {
      final formSprite = cosmeticEntry?.spriteUrl ??
          (formEntry?.sprites?['front_default'] as String?);
      if (formSprite != null) return formSprite;
    }
    return '$_spritesBase$pokemonId.png';
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _versionedDefaultUrl(
    String versionPath,
    String animSeg,
    String transparent,
    String stem,
    String ext,
  ) =>
      '$_versionsBase/$versionPath/$animSeg$transparent$stem$ext';

  static ({
    String? defaultUrl,
    String? shinyUrl,
    String? femaleUrl,
    String? femaleShinyUrl,
    String? fallbackUrl,
    String? fallbackUrl2,
  }) _homeOrArtwork(
    Map<String, dynamic>? sprites,
    String rawDefault,
    String rawShiny, {
    String? cosmeticHome,
    String? cosmeticHomeShiny,
  }) {
    final home =
        sprites == null ? null : _nav(sprites['other'], ['home']);
    final artwork =
        sprites == null ? null : _nav(sprites['other'], ['official-artwork']);
    return (
      defaultUrl: cosmeticHome ??
          home?['front_default'] as String? ??
          artwork?['front_default'] as String? ??
          rawDefault,
      shinyUrl: cosmeticHomeShiny ??
          home?['front_shiny'] as String? ??
          artwork?['front_shiny'] as String? ??
          rawShiny,
      femaleUrl: home?['front_female'] as String?,
      femaleShinyUrl: home?['front_shiny_female'] as String?,
      fallbackUrl: null,
      fallbackUrl2: null,
    );
  }

  static String _versionedShinyUrl(
    String versionPath,
    int gen,
    String animSeg,
    String transparent,
    String stem,
    String ext,
    String pokemonName,
  ) {
    if (gen == 1) {
      return _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
    }
    if (animSeg.isNotEmpty) {
      return '$_versionsBase/$versionPath/${animSeg}shiny/$stem$ext';
    }
    if (transparent.isNotEmpty) {
      // No transparent/shiny subfolder in Gen 2. Use Pokémon Showdown on native;
      // fall back to non-transparent PokeAPI shiny on web (CORS restriction).
      return kIsWeb
          ? '$_versionsBase/$versionPath/shiny/$stem$ext'
          : 'https://play.pokemonshowdown.com/sprites/gen2-shiny/$pokemonName.png';
    }
    return '$_versionsBase/$versionPath/shiny/$stem$ext';
  }

  static (String? femaleUrl, String? femaleShinyUrl) _versionedFemaleUrls(
    String versionPath,
    int gen,
    String animSeg,
    String stem,
    String ext,
  ) {
    if (gen < 4) return (null, null);
    return (
      '$_versionsBase/$versionPath/${animSeg}female/$stem$ext',
      '$_versionsBase/$versionPath/${animSeg}shiny/female/$stem$ext',
    );
  }

  static Map<String, dynamic>? _nav(dynamic root, List<String> path) {
    dynamic cur = root;
    for (final key in path) {
      if (cur is! Map) return null;
      cur = cur[key];
    }
    return cur is Map ? cur.cast<String, dynamic>() : null;
  }
}
