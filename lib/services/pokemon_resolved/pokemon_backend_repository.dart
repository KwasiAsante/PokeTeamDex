import 'package:poke_team_dex/services/api/api_client.dart';
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
}
