import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class PokemonBackendRepository {
  PokemonBackendRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<PokemonResolvedBackendResponse> fetchResolved(int id) async {
    final response = await _apiClient.dio.get<dynamic>('/pokemon/$id/resolved');
    if (response.statusCode != 200) {
      throw Exception('Backend resolved fetch failed for id=$id: ${response.statusCode}');
    }
    return PokemonResolvedBackendResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<MoveSummary>> fetchMoves(int id) async {
    final response = await _apiClient.dio.get<dynamic>('/pokemon/moves/$id');
    if (response.statusCode != 200) {
      throw Exception('Backend moves fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['moves'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<FormBackendData>> fetchForms(int id) async {
    final response = await _apiClient.dio.get<dynamic>('/pokemon/forms/$id');
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
