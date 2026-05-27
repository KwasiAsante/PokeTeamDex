import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';

class PokemonListTile extends StatelessWidget {
  final PokemonListEntry pokemon;
  const PokemonListTile({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(width: 48, height: 48, child: CachedNetworkImage(
        fit: BoxFit.contain,
        imageUrl: pokemon.imageUrl,
          placeholder: (context, url) => const Icon(Icons.catching_pokemon),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
      title: Text(pokemon.displayName),
      onTap: () => context.push('/pokedex/${pokemon.id}'),
    );
  }
}