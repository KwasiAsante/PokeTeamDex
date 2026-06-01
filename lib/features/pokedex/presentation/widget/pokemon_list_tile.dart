import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

/// Compact list tile used in the single-column (< 600dp) Pokédex layout.
/// Leading: Gen VIII icon sprite (small, no background).
/// Title: Dex# – Name.
/// Subtitle: type badges (loaded lazily, shown when available).
class PokemonListTile extends ConsumerWidget {
  final PokemonListEntry pokemon;
  const PokemonListTile({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Lazily fetch types for the badge row — fast from cache after first view
    final detailAsync = ref.watch(pokemonDetailProvider(pokemon.id));
    final types = detailAsync.whenOrNull(
      data: (p) => p.types.values.toList(),
    ) ?? const <String>[];

    // Gen VIII icon sprite — compact (40×30) and transparent
    final iconUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/versions/generation-viii/icons/${pokemon.id}.png';
    final fallbackUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${pokemon.id}.png';

    final displayName = pokemon.name
        .split('-')
        .map((w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 44,
        height: 33,
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => CachedNetworkImage(
            imageUrl: fallbackUrl,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Icon(Icons.catching_pokemon,
                size: 32,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            '#${pokemon.displayId()}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayName,
              style: textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: types.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 4,
                children:
                    types.map((t) => TypeBadge(type: t)).toList(),
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push('/pokedex/${pokemon.id}'),
    );
  }
}
