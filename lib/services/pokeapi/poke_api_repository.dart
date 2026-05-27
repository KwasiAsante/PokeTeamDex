import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_cache.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_client.dart';

class PokeApiRepository {
  PokeApiRepository(this._pokeApiClient, this._pokeApiCache);
  final PokeApiClient _pokeApiClient;
  final PokeApiCache _pokeApiCache;

  Future<List<PokemonListEntry>> fetchPokemonList({bool include = false}) async {
    try {
      final cache = _pokeApiCache.getIfValid('pokemon_list');
      if (cache is Map<String, dynamic>) {
        if (include && (!cache.containsKey('sprites') || !cache.containsKey('types'))) {
          for (dynamic result in (cache['results'] as List)) {
              String url = result['url'] as String;
              result = await fetchPokemonDetails(url, result);
            }
        }
        return _parseList(cache);
      } else {
        final response = await _pokeApiClient.client.get('/pokemon', queryParameters: {
          'limit': 10000,
          'offset': 0,
        });
        if (response.statusCode == 200) {
          final pokemonList = Map<String, dynamic>.from(response.data);
          if (include) {
            for (Map<String, dynamic> result in (pokemonList['results'] as List)) {
              String url = result['url'] as String;
              result = await fetchPokemonDetails(url, result);
            }
          }
          _pokeApiCache.putWithTTL('pokemon_list', pokemonList, const Duration(hours: 24));
          return _parseList(pokemonList);
        } else {
          throw Exception('Failed to fetch pokemon list: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch pokemon list: $e');
    }
  }
  
  Future<Map<String, dynamic>> fetchPokemonDetails(String url, Map<String, dynamic> result) async {
    if (url.isNotEmpty) {
      String endpoint = url.split('https://pokeapi.co/api/v2').last;
      final response = await _pokeApiClient.client.get(endpoint);
      if (response.statusCode == 200) {
        final pokemonResponse = Map<String, dynamic>.from(response.data);
        result['types'] = pokemonResponse['types'];
        result['sprites'] = pokemonResponse['sprites'];
      }
    }

    return result;
  }

  Future<PokemonEntry> fetchPokemon(int id) async {
    try {
      final cache = _pokeApiCache.getIfValid('pokemon_detail_$id');
      if (cache is Map<String, dynamic>) {
        return PokemonEntry.fromJson(cache);
      } else {
        final response = await _pokeApiClient.client.get('/pokemon/$id');
        if (response.statusCode == 200) {
          final pokemonResponse = Map<String, dynamic>.from(response.data);
          _pokeApiCache.putWithTTL('pokemon_detail_$id', pokemonResponse, const Duration(days: 7));
          return PokemonEntry.fromJson(pokemonResponse);
        } else {
          throw Exception('Failed to fetch pokemon: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch pokemon: $e');
    }
  }

  List<PokemonListEntry> _parseList(Map<String, dynamic> raw) {
  final results = raw['results'] as List;
  return results
      .map((e) => PokemonListEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}
}