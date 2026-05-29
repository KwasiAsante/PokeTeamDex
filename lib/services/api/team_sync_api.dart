import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';

final teamSyncApiProvider = Provider<TeamSyncApi>((ref) {
  return TeamSyncApi(ref.read(apiClientProvider).dio);
});

class TeamSyncApi {
  TeamSyncApi(this._dio);
  final Dio _dio;

  // ── Folders ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createFolder(String name) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/folders',
      data: {'name': name},
    );
    return res.data!;
  }

  Future<void> updateFolder(String remoteId, String name) async {
    await _dio.patch('/folders/$remoteId', data: {'name': name});
  }

  Future<void> deleteFolder(String remoteId) async {
    await _dio.delete('/folders/$remoteId');
  }

  // ── Teams ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTeam(
    String name, {
    String? folderRemoteId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/teams',
      data: {
        'name': name,
        if (folderRemoteId != null) 'folder_id': int.parse(folderRemoteId),
      },
    );
    return res.data!;
  }

  Future<void> updateTeam(String remoteId, String name) async {
    await _dio.patch('/teams/$remoteId', data: {'name': name});
  }

  Future<void> deleteTeam(String remoteId) async {
    await _dio.delete('/teams/$remoteId');
  }

  // ── Slots ────────────────────────────────────────────────────────────────────

  Future<void> upsertSlot(
    String teamRemoteId,
    int slot,
    int pokemonId, {
    String? nickname,
  }) async {
    await _dio.put(
      '/teams/$teamRemoteId/slots/$slot',
      data: {'slot': slot, 'pokemon_id': pokemonId, 'nickname': nickname},
    );
  }

  Future<void> deleteSlot(String teamRemoteId, int slot) async {
    await _dio.delete('/teams/$teamRemoteId/slots/$slot');
  }
}
