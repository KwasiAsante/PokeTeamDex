import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_grid_card.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

/// Maps a PokéAPI version-group name → sprite sub-path under [_kBase].
/// null = no game-specific pixel-art folder exists (Gen VI, IX) → use standard.
const _kVgToSubpath = <String, String?>{
  'red-blue':                        'versions/generation-i/red-blue',
  'yellow':                          'versions/generation-i/yellow',
  'gold-silver':                     'versions/generation-ii/gold',
  'crystal':                         'versions/generation-ii/crystal',
  'ruby-sapphire':                   'versions/generation-iii/ruby-sapphire',
  'emerald':                         'versions/generation-iii/emerald',
  'firered-leafgreen':               'versions/generation-iii/firered-leafgreen',
  'diamond-pearl':                   'versions/generation-iv/diamond-pearl',
  'platinum':                        'versions/generation-iv/platinum',
  'heartgold-soulsilver':            'versions/generation-iv/heartgold-soulsilver',
  'black-white':                     'versions/generation-v/black-white',
  'black-2-white-2':                 'versions/generation-v/black-white', // BW2 shares BW sprites
  // Gen VI–IX: 3D games — no pixel-art sprite sheets exist, use standard sprite
  'x-y':                             null,
  'omega-ruby-alpha-sapphire':       null,
  'sun-moon':                        null,
  'ultra-sun-ultra-moon':            null,
  'lets-go-pikachu-lets-go-eevee':   null,
  'sword-shield':                    null,
  'brilliant-diamond-and-shining-pearl': null,
  'legends-arceus':                  null,
  'scarlet-violet':                  null,
};

/// The last released version-group per generation (used when only gen is set).
const _kGenToLastVg = <int, String>{
  1: 'yellow',
  2: 'crystal',
  3: 'emerald',
  4: 'heartgold-soulsilver',
  5: 'black-white',
  6: 'omega-ruby-alpha-sapphire',
  7: 'ultra-sun-ultra-moon',
  8: 'sword-shield',
  9: 'scarlet-violet',
};

/// Returns the generation/game-aware sprite URL for [pokemonId].
/// Falls back to the standard front-default sprite when no specific path exists.
String _compactIconUrl(int pokemonId, PokedexFilter filter) {
  String? vg;
  if (filter.game != null) {
    vg = kFormatToVersionGroup[filter.game];
  } else if (filter.generation != null) {
    vg = _kGenToLastVg[filter.generation];
  }

  final subpath = vg != null ? _kVgToSubpath[vg] : null;
  if (subpath == null) {
    // Gen VI / IX have no pixel-art folder — standard front-default
    return '$_kBase$pokemonId.png';
  }
  return '$_kBase$subpath/$pokemonId.png';
}

/// List-mode tile for the Pokédex.
///
/// [imageType] controls which image is shown:
/// - null (compact < 600dp) → Gen VIII icon sprite (small, icon-style)
/// - [PokedexImageType.sprite] (medium 600–840dp) → front-default sprite
/// - [PokedexImageType.artwork] (expanded >840dp) → HOME / official artwork
///
/// All widths get a type-gradient background that animates in as the
/// type loads from [pokemonDetailProvider].
class PokemonListTile extends ConsumerWidget {
  final PokemonListEntry pokemon;

  /// Which image tier to use. Null = compact (icon sprite).
  final PokedexImageType? imageType;

  const PokemonListTile({
    super.key,
    required this.pokemon,
    this.imageType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(pokedexFilterProvider);

    // Lazy type fetch — instant from cache after first detail view
    final detailAsync = ref.watch(pokemonDetailProvider(pokemon.id));
    final primaryType = detailAsync.whenOrNull(
      data: (p) => p.types[1] ?? p.types.values.firstOrNull,
    );
    final types = detailAsync.whenOrNull(
      data: (p) => p.types.values.toList(),
    ) ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerLow;

    // Image URL and size per tier
    final imageUrl = switch (imageType) {
      PokedexImageType.artwork =>
        '${_kBase}other/official-artwork/${pokemon.id}.png',
      PokedexImageType.sprite =>
        _compactIconUrl(pokemon.id, filter),
      null =>
        '${_kBase}versions/generation-viii/icons/${pokemon.id}.png',
    };
    final fallbackUrl = '$_kBase${pokemon.id}.png';

    final imageSize = switch (imageType) {
      PokedexImageType.artwork => 180.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 60.0,
    };
    final imageHeight = switch (imageType) {
      PokedexImageType.artwork => 180.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 50.0, // icon aspect ratio
    };

    final displayName = detailAsync.asData?.value.displaySpeciesName ??
        pokemon.name
            .split('-')
            .map((w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/pokedex/${pokemon.id}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  typeColor.withValues(alpha: 0.35),
                  typeColor.withValues(alpha: 0.06),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // ── Image ──
                Hero(
                  tag: 'pokemon-sprite-${pokemon.id}',
                  child: SizedBox(
                    width: imageSize,
                    height: imageHeight,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => imageType == null
                          ? CachedNetworkImage(
                              imageUrl: fallbackUrl,
                              width: imageSize,
                              height: imageSize,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => Icon(
                                Icons.catching_pokemon,
                                size: imageSize,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                            )
                          : Icon(
                              Icons.catching_pokemon,
                              size: imageSize,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Info ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${pokemon.displayId()}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        displayName,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (types.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: types
                                .map((t) => TypeBadge(type: t))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                FavoriteButton(pokemonId: pokemon.id, iconSize: 20),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
