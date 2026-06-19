import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_cache.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart' show MoveSummary;

class PokeApiRepository {
  PokeApiRepository(this._pokeApiClient, this._pokeApiCache);
  final PokeApiClient _pokeApiClient;
  final PokeApiCache _pokeApiCache;

  /// In-memory cache of parsed [PokemonEntry] objects, layered on top of
  /// [_pokeApiCache]'s raw-JSON Hive cache. `PokemonEntry.fromJson` walks
  /// every nested list (a movepool can run 100-200 entries) — that's
  /// synchronous CPU work on the calling isolate. Both the Pokédex list
  /// (`pokemonDetailProvider` per visible tile) and team/slot screens
  /// (`pokemonDetailProvider`/`pokemonByNameProvider` per slot card, for the
  /// base species plus any active mega/form/G-Max) re-request the same
  /// species repeatedly as `.autoDispose` providers are torn down and rebuilt
  /// on scroll/navigation — re-parsing the cached JSON every time. Memoizing
  /// the parsed object skips that re-parse on every repeat lookup.
  final Map<int, PokemonEntry> _pokemonById = {};
  final Map<String, PokemonEntry> _pokemonByName = {};

  /// Same memoization as [_pokemonById] for the other detail-screen fetches —
  /// `fetchPokemonSpecies`/`fetchAbility`/`fetchEvolutionChain`/
  /// `fetchPokemonForm` had no in-memory layer, so every `.autoDispose`
  /// provider rebuild (and every internal helper that calls them, e.g.
  /// `fetchForwardEvolutionInfo` + `fetchBackwardEvolutionInfo` both fetching
  /// the same species/chain back to back) re-ran `fromJson` on the cached
  /// Hive payload from scratch.
  final Map<int, PokemonSpeciesEntry> _speciesById = {};
  final Map<String, AbilityEntry> _abilityByName = {};
  final Map<int, EvolutionNode> _evolutionChainById = {};
  final Map<String, PokemonFormEntry> _formByName = {};

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
    final memoized = _pokemonById[id];
    if (memoized != null) return memoized;
    try {
      final cache = _pokeApiCache.getIfValid('pokemon_detail_$id');
      if (cache is Map<String, dynamic>) {
        final entry = PokemonEntry.fromJson(cache);
        _pokemonById[id] = entry;
        return entry;
      } else {
        final response = await _pokeApiClient.client.get('/pokemon/$id');
        if (response.statusCode == 200) {
          final pokemonResponse = Map<String, dynamic>.from(response.data);
          _pokeApiCache.putWithTTL('pokemon_detail_$id', pokemonResponse, const Duration(days: 7));
          final entry = PokemonEntry.fromJson(pokemonResponse);
          _pokemonById[id] = entry;
          return entry;
        } else {
          throw Exception('Failed to fetch pokemon: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch pokemon: $e');
    }
  }

  Future<PokemonEntry> fetchPokemonByName(String name) async {
    final memoized = _pokemonByName[name];
    if (memoized != null) return memoized;
    final cacheKey = 'pokemon_name_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      final entry = PokemonEntry.fromJson(cached);
      _pokemonByName[name] = entry;
      _pokemonById.putIfAbsent(entry.id, () => entry);
      return entry;
    }
    final response = await _pokeApiClient.client.get('/pokemon/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch pokemon $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    final entry = PokemonEntry.fromJson(data);
    _pokemonByName[name] = entry;
    _pokemonById.putIfAbsent(entry.id, () => entry);
    return entry;
  }

  /// Fetches a `pokemon-form` resource — used for cosmetic forms (e.g. Burmy's
  /// cloaks, Shellos' seas, Unown's letters) that exist only as form resources
  /// and have no separate `/pokemon/{name}` entry of their own.
  Future<PokemonFormEntry> fetchPokemonForm(String name) async {
    final memoized = _formByName[name];
    if (memoized != null) return memoized;
    final cacheKey = 'pokemon_form_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      final entry = PokemonFormEntry.fromJson(cached);
      _formByName[name] = entry;
      return entry;
    }
    final response = await _pokeApiClient.client.get('/pokemon-form/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch pokemon form $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    final entry = PokemonFormEntry.fromJson(data);
    _formByName[name] = entry;
    return entry;
  }

  /// Like [fetchPokemonByName] but falls back to the species endpoint when the
  /// direct name lookup fails (e.g. `aegislash` → 404; use species to find the
  /// default variety `aegislash-shield`).
  ///
  /// For Pokémon Showdown imports where the PS form name differs from the
  /// PokéAPI variety name, a second fallback looks up the base species and
  /// searches its variety list:
  ///   • Exact match  — `gastrodon-east` found in Gastrodon's variety list.
  ///   • Prefix match — `calyrex-shadow` matches `calyrex-shadow-rider`.
  Future<PokemonEntry> fetchPokemonByNameOrDefault(String name) async {
    try {
      return await fetchPokemonByName(name);
    } catch (_) {
      // ── Strategy 1: species/{name} → default variety ──────────────────────
      // Handles bare species names like "aegislash" that 404 on /pokemon but
      // have a valid /pokemon-species entry with a default variety.
      final r = await _pokeApiClient.client.get('/pokemon-species/$name');
      if (r.statusCode == 200) {
        final varieties = r.data['varieties'] as List? ?? [];
        final defaultVariety = varieties.firstWhere(
          (v) => v['is_default'] == true,
          orElse: () => varieties.isNotEmpty ? varieties.first : null,
        );
        if (defaultVariety != null) {
          final defaultName =
              (defaultVariety['pokemon'] as Map)['name'] as String;
          return await fetchPokemonByName(defaultName);
        }
      }

      // ── Strategy 2: base-species variety search ────────────────────────────
      // For hyphenated names (PS form names) where the direct /pokemon and
      // /pokemon-species lookups both failed.  Strip the form suffix, look up
      // the owning species, and search its variety list for:
      //   1. An exact name match  (e.g. "gastrodon-east" in Gastrodon varieties)
      //   2. A prefix match       (e.g. "calyrex-shadow" → "calyrex-shadow-rider")
      //
      // Once a variety is found, fetch by the numeric ID embedded in the
      // variety URL.  Some alternate forms (like Gastrodon-East, ID 10015) are
      // not reachable via /pokemon/{name} — only via /pokemon/{id} — so using
      // the URL-embedded ID is more reliable than a second name-based lookup.
      //
      // Intentionally does NOT fall back to the default variety — silently
      // importing the wrong form would be more confusing than a clear error.
      if (name.contains('-')) {
        final baseName = name.split('-').first;
        final r2 =
            await _pokeApiClient.client.get('/pokemon-species/$baseName');
        if (r2.statusCode == 200) {
          final varieties = r2.data['varieties'] as List? ?? [];
          for (final v in varieties) {
            final vName = (v['pokemon'] as Map)['name'] as String;
            // Match:
            //   1. Exact              — "gastrodon-east" == "gastrodon-east"
            //   2. Forward prefix     — "calyrex-shadow" → "calyrex-shadow-rider"
            //   3. Reverse prefix     — "necrozma-dawn-wings" → "necrozma-dawn"
            //      (PS appends extra suffixes that PokéAPI omits; guard with
            //      vName != baseName so base form "necrozma" is never matched)
            if (vName == name ||
                vName.startsWith('$name-') ||
                (name.startsWith('$vName-') && vName != baseName)) {
              // Prefer ID-based fetch: alternate forms may only be accessible
              // via /pokemon/{id}, not /pokemon/{name}.
              final vUrl = (v['pokemon'] as Map)['url'] as String?;
              if (vUrl != null) {
                final seg = Uri.parse(vUrl).pathSegments
                    .where((s) => s.isNotEmpty)
                    .toList();
                final id = int.tryParse(seg.isNotEmpty ? seg.last : '');
                if (id != null) return await fetchPokemon(id);
              }
              return await fetchPokemonByName(vName);
            }
          }
        }
      }

      rethrow;
    }
  }

  Future<PokemonSpeciesEntry> fetchPokemonSpecies(int id) async {
    // Form-variant IDs (> 10000, e.g. 10174 for Galarian Zigzagoon) are not
    // valid species IDs — resolve to the canonical species ID first so the
    // /pokemon-species/ endpoint doesn't 404.
    final speciesId = await _getSpeciesIdForPokemon(id);
    final memoized = _speciesById[speciesId];
    if (memoized != null) return memoized;
    final cacheKey = 'pokemon_species_$speciesId';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      final entry = PokemonSpeciesEntry.fromJson(cached);
      _speciesById[speciesId] = entry;
      return entry;
    }
    final response = await _pokeApiClient.client.get('/pokemon-species/$speciesId');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch species $speciesId: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    final entry = PokemonSpeciesEntry.fromJson(data);
    _speciesById[speciesId] = entry;
    return entry;
  }

  Future<AbilityEntry> fetchAbility(String name) async {
    final memoized = _abilityByName[name];
    if (memoized != null) return memoized;
    final cacheKey = 'ability_$name';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      final entry = AbilityEntry.fromJson(cached);
      _abilityByName[name] = entry;
      return entry;
    }
    final response = await _pokeApiClient.client.get('/ability/$name');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ability $name: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    final entry = AbilityEntry.fromJson(data);
    _abilityByName[name] = entry;
    return entry;
  }

  Future<EvolutionNode> fetchEvolutionChain(int chainId) async {
    final memoized = _evolutionChainById[chainId];
    if (memoized != null) return memoized;
    final cacheKey = 'evolution_chain_$chainId';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is Map<String, dynamic>) {
      final node = EvolutionNode.fromJson(cached['chain'] as Map<String, dynamic>);
      _evolutionChainById[chainId] = node;
      return node;
    }
    final response = await _pokeApiClient.client.get('/evolution-chain/$chainId');
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch evolution chain $chainId: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data);
    _pokeApiCache.putWithTTL(cacheKey, data, const Duration(days: 7));
    final node = EvolutionNode.fromJson(data['chain'] as Map<String, dynamic>);
    _evolutionChainById[chainId] = node;
    return node;
  }

  /// Returns the set of species IDs reachable FORWARD in the evolution chain
  /// from [originPokemonId] (inclusive), plus the resolved species ID for the
  /// origin itself. Used by the evolution-aware instance picker.
  ///
  /// For form-variant pokemonIds (> 10000) a lightweight `/pokemon/{id}` fetch
  /// resolves the national-dex species ID first.
  Future<({Set<int> forwardSpeciesIds, int originSpeciesId})>
      fetchForwardEvolutionInfo(int originPokemonId) async {
    final originSpeciesId = await _getSpeciesIdForPokemon(originPokemonId);
    final species = await fetchPokemonSpecies(originSpeciesId);
    final chainId = species.evolutionChainId;
    if (chainId == null) {
      return (forwardSpeciesIds: {originSpeciesId}, originSpeciesId: originSpeciesId);
    }
    final root = await fetchEvolutionChain(chainId);
    final forward = _collectSubtreeFrom(root, originSpeciesId) ?? {originSpeciesId};
    return (forwardSpeciesIds: forward, originSpeciesId: originSpeciesId);
  }

  /// Returns all species IDs on the ancestor path from the chain root DOWN TO
  /// [originPokemonId] (inclusive). Used by the child-role picker to show only
  /// valid pre-evolution origin slots — e.g. Electivire's ancestors are
  /// {Elekid, Electabuzz, Electivire}, not its (nonexistent) evolutions.
  Future<({Set<int> ancestorSpeciesIds, int originSpeciesId})>
      fetchBackwardEvolutionInfo(int originPokemonId) async {
    final originSpeciesId = await _getSpeciesIdForPokemon(originPokemonId);
    final species = await fetchPokemonSpecies(originSpeciesId);
    final chainId = species.evolutionChainId;
    if (chainId == null) {
      return (ancestorSpeciesIds: {originSpeciesId}, originSpeciesId: originSpeciesId);
    }
    final root = await fetchEvolutionChain(chainId);
    final path = _findPathTo(root, originSpeciesId, []);
    final ancestors = path != null ? path.toSet() : {originSpeciesId};
    return (ancestorSpeciesIds: ancestors, originSpeciesId: originSpeciesId);
  }

  /// Returns true if [speciesId]'s varieties include a form whose name ends
  /// with '-[formName]'. Used to determine whether a forward-evolution species
  /// has a regional counterpart for the origin's form.
  Future<bool> fetchSpeciesHasForm(int speciesId, String formName) async {
    final species = await fetchPokemonSpecies(speciesId);
    return species.varieties.any((v) => v.name.endsWith('-$formName'));
  }

  Future<int> getSpeciesId(int pokemonId) => _getSpeciesIdForPokemon(pokemonId);

  Future<int> _getSpeciesIdForPokemon(int pokemonId) async {
    if (pokemonId <= 10000) return pokemonId;
    final cacheKey = 'species_id_for_pokemon_$pokemonId';
    final cached = _pokeApiCache.getIfValid(cacheKey);
    if (cached is int) return cached;
    final response = await _pokeApiClient.client.get('/pokemon/$pokemonId');
    if (response.statusCode != 200) return pokemonId; // best-effort fallback
    final speciesUrl = (response.data['species'] as Map)['url'] as String;
    final segments = Uri.parse(speciesUrl).pathSegments;
    final speciesId = int.parse(segments.lastWhere((s) => s.isNotEmpty));
    _pokeApiCache.putWithTTL(cacheKey, speciesId, const Duration(days: 7));
    return speciesId;
  }

  /// Returns the path of species IDs from [node] down to [targetSpeciesId]
  /// (inclusive), or null if the target is not in this subtree.
  List<int>? _findPathTo(EvolutionNode node, int targetSpeciesId, List<int> path) {
    final current = [...path, node.speciesId];
    if (node.speciesId == targetSpeciesId) return current;
    for (final child in node.evolvesTo) {
      final result = _findPathTo(child, targetSpeciesId, current);
      if (result != null) return result;
    }
    return null;
  }

  /// Finds [originSpeciesId] in the tree rooted at [node] and returns all
  /// species IDs at that node and every descendant. Returns null if the
  /// species is not in the subtree.
  Set<int>? _collectSubtreeFrom(EvolutionNode node, int originSpeciesId) {
    if (node.speciesId == originSpeciesId) return _collectAll(node);
    for (final child in node.evolvesTo) {
      final result = _collectSubtreeFrom(child, originSpeciesId);
      if (result != null) return result;
    }
    return null;
  }

  Set<int> _collectAll(EvolutionNode node) {
    final ids = <int>{node.speciesId};
    for (final child in node.evolvesTo) {
      ids.addAll(_collectAll(child));
    }
    return ids;
  }

  /// Returns each ancestor Pokémon's display name and moves list, in chain
  /// order (oldest first). Returns an empty list if [pokemonId] has no prior
  /// evolutions (e.g. unevolved or a baby with no pre-baby).
  Future<List<({String speciesName, List<MoveSummary> moves})>>
      fetchPriorEvoMoveSets(int pokemonId) async {
    final speciesId = await _getSpeciesIdForPokemon(pokemonId);
    final species = await fetchPokemonSpecies(speciesId);
    final chainId = species.evolutionChainId;
    if (chainId == null) return [];
    final root = await fetchEvolutionChain(chainId);
    final path = _findPathTo(root, speciesId, []);
    if (path == null || path.length <= 1) return [];
    // All species IDs that precede the current one in the evolution path.
    final ancestorIds = path.sublist(0, path.length - 1);

    // Determine the regional identity of the pokemon being viewed.
    // Variety IDs >= 10000 are regional/alternate forms; the base ID is the default.
    final bool isDefaultForm = pokemonId == speciesId;
    String? currentRegionalSuffix;
    if (!isDefaultForm) {
      final currentPokemon = await fetchPokemon(pokemonId);
      currentRegionalSuffix = _regionalFormSuffix(currentPokemon.name);
    }
    // Regional suffixes that exist in the CURRENT species' non-default varieties.
    // Used to decide whether an ancestor's regional variant is relevant.
    final currentSpeciesRegionalSuffixes = species.varieties
        .where((v) => !v.isDefault)
        .map((v) => _regionalFormSuffix(v.name))
        .whereType<String>()
        .toSet();

    final result = <({String speciesName, List<MoveSummary> moves})>[];
    for (final ancestorId in ancestorIds) {
      // For regional forms, skip the default ancestor — only the matching
      // regional variety is relevant (Alolan Ninetales → Alolan Vulpix only,
      // not Kantonian Vulpix).
      if (isDefaultForm) {
        final pokemon = await fetchPokemon(ancestorId);
        result.add((speciesName: pokemon.name, moves: pokemon.moves));
      }
      // Also include non-default regional forms so that breeding moves exclusive
      // to those forms surface as prior-evo moves (e.g. Galarian Zigzagoon egg
      // moves for Obstagoon). Apply regional filtering so Alolan Vulpix does not
      // appear when viewing Kantonian Ninetales, and Kantonian Vulpix does not
      // appear when viewing Alolan Ninetales.
      final ancestorSpecies = await fetchPokemonSpecies(ancestorId);
      for (final variety in ancestorSpecies.varieties) {
        if (variety.isDefault) continue;
        final varSuffix = _regionalFormSuffix(variety.name);
        if (varSuffix != null) {
          if (isDefaultForm) {
            // Default form: skip ancestor regional variants whose region IS
            // represented by a non-default variety of the current species
            // (Ninetales has -alola → skip vulpix-alola). Keep regional ancestors
            // whose region has NO counterpart in the current species (Obstagoon
            // has no other forms → keep zigzagoon-galar).
            if (currentSpeciesRegionalSuffixes.contains(varSuffix)) continue;
          } else {
            // Regional form: only include ancestors from the same region.
            if (varSuffix != currentRegionalSuffix) continue;
          }
        }
        try {
          final formPokemon = await fetchPokemonByNameOrDefault(variety.name);
          result.add((speciesName: variety.name, moves: formPokemon.moves));
        } catch (_) {
          // Best-effort: skip if the form has no dedicated /pokemon resource.
        }
      }
    }
    return result;
  }

  static String? _regionalFormSuffix(String name) {
    const suffixes = ['-alola', '-galar', '-hisui', '-paldea'];
    for (final s in suffixes) {
      if (name.endsWith(s)) return s;
    }
    return null;
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
