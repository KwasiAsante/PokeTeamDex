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
  /// No-ops silently when no auth token is present.
  Future<void> run({String? token}) async {
    if (_running) return;
    // Require a non-empty token — avoids 403 floods when syncs fire before
    // the user has logged in (e.g. immediately after a backend restart).
    if (token == null || token.isEmpty) return;
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
    if (ops.isEmpty) return;

    // Prune ops that have exhausted all retries — they will never succeed and
    // should not accumulate in the queue indefinitely.
    for (final op in ops) {
      if (op.attempts >= _maxAttempts) await syncQueue.delete(op.id);
    }
    final activeOps = ops.where((o) => o.attempts < _maxAttempts).toList();
    if (activeOps.isEmpty) return;

    // Identify entity local IDs being created in this batch so cross-references
    // (e.g. a team whose folder is also being created here) can be resolved by
    // the server using the within-batch map rather than requiring a prior sync.
    final creatingFolderIds = <int>{
      for (final op in activeOps)
        if (op.entityType == 'team_folder' && op.operation == 'create')
          op.entityId,
    };
    final creatingTeamIds = <int>{
      for (final op in activeOps)
        if (op.entityType == 'team' && op.operation == 'create') op.entityId,
    };

    final batchOps = <Map<String, dynamic>>[];
    final includedOps = <PendingSyncOp>[];

    for (final op in activeOps) {
      final entry = await _buildOp(op, creatingFolderIds, creatingTeamIds);
      if (entry != null) {
        batchOps.add(entry);
        includedOps.add(op);
      }
    }

    if (batchOps.isEmpty) return;

    try {
      final result = await api.pushBatch(batchOps);

      // Write back server-assigned IDs for any entities created in this batch.
      for (final c in (result['created'] as List).cast<Map<String, dynamic>>()) {
        final localId = c['client_local_id'] as int;
        final remoteId = (c['remote_id'] as int).toString();
        switch (c['entity_type'] as String) {
          case 'folder':
            await (db.update(db.teamFolders)
                  ..where((f) => f.id.equals(localId)))
                .write(TeamFoldersCompanion(remoteId: Value(remoteId)));
          case 'team':
            await (db.update(db.teams)..where((t) => t.id.equals(localId)))
                .write(TeamsCompanion(remoteId: Value(remoteId)));
        }
      }

      for (final op in includedOps) {
        await syncQueue.delete(op.id);
      }
    } on DioException {
      for (final op in includedOps) {
        await syncQueue.markAttempted(op.id, op.attempts);
      }
    } on StateError {
      // Stale queue entries — drop them so they don't block future syncs.
      for (final op in includedOps) {
        await syncQueue.delete(op.id);
      }
    }
  }

  /// Converts a single queue entry into a batch-op map, resolving cross-entity
  /// references. Returns null if the op should be skipped this cycle.
  Future<Map<String, dynamic>?> _buildOp(
    PendingSyncOp op,
    Set<int> creatingFolderIds,
    Set<int> creatingTeamIds,
  ) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    switch ('${op.entityType}:${op.operation}') {
      // ── Folders ───────────────────────────────────────────────────────────
      case 'team_folder:create':
        return {
          'type': 'folder_create',
          'client_local_id': op.entityId,
          'name': payload['name'] as String,
        };

      case 'team_folder:update':
        final folder = await folderRepo.getByIdOrNull(op.entityId);
        if (folder?.remoteId == null) return null;
        return {
          'type': 'folder_update',
          'remote_id': int.parse(folder!.remoteId!),
          'name': payload['name'] as String,
        };

      case 'team_folder:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return null;
        return {'type': 'folder_delete', 'remote_id': int.parse(remoteId)};

      // ── Teams ─────────────────────────────────────────────────────────────
      case 'team:create':
        final entry = <String, dynamic>{
          'type': 'team_create',
          'client_local_id': op.entityId,
          'name': payload['name'] as String,
        };
        final folderLocalId = payload['folder_local_id'] as int?;
        if (folderLocalId != null) {
          if (creatingFolderIds.contains(folderLocalId)) {
            // Folder also being created in this batch — server resolves it.
            entry['folder_client_local_id'] = folderLocalId;
          } else {
            final folder = await folderRepo.getByIdOrNull(folderLocalId);
            if (folder?.remoteId == null) return null;
            entry['folder_remote_id'] = int.parse(folder!.remoteId!);
          }
        }
        return entry;

      case 'team:update':
        final team = await teamRepo.getByIdOrNull(op.entityId);
        if (team?.remoteId == null) return null;
        return {
          'type': 'team_update',
          'remote_id': int.parse(team!.remoteId!),
          // payload['name'] may be absent when only format_label changed.
          'name': payload['name'] as String? ?? team.name,
        };

      case 'team:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return null;
        return {'type': 'team_delete', 'remote_id': int.parse(remoteId)};

      // ── Slots ─────────────────────────────────────────────────────────────
      case 'team_slot:upsert':
        final teamLocalId = payload['team_local_id'] as int;
        final entry = <String, dynamic>{
          'type': 'slot_upsert',
          'slot': payload['slot'] as int,
          'pokemon_id': payload['pokemon_id'] as int,
          if (payload['nickname'] != null) 'nickname': payload['nickname'],
        };
        if (creatingTeamIds.contains(teamLocalId)) {
          entry['team_client_local_id'] = teamLocalId;
        } else {
          final team = await teamRepo.getByIdOrNull(teamLocalId);
          if (team?.remoteId == null) return null;
          entry['team_remote_id'] = int.parse(team!.remoteId!);
        }
        return entry;

      case 'team_slot:delete':
        final teamLocalId = payload['team_local_id'] as int;
        final entry = <String, dynamic>{
          'type': 'slot_delete',
          'slot': payload['slot'] as int,
        };
        if (creatingTeamIds.contains(teamLocalId)) {
          entry['team_client_local_id'] = teamLocalId;
        } else {
          final team = await teamRepo.getByIdOrNull(teamLocalId);
          if (team?.remoteId == null) return null;
          entry['team_remote_id'] = int.parse(team!.remoteId!);
        }
        return entry;

      default:
        return null;
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
      final remoteDeleted = rf['is_deleted'] as bool? ?? false;
      final remoteUpdatedAt =
          DateTime.parse(rf['updated_at'] as String).toUtc();

      final existing = await folderRepo.getByRemoteId(remoteId);

      if (remoteDeleted) {
        // Soft-deleted on server — hard-delete locally if present.
        if (existing != null) {
          // Move orphaned teams to ungrouped before deleting the folder.
          await (db.update(db.teams)
                ..where((t) => t.folderId.equals(existing.id)))
              .write(const TeamsCompanion(folderId: Value(null)));
          await folderRepo.delete(existing.id);
        }
        continue;
      }

      final remoteName = rf['name'] as String;
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
      final remoteDeleted = rt['is_deleted'] as bool? ?? false;
      final remoteUpdatedAt =
          DateTime.parse(rt['updated_at'] as String).toUtc();

      final existing = await teamRepo.getByRemoteId(remoteId);

      if (remoteDeleted) {
        // Soft-deleted on server — hard-delete locally including all slots.
        if (existing != null) {
          await slotRepo.deleteAllForTeam(existing.id);
          await teamRepo.delete(existing.id);
        }
        continue;
      }

      final remoteName = rt['name'] as String;
      final remoteFolderId = rt['folder_id'];

      // Resolve remote folder_id → local folder
      int? localFolderId;
      if (remoteFolderId != null) {
        final localFolder =
            await folderRepo.getByRemoteId(remoteFolderId.toString());
        localFolderId = localFolder?.id;
      }

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
      final remoteDeleted = rs['is_deleted'] as bool? ?? false;
      final remoteUpdatedAt =
          DateTime.parse(rs['updated_at'] as String).toUtc();

      final localTeam = await teamRepo.getByRemoteId(remoteTeamId);
      if (localTeam == null) continue; // team not yet pulled — skip

      final existing =
          await slotRepo.getByTeamAndSlot(localTeam.id, slotNumber);

      if (remoteDeleted) {
        // Soft-deleted on server — hard-delete locally if present.
        if (existing != null) {
          await slotRepo.deleteSlot(localTeam.id, slotNumber);
        }
        continue;
      }

      final pokemonId = rs['pokemon_id'] as int;
      final nickname = rs['nickname'] as String?;

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
