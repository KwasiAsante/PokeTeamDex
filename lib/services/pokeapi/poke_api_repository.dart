import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
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

  Future<PokemonEntry> fetchPokemonByName(String name) async {
    final cacheKey = 'pokemon_name_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return PokemonEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/pokemon/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch pokemon $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return PokemonEntry.fromJson(data);
  }

  Future<PokemonSpeciesEntry> fetchPokemonSpecies(int id) async {
    final cacheKey = 'pokemon_species_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return PokemonSpeciesEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/pokemon-species/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch species $id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return PokemonSpeciesEntry.fromJson(data);
  }

  Future<AbilityEntry> fetchAbility(String name) async {
    final cacheKey = 'ability_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return AbilityEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/ability/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ability $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return AbilityEntry.fromJson(data);
  }

  Future<EvolutionNode> fetchEvolutionChain(int chainId) async {
    final cacheKey = 'evolution_chain_$chainId';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return EvolutionNode.fromJson(cached['chain'] as Map<String, dynamic>);
    }
    final response = await _pokeApiClient.client.get('/evolution-chain/$chainId');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch evolution chain $chainId: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return EvolutionNode.fromJson(data['chain'] as Map<String, dynamic>);
  }

  Future<MoveEntry> fetchMove(String name) async {
    final cacheKey = 'move_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return MoveEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/move/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch move $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return MoveEntry.fromJson(data);
  }

  /// Returns the set of national dex IDs (1–1025) that belong to [typeName].
  /// Cached for 7 days — type membership is static data.
  Future<Set<int>> fetchPokemonIdsByType(String typeName) async {
    final cacheKey = 'type_pokemon_$typeName';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) {
      return Set<int>.from(cached.cast<int>());
    }

    final response = await _pokeApiClient.client.get('/type/$typeName');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch type $typeName: ${response.statusCode}');
    }

    final pokemonList = (response.data['pokemon'] as List)
        .map((e) {
          final url = e['pokemon']['url'] as String;
          final segments = Uri.parse(url).pathSegments;
          final idStr = segments.lastWhere((s) => s.isNotEmpty);
          return int.tryParse(idStr);
        })
        .whereType<int>()
        .where((id) => id >= 1 && id <= 1025)
        .toSet();

    _pokeApiCache.putWithTTL(cacheKey, pokemonList.toList(), const Duration(days: 7));
    return pokemonList;
  }

  Future<List<EncounterEntry>> fetchPokemonEncounters(int id) async {
    final cacheKey = 'pokemon_encounters_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) {
      return cached
          .map((e) => EncounterEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final response = await _pokeApiClient.client.get('/pokemon/$id/encounters');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch encounters for $id: ${response.statusCode}');
    }
    final data = (response.data as List).cast<Map<String, dynamic>>();
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return data.map(EncounterEntry.fromJson).toList();
  }

  Future<List<String>> fetchMoveList() async {
    const cacheKey = 'move_list';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) {
      return cached.cast<String>();
    }
    final response = await _pokeApiClient.client.get('/move', queryParameters: {
      'limit': 10000,
      'offset': 0,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch move list: ${response.statusCode}');
    }
    final names = (response.data['results'] as List)
        .map((e) => e['name'] as String)
        .toList();
    _pokeApiCache.putWithTTL(cacheKey, names, const Duration(days: 7));
    return names;
  }

  Future<List<String>> fetchAbilityList() async {
    const cacheKey = 'ability_list';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) {
      return cached.cast<String>();
    }
    final response = await _pokeApiClient.client.get('/ability', queryParameters: {
      'limit': 10000,
      'offset': 0,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ability list: ${response.statusCode}');
    }
    final names = (response.data['results'] as List)
        .map((e) => e['name'] as String)
        .toList();
    _pokeApiCache.putWithTTL(cacheKey, names, const Duration(days: 7));
    return names;
  }

  List<PokemonListEntry> _parseList(Map<String, dynamic> raw) {
    final results = raw['results'] as List;
    return results
        .map((e) => PokemonListEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
