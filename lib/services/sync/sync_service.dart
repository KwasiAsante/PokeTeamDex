import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';

const _maxAttempts = 5;

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncQueue: ref.read(syncQueueRepositoryProvider),
    folderRepo: ref.read(teamFolderRepositoryProvider),
    teamRepo: ref.read(teamRepositoryProvider),
    api: ref.read(teamSyncApiProvider),
    db: ref.read(appDatabaseProvider),
  );
});

class SyncService {
  SyncService({
    required this.syncQueue,
    required this.folderRepo,
    required this.teamRepo,
    required this.api,
    required this.db,
  });

  final dynamic syncQueue;
  final dynamic folderRepo;
  final dynamic teamRepo;
  final TeamSyncApi api;
  final AppDatabase db;

  bool _running = false;

  /// Drains the pending ops queue. Safe to call multiple times — only one
  /// execution runs at a time.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      await _drain();
    } finally {
      _running = false;
    }
  }

  Future<void> _drain() async {
    final ops = await syncQueue.getPending();
    for (final op in ops) {
      if (op.attempts >= _maxAttempts) continue;
      try {
        await _process(op);
        await syncQueue.delete(op.id);
      } on DioException {
        await syncQueue.markAttempted(op.id, op.attempts);
      }
    }
  }

  Future<void> _process(PendingSyncOp op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    switch ('${op.entityType}:${op.operation}') {
      // ── Folders ─────────────────────────────────────────────────────────────
      case 'team_folder:create':
        final data = await api.createFolder(payload['name'] as String);
        final remoteId = data['id'].toString();
        await (db.update(db.teamFolders)
              ..where((f) => f.id.equals(op.entityId)))
            .write(TeamFoldersCompanion(remoteId: Value(remoteId)));

      case 'team_folder:update':
        final folder = await folderRepo.getById(op.entityId);
        if (folder.remoteId == null) return; // create not synced yet
        await api.updateFolder(folder.remoteId!, payload['name'] as String);

      case 'team_folder:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return; // never synced, nothing to delete remotely
        await api.deleteFolder(remoteId);

      // ── Teams ────────────────────────────────────────────────────────────────
      case 'team:create':
        String? folderRemoteId;
        final folderLocalId = payload['folder_local_id'];
        if (folderLocalId != null) {
          final folder = await folderRepo.getById(folderLocalId as int);
          folderRemoteId = folder.remoteId;
          if (folderRemoteId == null) return; // wait for folder create to sync first
        }
        final data = await api.createTeam(
          payload['name'] as String,
          folderRemoteId: folderRemoteId,
        );
        final remoteId = data['id'].toString();
        await (db.update(db.teams)..where((t) => t.id.equals(op.entityId)))
            .write(TeamsCompanion(remoteId: Value(remoteId)));

      case 'team:update':
        final team = await teamRepo.getById(op.entityId);
        if (team.remoteId == null) return;
        await api.updateTeam(team.remoteId!, payload['name'] as String);

      case 'team:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return;
        await api.deleteTeam(remoteId);

      // ── Slots ─────────────────────────────────────────────────────────────────
      case 'team_slot:upsert':
        final teamLocalId = payload['team_local_id'] as int;
        final team = await teamRepo.getById(teamLocalId);
        if (team.remoteId == null) return; // wait for team create
        await api.upsertSlot(
          team.remoteId!,
          payload['slot'] as int,
          payload['pokemon_id'] as int,
          nickname: payload['nickname'] as String?,
        );

      case 'team_slot:delete':
        final teamLocalId = payload['team_local_id'] as int;
        final team = await teamRepo.getById(teamLocalId);
        if (team.remoteId == null) return;
        await api.deleteSlot(team.remoteId!, payload['slot'] as int);
    }
  }
}
