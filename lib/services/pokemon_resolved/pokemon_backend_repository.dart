import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class PokemonBackendRepository {
  PokemonBackendRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<PokemonResolvedBackendResponse> fetchResolved(int id, {int? gen}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/$id/resolved',
      queryParameters: gen != null ? {'gen': gen} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend resolved fetch failed for id=$id: ${response.statusCode}');
    }
    return PokemonResolvedBackendResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<MoveSummary>> fetchMoves(int id, {int? gen}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/moves/$id',
      queryParameters: gen != null ? {'gen': gen} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend moves fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final movesRaw = data['moves'] as Map<String, dynamic>? ?? {};

    if (gen != null) {
      // Gen-filtered: single key in the dict matching the requested gen.
      final genMoves = movesRaw[gen.toString()] as List<dynamic>? ?? [];
      return genMoves.map((m) => MoveSummary.fromJson(m as Map<String, dynamic>)).toList();
    }

    // All-gens: flatten across every generation, merging learnDetails per move.
    final byName = <String, List<MoveLearnDetail>>{};
    for (final genEntry in movesRaw.values) {
      for (final m in (genEntry as List<dynamic>)) {
        final ms = MoveSummary.fromJson(m as Map<String, dynamic>);
        byName.update(ms.name, (d) => d..addAll(ms.learnDetails),
            ifAbsent: () => List.of(ms.learnDetails));
      }
    }
    return byName.entries
        .map((e) => MoveSummary(name: e.key, learnDetails: e.value))
        .toList();
  }

  Future<List<VarietyBackendData>> fetchVarieties(int id, {int? gen}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/varieties/$id',
      queryParameters: gen != null ? {'gen': gen} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend varieties fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['varieties'] as List<dynamic>)
        .map((v) => VarietyBackendData.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<List<FormBackendData>> fetchForms(int id, {int? gen}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/forms/$id',
      queryParameters: gen != null ? {'gen': gen} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend forms fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['forms'] as List<dynamic>)
        .map((f) => FormBackendData.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<List<FlavorTextEntry>> fetchFlavorText(int id, {String? lang}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/flavor-text/$id',
      queryParameters: lang != null ? {'lang': lang} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend flavor text fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['flavor_text_entries'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaginatedCatalogResponse<BackendMoveEntry>> fetchCatalogMoves({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? damageClass,
    bool? isZMove,
    bool? isMaxMove,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (damageClass != null) qp['damage_class'] = damageClass;
    if (isZMove != null) qp['is_z_move'] = isZMove;
    if (isMaxMove != null) qp['is_max_move'] = isMaxMove;
    final response = await _apiClient.dio.get<dynamic>('/moves', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogMoves failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendMoveEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendMoveEntry> fetchCatalogMove(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/moves/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogMove failed for $idOrName: ${response.statusCode}');
    }
    return BackendMoveEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<PaginatedCatalogResponse<BackendItemEntry>> fetchCatalogItems({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? category,
    bool? isMegaStone,
    bool? isZCrystal,
    bool? isBerry,
    bool? isPlate,
    bool? isMemory,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (category != null) qp['category'] = category;
    if (isMegaStone != null) qp['is_mega_stone'] = isMegaStone;
    if (isZCrystal != null) qp['is_z_crystal'] = isZCrystal;
    if (isBerry != null) qp['is_berry'] = isBerry;
    if (isPlate != null) qp['is_plate'] = isPlate;
    if (isMemory != null) qp['is_memory'] = isMemory;
    final response = await _apiClient.dio.get<dynamic>('/items', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogItems failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendItemEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendItemEntry> fetchCatalogItem(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/items/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogItem failed for $idOrName: ${response.statusCode}');
    }
    return BackendItemEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<PaginatedCatalogResponse<BackendAbilityEntry>> fetchCatalogAbilities({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? pokemon,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (pokemon != null) qp['pokemon'] = pokemon;
    final response =
        await _apiClient.dio.get<dynamic>('/abilities', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogAbilities failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendAbilityEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendAbilityEntry> fetchCatalogAbility(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/abilities/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogAbility failed for $idOrName: ${response.statusCode}');
    }
    return BackendAbilityEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
}
