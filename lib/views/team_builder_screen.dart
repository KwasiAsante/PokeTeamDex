import 'package:flutter/material.dart';
import 'package:poke_team_dex/providers/team_provider.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';

class TeamBuilderScreen extends StatelessWidget {
  const TeamBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    TeamProvider teamProvider = Provider.of<TeamProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Your Pokémon Team')),
      body: teamProvider.team.members.isEmpty
          ? Center(child: Text('No Pokémon in your team yet!'))
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: teamProvider.team.members.length,
              itemBuilder: (context, index) {
                Pokemon pokemon = teamProvider.team.members[index];
                return Card(
                  child: ListTile(
                    leading:
                        Image.network(pokemon.imageUrl, width: 50, height: 50),
                    title: Text(pokemon.name.toUpperCase()),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        teamProvider.removeFromTeam(pokemon);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
