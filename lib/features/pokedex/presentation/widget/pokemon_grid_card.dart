import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

/// Which sprite tier to show in the grid card.
enum PokedexImageType {
  /// HOME / official artwork — best for large (>840dp) grids.
  artwork,
  /// Front-default sprite — good for medium (600–840dp) grids.
  sprite,
}

/// Grid card shown on medium and expanded breakpoints.
/// Fetches type data lazily via [pokemonDetailProvider] to colour the
/// gradient background; shows a neutral placeholder while loading.
class PokemonGridCard extends ConsumerWidget {
  final PokemonListEntry pokemon;
  final PokedexImageType imageType;

  const PokemonGridCard({
    super.key,
    required this.pokemon,
    required this.imageType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(pokemonDetailProvider(pokemon.id));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Derive primary type and types list once detail loads
    final primaryType = detailAsync.whenOrNull(
      data: (p) => p.types[1] ?? p.types.values.firstOrNull,
    );
    final types = detailAsync.whenOrNull(
      data: (p) => p.types.values.toList(),
    ) ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerHighest;

    // Construct image URL from ID — no extra API call needed
    final imageUrl = switch (imageType) {
      PokedexImageType.artwork =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/other/official-artwork/${pokemon.id}.png',
      PokedexImageType.sprite =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${pokemon.id}.png',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pokedex/${pokemon.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient image area ──
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      typeColor.withValues(alpha: 0.35),
                      typeColor.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Hero(
                  tag: 'pokemon-sprite-${pokemon.id}',
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: Icon(Icons.catching_pokemon,
                          size: 48, color: Colors.white30),
                    ),
                    errorWidget: (_, _, _) => const Center(
                      child: Icon(Icons.catching_pokemon,
                          size: 48, color: Colors.white30),
                    ),
                  ),
                ),
              ),
            ),

            // ── Info strip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${pokemon.displayId()}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    detailAsync.asData?.value.displaySpeciesName ??
                        pokemon.name
                            .split('-')
                            .map((w) => w.isEmpty
                                ? ''
                                : '${w[0].toUpperCase()}${w.substring(1)}')
                            .join(' '),
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (types.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: types.map((t) => TypeBadge(type: t)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
