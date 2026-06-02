import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/database_providers.dart';

/// Streams the full set of favorited Pokémon IDs.
final favoritesSetProvider = StreamProvider<Set<int>>((ref) {
  return ref.watch(favoritesRepositoryProvider).watchAll();
});

/// Streams whether a specific Pokémon is favorited.
final isFavoriteProvider =
    StreamProvider.autoDispose.family<bool, int>((ref, pokemonId) {
  return ref.watch(favoritesRepositoryProvider).watchIsFavorite(pokemonId);
});

/// A star icon button that toggles a Pokémon's favorite status.
/// Subscribes to [isFavoriteProvider] so it rebuilds when favorites change.
class FavoriteButton extends ConsumerWidget {
  final int pokemonId;
  final double? iconSize;

  const FavoriteButton({super.key, required this.pokemonId, this.iconSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav =
        ref.watch(isFavoriteProvider(pokemonId)).asData?.value ?? false;

    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      iconSize: iconSize,
      icon: Icon(
        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isFav ? Colors.amber : null,
      ),
      onPressed: () =>
          ref.read(favoritesRepositoryProvider).toggle(pokemonId),
    );
  }
}
