import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
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

  /// Returns move names of a given type using /type/{name}.moves; cached 7 days.
  Future<List<String>> fetchMovesByType(String typeName) async {
    final cacheKey = 'moves_type_$typeName';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) return cached.cast<String>();
    final r = await _pokeApiClient.client.get('/type/$typeName');
    if (r.statusCode != 200) {
      throw Exception('Failed to fetch type $typeName: ${r.statusCode}');
    }
    final names = (r.data['moves'] as List)
        .map((m) => (m as Map)['name'] as String)
        .toList()
      ..sort();
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

  Future<List<String>> fetchItemList() async {
    const cacheKey = 'item_list';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) {
      return cached.cast<String>();
    }
    final response = await _pokeApiClient.client.get('/item', queryParameters: {
      'limit': 10000,
      'offset': 0,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch item list: ${response.statusCode}');
    }
    final names = (response.data['results'] as List)
        .map((e) => e['name'] as String)
        .toList();
    _pokeApiCache.putWithTTL(cacheKey, names, const Duration(days: 7));
    return names;
  }

  Future<ItemEntry> fetchItem(String name) async {
    final cacheKey = 'item_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return ItemEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/item/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch item $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return ItemEntry.fromJson(data);
  }

  Future<TypeEntry> fetchType(String name) async {
    final cacheKey = 'type_detail_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      return TypeEntry.fromJson(cached);
    }
    final response = await _pokeApiClient.client.get('/type/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch type $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return TypeEntry.fromJson(data);
  }

  /// Fetches a machine by its full PokéAPI URL.
  /// Returns {item_name, item_url} for display and linking.
  Future<Map<String, String>> fetchMachineByUrl(String url) async {
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    final cacheKey = 'machine_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map) return Map<String, String>.from(cached.cast<String, String>());

    // Strip the base URL so the Dio client (which has baseUrl set) handles it
    final path = url.contains('api/v2')
        ? url.substring(url.indexOf('api/v2') + 6)  // "/machine/{id}/"
        : '/machine/$id/';
    final r = await _pokeApiClient.client.get(path);
    if (r.statusCode != 200) {
      throw Exception('Failed to fetch machine $id: ${r.statusCode}');
    }
    final itemMap = r.data['item'] as Map<String, dynamic>;
    final result = <String, String>{
      'name': itemMap['name'] as String,
      'url':  itemMap['url'] as String,
    };
    _pokeApiCache.putWithTTL(cacheKey, result, const Duration(days: 7));
    return result;
  }

  /// Fetches a named regional Pokédex and returns {speciesName: entryNumber}.
  /// Used to filter and sort the Pokédex list by a specific game's regional dex.
  Future<Map<String, int>> fetchRegionalPokedex(String name) async {
    final cacheKey = 'regional_pokedex_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map) {
      return Map<String, int>.from(cached.cast<String, int>());
    }
    final response = await _pokeApiClient.client.get('/pokedex/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch pokedex $name: ${response.statusCode}');
    }
    final entries = (response.data['pokemon_entries'] as List).map((e) {
      return MapEntry(
        e['pokemon_species']['name'] as String,
        e['entry_number'] as int,
      );
    }).toList();
    final result = Map<String, int>.fromEntries(entries);
    _pokeApiCache.putWithTTL(cacheKey, result, const Duration(days: 7));
    return result;
  }

  // ── Location / Region ─────────────────────────────────────────────────────

  /// Returns a map of {regionName: [locationName, ...]} for all regions.
  /// Performs one request per region (~10 total); cached 7 days.
  Future<Map<String, List<String>>> fetchAllRegionLocations() async {
    const cacheKey = 'all_region_locations';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map) {
      return {
        for (final e in cached.entries)
          e.key as String: (e.value as List).cast<String>(),
      };
    }

    final regResp = await _pokeApiClient.client
        .get('/region', queryParameters: {'limit': 100, 'offset': 0});
    if (regResp.statusCode != 200) {
      throw Exception('Failed to fetch regions: ${regResp.statusCode}');
    }

    final regionNames = (regResp.data['results'] as List)
        .map((r) => r['name'] as String)
        .toList();

    final result = <String, List<String>>{};
    for (final regionName in regionNames) {
      final r = await _pokeApiClient.client.get('/region/$regionName');
      if (r.statusCode == 200) {
        final locs = (r.data['locations'] as List)
            .map((l) => l['name'] as String)
            .toList()
          ..sort();
        result[regionName] = locs;
      }
    }

    _pokeApiCache.putWithTTL(cacheKey, result, const Duration(days: 7));
    return result;
  }

  /// Fetches a single location — returns its display name, region, and areas.
  Future<Map<String, dynamic>> fetchLocation(String name) async {
    final cacheKey = 'location_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) return cached;
    final r = await _pokeApiClient.client.get('/location/$name');
    if (r.statusCode != 200) {
      throw Exception('Failed to fetch location $name: ${r.statusCode}');
    }
    final data = Map<String, dynamic>.from(r.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return data;
  }

  /// Fetches a location area — returns its pokemon_encounters list.
  Future<Map<String, dynamic>> fetchLocationArea(String name) async {
    final cacheKey = 'location_area_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) return cached;
    final r = await _pokeApiClient.client.get('/location-area/$name');
    if (r.statusCode != 200) {
      throw Exception('Failed to fetch location area $name: ${r.statusCode}');
    }
    final data = Map<String, dynamic>.from(r.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    return data;
  }

  /// Returns ability names introduced in [genName] (e.g. "generation-iii").
  /// Uses /generation/{name} and caches the list for 7 days.
  Future<List<String>> fetchAbilitiesByGeneration(String genName) async {
    final cacheKey = 'abilities_gen_$genName';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) return cached.cast<String>();
    final r = await _pokeApiClient.client.get('/generation/$genName');
    if (r.statusCode != 200) {
      throw Exception('Failed to fetch generation $genName');
    }
    final names = (r.data['abilities'] as List)
        .map((a) => (a as Map)['name'] as String)
        .toList()
      ..sort();
    _pokeApiCache.putWithTTL(cacheKey, names, const Duration(days: 7));
    return names;
  }
  
  /// Fetches a machine by URL and returns the name of the MOVE it teaches.
  /// Returns all item names belonging to an item pocket (e.g. "berries").
  /// Fetches the pocket → its categories → item names; cached 7 days.
  Future<List<String>> fetchItemsByPocket(String pocketName) async {
    final cacheKey = 'item_pocket_$pocketName';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is List) return cached.cast<String>();

    final pocketResp =
        await _pokeApiClient.client.get('/item-pocket/$pocketName');
    if (pocketResp.statusCode != 200) {
      throw Exception('Failed to fetch pocket $pocketName');
    }
    final categoryNames = (pocketResp.data['categories'] as List)
        .map((c) => (c as Map)['name'] as String)
        .toList();

    final allItems = <String>[];
    for (final cat in categoryNames) {
      final catResp =
          await _pokeApiClient.client.get('/item-category/$cat');
      if (catResp.statusCode == 200) {
        final items = (catResp.data['items'] as List)
            .map((i) => (i as Map)['name'] as String)
            .toList();
        allItems.addAll(items);
      }
    }
    allItems.sort();
    _pokeApiCache.putWithTTL(cacheKey, allItems, const Duration(days: 7));
    return allItems;
  }

  Future<String?> fetchMachineMove(String url) async {
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    final cacheKey = 'machine_move_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is String) return cached;
    final path = url.contains('api/v2')
        ? url.substring(url.indexOf('api/v2') + 6)
        : '/machine/$id/';
    final r = await _pokeApiClient.client.get(path);
    if (r.statusCode != 200) return null;
    final moveName =
        (r.data['move'] as Map<String, dynamic>)['name'] as String;
    _pokeApiCache.putWithTTL(cacheKey, moveName, const Duration(days: 7));
    return moveName;
  }

  Future<ContestEffectData> fetchContestEffect(String url) async {
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    final cacheKey = 'contest_effect_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map) {
      return ContestEffectData.fromJson(cached.cast<String, dynamic>());
    }
    final path = url.contains('api/v2')
        ? url.substring(url.indexOf('api/v2') + 6)
        : '/contest-effect/$id/';
    final r = await _pokeApiClient.client.get(path);
    if (r.statusCode != 200) throw Exception('Failed to fetch contest effect $id');
    final data = r.data as Map<String, dynamic>;
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 30));
    return ContestEffectData.fromJson(data);
  }

  Future<SuperContestEffectData> fetchSuperContestEffect(String url) async {
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    final cacheKey = 'super_contest_effect_$id';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map) {
      return SuperContestEffectData.fromJson(cached.cast<String, dynamic>());
    }
    final path = url.contains('api/v2')
        ? url.substring(url.indexOf('api/v2') + 6)
        : '/super-contest-effect/$id/';
    final r = await _pokeApiClient.client.get(path);
    if (r.statusCode != 200) throw Exception('Failed to fetch super contest effect $id');
    final data = r.data as Map<String, dynamic>;
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 30));
    return SuperContestEffectData.fromJson(data);
  }

  List<PokemonListEntry> _parseList(Map<String, dynamic> raw) {
    final results = raw['results'] as List;
    return results
        .map((e) => PokemonListEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
