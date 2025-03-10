import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/pokemon.dart';

class PokeApiService {
  final String baseUrl = 'https://pokeapi.co/api/v2/';

  Future<List<Pokemon>> fetchPokemonList({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/pokemon?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List results = data['results'];

      List<Pokemon> pokemonList = [];
      for (var result in results) {
        final detailResponse = await http.get(Uri.parse(result['url']));
        if (detailResponse.statusCode == 200) {
          final detailData = jsonDecode(detailResponse.body);
          pokemonList.add(Pokemon.fromJson(detailData));
        }
      }
      return pokemonList;
    }
    else {
      throw Exception('Failed to load Pokemon list');
    }
  }
}