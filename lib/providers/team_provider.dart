import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pokemon.dart';
import '../models/team.dart';

class TeamProvider with ChangeNotifier {
  Team _team = Team(members: []);
  static const String _storageKey = "user_team";

  Team get team => _team;

  //Add Pokemon to the team (Max 6 members)
  void addToTeam(Pokemon pokemon) {
    if (_team.members.length < 6) {
      _team.members.add(pokemon);
      saveTeam();
      notifyListeners();
    }
  }

  void removeFromTeam(Pokemon pokemon) {
    _team.members.remove(pokemon);
    saveTeam();
    notifyListeners();
  }

  Future<void> saveTeam() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_storageKey, _team.toJsonString());
  }

  Future<void> loadTeam() async {
    final prefs = await SharedPreferences.getInstance();
    String? teamData = prefs.getString(_storageKey);

    if (teamData != null) {
      _team = Team.fromJsonString(teamData);
      notifyListeners();
    }
  }
}
