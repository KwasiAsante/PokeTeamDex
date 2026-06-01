import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_grid_card.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

/// List-mode tile for the Pokédex.
///
/// [imageType] controls which image is shown:
/// - null (compact < 600dp) → Gen VIII icon sprite (small, icon-style)
/// - [PokedexImageType.sprite] (medium 600–840dp) → front-default sprite
/// - [PokedexImageType.artwork] (expanded > 840dp) → HOME / official artwork
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
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/other/official-artwork/${pokemon.id}.png',
      PokedexImageType.sprite =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${pokemon.id}.png',
      null =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/versions/generation-viii/icons/${pokemon.id}.png',
    };
    final fallbackUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${pokemon.id}.png';

    final imageSize = switch (imageType) {
      PokedexImageType.artwork => 80.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 40.0,
    };
    final imageHeight = switch (imageType) {
      PokedexImageType.artwork => 80.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 30.0, // icon aspect ratio
    };

    final displayName = pokemon.name
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
                SizedBox(
                  width: imageSize,
                  height: imageHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => imageType == null
                        ? CachedNetworkImage(
                            imageUrl: fallbackUrl,
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
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

                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
