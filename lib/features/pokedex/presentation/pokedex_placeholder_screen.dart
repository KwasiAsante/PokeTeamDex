import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_list_tile.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';

class PokedexPlaceholderScreen extends ConsumerStatefulWidget {
  const PokedexPlaceholderScreen({super.key});

  @override
  ConsumerState<PokedexPlaceholderScreen> createState() => _PokedexPlaceholderScreenState();
}

class _PokedexPlaceholderScreenState extends ConsumerState<PokedexPlaceholderScreen> {
    late TextEditingController searchController;

    @override
    void initState() {
      super.initState();
      searchController = TextEditingController();
    }

    @override
    void dispose() {
      searchController.dispose();
      super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PokemonListEntry>> pokemonList = ref.watch(filteredPokemonListProvider);
    return pokemonList.when(
      data: (data) => Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16), 
          child: Column(children: [
            SearchBar(
              controller: searchController,
              hintText: 'Search for a pokemon',
              onChanged: (value) => ref.read(pokemonSearchProvider.notifier).state = value,
              trailing: [
                IconButton(
                  onPressed: () { 
                    if (searchController.value.text.isNotEmpty) {
                      searchController.clear();
                      ref.read(pokemonSearchProvider.notifier).state = '';
                    }
                  },
                  icon: Icon(Icons.clear)
                )
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) => PokemonListTile(pokemon: data[index]),
              ),
            ),
          ]), 
        ),
      ),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}