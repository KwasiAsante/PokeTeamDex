import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pokemon_provider.dart';
import '../widgets/pokemon_card.dart';

class PokedexScreen extends StatelessWidget {
  const PokedexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pokemonProvider = Provider.of<PokemonProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Pokédex')),
      body: pokemonProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: pokemonProvider.pokemonList.length,
            itemBuilder: (context, index) {
              return PokemonCard(pokemon: pokemonProvider.pokemonList[index]);
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pokemonProvider.loadPokemonList(),
        child: Icon(Icons.download),
      ),
    );
  }
}