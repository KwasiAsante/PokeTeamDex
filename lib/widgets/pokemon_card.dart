import 'package:flutter/material.dart';
import 'package:poke_team_dex/providers/team_provider.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';

class PokemonCard extends StatelessWidget {
  final Pokemon pokemon;

  const PokemonCard({super.key, required this.pokemon});

  Color getTypeColor(String type) {
    switch (type) {
      case "fire": return Colors.redAccent;
      case "water": return Colors.blueAccent;
      case "grass": return Colors.greenAccent;
      case "normal": return const Color.fromARGB(255, 224, 223, 223);
      case "bug": return const Color.fromARGB(255, 117, 182, 13);
      case "flying": return const Color.fromARGB(255, 175, 98, 247);
      case "ground": return Colors.brown;
      case "rock": return const Color.fromARGB(255, 92, 75, 69);
      case "steel": return Colors.grey;
      case "electric": return Colors.yellowAccent;
      case "ice": return Colors.cyanAccent;
      case "fighting": return Colors.deepOrangeAccent;
      case "poison": return Colors.deepPurpleAccent;
      case "dark": return const Color.fromARGB(255, 46, 45, 45);
      case "ghost": return Colors.deepPurple;
      case "psychic": return Colors.pink;
      case "fairy": return Colors.pinkAccent;
      case "dragon": return Colors.indigoAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    TeamProvider teamProvider = Provider.of<TeamProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        teamProvider.addToTeam(pokemon);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pokemon.name} added to the team!')));
      },
      child: Container(
        decoration: BoxDecoration(
          color: getTypeColor(pokemon.types.first),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              spreadRadius: 2
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 8),
            Text(
              pokemon.name.toUpperCase(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 8),
            Image.network(
              pokemon.imageUrl,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            )
          ],
        ),
      ),
    );
  }
}
