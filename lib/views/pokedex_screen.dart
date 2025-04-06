import 'package:flutter/material.dart';
import 'package:poke_team_dex/views/team_builder_screen.dart';
import 'package:provider/provider.dart';

import '../providers/pokemon_provider.dart';
import '../widgets/pokemon_card.dart';

class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  _PokedexScreenState createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final pokemonProvider =
        Provider.of<PokemonProvider>(context, listen: false);
    pokemonProvider.loadPokemonList(); // Load initial Pokémon

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        // User scrolled to the bottom, load more Pokémon
        pokemonProvider.loadPokemonList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pokemonProvider = Provider.of<PokemonProvider>(context);

    return Scaffold(
        appBar: AppBar(title: Text('Pokédex')),
        body: pokemonProvider.isLoading && pokemonProvider.pokemonList.isEmpty
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: pokemonProvider.pokemonList.length,
                      itemBuilder: (context, index) {
                        return PokemonCard(
                            pokemon: pokemonProvider.pokemonList[index]);
                      },
                    ),
                  ),
                  if (pokemonProvider
                      .isLoading) // Show loading indicator at bottom
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
        floatingActionButton:
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Refresh Pokémon List Button
              FloatingActionButton(
                onPressed: () => pokemonProvider.loadPokemonList(),
                tooltip: 'Load Pokémon',
                child: Icon(Icons.download),
              ),
              SizedBox(width: 16), // Add spacing between buttons

              // Navigate to Team Builder Button
              FloatingActionButton(
                heroTag: 'team',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TeamBuilderScreen()),
                  );
                },
                tooltip: 'View Team',
                child: Icon(Icons.group),
              ),
            ],
          )
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
