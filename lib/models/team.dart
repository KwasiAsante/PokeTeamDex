import 'dart:convert';
import 'pokemon.dart';

class Team {
  final List<Pokemon> members;

  Team({required this.members});

  // Convert Team to JSON
  Map<String, dynamic> toJson() {
    return {
      'members': members
          .map((pokemon) => {
                'id': pokemon.id,
                'name': pokemon.name,
                'imageUrl': pokemon.imageUrl,
              })
          .toList(),
    };
  }

  // Convert JSON to Team object
  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      members: (json['members'] as List)
          .map((item) => Pokemon.fromJson(item))
          .toList(),
    );
  }

  // Convert Team object to a JSON string for storage
  String toJsonString() => jsonEncode(toJson());

  // Create Team object from a JSON string
  static Team fromJsonString(String jsonString) {
    return Team.fromJson(jsonDecode(jsonString));
  }
}
