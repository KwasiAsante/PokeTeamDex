import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

class PokemonDetailPlaceholderScreen extends ConsumerWidget {
  final GoRouterState goRouterState;

  const PokemonDetailPlaceholderScreen({
    super.key,
    required this.goRouterState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String pokemonID = goRouterState.pathParameters['id'] ?? '';
    final AsyncValue<PokemonEntry> pokemon = ref.watch(
      pokemonDetailProvider(int.parse(pokemonID)),
    );
    return pokemon.when(
      data: (data) {
        final url = data.getImageUrl();
        return Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
          body: Column(
            children: [
              SizedBox(
                width: 350,
                height: 350,
                child: url != null
                    ? CachedNetworkImage(
                        fit: BoxFit.contain,
                        imageUrl: url,
                        placeholder: (context, url) =>
                            const Icon(Icons.catching_pokemon),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : Icon(Icons.catching_pokemon),
              ),
              Text(data.name.toCapitalCase()),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5.0,
                children: [
                  ...data.types.map((type) => TypeBadge(type: type)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5.0,
                children: [
                  Text(data.displayHeight()),
                  Text(data.displayWeight()),
                ],
              ),
            ],
          ),
        );
      },
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: Text(error.toString())),
      ),
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
