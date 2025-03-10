import 'package:flutter/material.dart';
import 'package:poke_team_dex/models/team.dart';
import 'package:poke_team_dex/providers/team_provider.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';

class PokemonCard extends StatelessWidget {
  final Pokemon pokemon;

  const PokemonCard({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    TeamProvider teamProvider =
        Provider.of<TeamProvider>(context, listen: false);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            pokemon.imageUrl,
            height: 100,
            width: 100,
            fit: BoxFit.cover,
          ),
          SizedBox(height: 8),
          Text(
            pokemon.name.toUpperCase(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ElevatedButton(
              onPressed: () {
                teamProvider.addToTeam(pokemon);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${pokemon.name} added to the team!')));
              },
              child: Text('Add to Team'))
        ],
      ),
    );
  }
}
