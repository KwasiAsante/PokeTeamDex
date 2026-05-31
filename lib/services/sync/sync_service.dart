import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/meta_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';

const _maxAttempts = 5;
const _metaKeyLastPullAt = 'last_pull_at';

class SyncService {
  SyncService({
    required this.syncQueue,
    required this.folderRepo,
    required this.teamRepo,
    required this.slotRepo,
    required this.metaRepo,
    required this.api,
    required this.db,
    required this.notifier,
  });

  final SyncQueueRepository syncQueue;
  final TeamFolderRepository folderRepo;
  final TeamRepository teamRepo;
  final TeamSlotRepository slotRepo;
  final MetaRepository metaRepo;
  final TeamSyncApi api;
  final AppDatabase db;
  final SyncStateNotifier notifier;

  bool _running = false;

  /// Push pending local ops then pull remote changes.
  /// Safe to call multiple times — only one execution runs at a time.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    notifier.setSyncing();
    try {
      await _drain();
      await _pull();
      notifier.setSuccess();
    } catch (e) {
      notifier.setError(e.toString());
    } finally {
      _running = false;
    }
  }

  // ── Push ────────────────────────────────────────────────────────────────────

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
        if (folder.remoteId == null) return;
        await api.updateFolder(folder.remoteId!, payload['name'] as String);

      case 'team_folder:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return;
        await api.deleteFolder(remoteId);

      // ── Teams ────────────────────────────────────────────────────────────────
      case 'team:create':
        String? folderRemoteId;
        final folderLocalId = payload['folder_local_id'];
        if (folderLocalId != null) {
          final folder = await folderRepo.getById(folderLocalId as int);
          folderRemoteId = folder.remoteId;
          if (folderRemoteId == null) return;
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
        // payload['name'] may be absent if only format_label changed — fall
        // back to the current name from the DB so the API call is always valid.
        final teamName = payload['name'] as String? ?? team.name;
        await api.updateTeam(team.remoteId!, teamName);

      case 'team:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return;
        await api.deleteTeam(remoteId);

      // ── Slots ─────────────────────────────────────────────────────────────────
      case 'team_slot:upsert':
        final teamLocalId = payload['team_local_id'] as int;
        final team = await teamRepo.getById(teamLocalId);
        if (team.remoteId == null) return;
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

  // ── Pull ────────────────────────────────────────────────────────────────────

  Future<void> _pull() async {
    final sinceStr = await metaRepo.get(_metaKeyLastPullAt);
    final since = sinceStr != null ? DateTime.parse(sinceStr) : null;

    // Record start time before the request so we don't miss changes that
    // arrive concurrently during the pull.
    final pullStart = DateTime.now().toUtc();
    final data = await api.pullSince(since);

    await _mergeFolders(data['folders'] as List);
    await _mergeTeams(data['teams'] as List);
    await _mergeSlots(data['slots'] as List);

    await metaRepo.set(_metaKeyLastPullAt, pullStart.toIso8601String());
  }

  Future<void> _mergeFolders(List remote) async {
    for (final rf in remote.cast<Map<String, dynamic>>()) {
      final remoteId = rf['id'].toString();
      final remoteName = rf['name'] as String;
      final remoteUpdatedAt =
          DateTime.parse(rf['updated_at'] as String).toUtc();

      final existing = await folderRepo.getByRemoteId(remoteId);
      if (existing == null) {
        await folderRepo.insert(TeamFoldersCompanion(
          name: Value(remoteName),
          remoteId: Value(remoteId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teamFolders)
              ..where((f) => f.id.equals(existing.id)))
            .write(TeamFoldersCompanion(
          name: Value(remoteName),
          updatedAt: Value(remoteUpdatedAt),
        ));
      }
    }
  }

  Future<void> _mergeTeams(List remote) async {
    for (final rt in remote.cast<Map<String, dynamic>>()) {
      final remoteId = rt['id'].toString();
      final remoteName = rt['name'] as String;
      final remoteUpdatedAt =
          DateTime.parse(rt['updated_at'] as String).toUtc();
      final remoteFolderId = rt['folder_id'];

      // Resolve remote folder_id → local folder
      int? localFolderId;
      if (remoteFolderId != null) {
        final localFolder =
            await folderRepo.getByRemoteId(remoteFolderId.toString());
        localFolderId = localFolder?.id;
      }

      final existing = await teamRepo.getByRemoteId(remoteId);
      if (existing == null) {
        await teamRepo.insert(TeamsCompanion(
          name: Value(remoteName),
          remoteId: Value(remoteId),
          folderId: Value(localFolderId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teams)..where((t) => t.id.equals(existing.id)))
            .write(TeamsCompanion(
          name: Value(remoteName),
          folderId: Value(localFolderId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      }
    }
  }

  Future<void> _mergeSlots(List remote) async {
    for (final rs in remote.cast<Map<String, dynamic>>()) {
      final remoteTeamId = rs['team_id'].toString();
      final slotNumber = rs['slot'] as int;
      final pokemonId = rs['pokemon_id'] as int;
      final nickname = rs['nickname'] as String?;
      final remoteUpdatedAt =
          DateTime.parse(rs['updated_at'] as String).toUtc();

      final localTeam = await teamRepo.getByRemoteId(remoteTeamId);
      if (localTeam == null) continue; // team not yet pulled — skip

      final existing =
          await slotRepo.getByTeamAndSlot(localTeam.id, slotNumber);
      if (existing == null) {
        await slotRepo.insert(TeamSlotsCompanion(
          teamId: Value(localTeam.id),
          slot: Value(slotNumber),
          pokemonId: Value(pokemonId),
          nickname: Value(nickname),
          updatedAt: Value(remoteUpdatedAt),
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teamSlots)
              ..where((s) => s.id.equals(existing.id)))
            .write(TeamSlotsCompanion(
          pokemonId: Value(pokemonId),
          nickname: Value(nickname),
          updatedAt: Value(remoteUpdatedAt),
        ));
      }
    }
  }
}
