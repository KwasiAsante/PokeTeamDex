// ignore_for_file: unnecessary_non_null_assertion

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/meta_repository.dart';
import 'package:poke_team_dex/database/repositories/pokemon_instance_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

const _maxAttempts = 5;
const _metaKeyLastPullAt = 'last_pull_at';

class SyncService {
  SyncService({
    required this.syncQueue,
    required this.folderRepo,
    required this.teamRepo,
    required this.slotRepo,
    required this.instanceRepo,
    required this.metaRepo,
    required this.api,
    required this.db,
    required this.notifier,
  });

  final SyncQueueRepository syncQueue;
  final TeamFolderRepository folderRepo;
  final TeamRepository teamRepo;
  final TeamSlotRepository slotRepo;
  final PokemonInstanceRepository instanceRepo;
  final MetaRepository metaRepo;
  final TeamSyncApi api;
  final AppDatabase db;
  final SyncNotifier notifier;

  bool _running = false;

  /// Push pending local ops then pull remote changes.
  /// Safe to call multiple times — only one execution runs at a time.
  /// No-ops silently when no auth token is present.
  Future<void> run({String? token}) async {
    if (_running) return;
    if (token == null || token.isEmpty) return;
    _running = true;
    notifier.setSyncing();
    AppLogger().i('Sync started');
    bool pushOk = true;
    try {
      pushOk = await _drain();
    } catch (e, st) {
      AppLogger().e('Push phase failed', error: e, stackTrace: st);
      pushOk = false;
    }
    try {
      await _pull();
    } catch (e, st) {
      AppLogger().e('Pull phase failed', error: e, stackTrace: st);
      notifier.setError(e.toString());
      _running = false;
      return;
    }
    if (pushOk) {
      AppLogger().i('Sync complete');
      notifier.setSuccess();
    } else {
      AppLogger().w('Sync complete with push errors — will retry');
      notifier.setError('Some changes failed to sync and will retry automatically.');
    }
    _running = false;
  }

  // ── Push ────────────────────────────────────────────────────────────────────

  // Sentinel returned by _buildOp to mean "discard this op — it can never
  // succeed and should be removed from the queue immediately." Distinct from
  // null which means "skip for now, dependency not yet ready."
  static final _kDiscard = <String, dynamic>{};

  Future<bool> _drain() async {
    final ops = await syncQueue.getPending();
    if (ops.isEmpty) return true;

    for (final op in ops) {
      if (op.attempts >= _maxAttempts) await syncQueue.delete(op.id);
    }
    final activeOps = ops.where((o) => o.attempts < _maxAttempts).toList();
    if (activeOps.isEmpty) return true;

    final creatingFolderIds = <int>{
      for (final op in activeOps)
        if (op.entityType == 'team_folder' && op.operation == 'create')
          op.entityId,
    };
    final creatingTeamIds = <int>{
      for (final op in activeOps)
        if (op.entityType == 'team' && op.operation == 'create') op.entityId,
    };
    final creatingInstanceIds = <int>{
      for (final op in activeOps)
        if (op.entityType == 'pokemon_instance' && op.operation == 'create')
          op.entityId,
    };

    await _healOrphanedOps(activeOps);

    final batchOps = <Map<String, dynamic>>[];
    final includedOps = <PendingSyncOp>[];

    for (final op in activeOps) {
      final entry = await _buildOp(
        op,
        creatingFolderIds,
        creatingTeamIds,
        creatingInstanceIds,
      );
      if (identical(entry, _kDiscard)) {
        // Op is permanently unprocessable — drop it without sending to server.
        await syncQueue.delete(op.id);
      } else if (entry != null) {
        batchOps.add(entry);
        includedOps.add(op);
      }
    }

    if (batchOps.isEmpty) return true;

    AppLogger().d('Push: sending ${batchOps.length} op(s)');
    try {
      final result = await api.pushBatch(batchOps);
      final created = (result['created'] as List).cast<Map<String, dynamic>>();
      AppLogger().i('Push: ${batchOps.length} op(s) sent, ${created.length} entity(ies) created');

      // Same coalescing as the pull-side merges below — stamp every newly
      // created entity's server-assigned remoteId in one transaction so each
      // table fires a single invalidation rather than one per row.
      if (created.isNotEmpty) {
        await db.transaction(() async {
          for (final c in created) {
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
              case 'instance':
                await (db.update(db.pokemonInstances)
                      ..where((i) => i.id.equals(localId)))
                    .write(PokemonInstancesCompanion(remoteId: Value(remoteId)));
            }
          }
        });
      }

      // Same coalescing — clearing the queue one row at a time fires
      // `watchPendingCount`/`watchPending` (the sync monitor screen) once
      // per deleted op instead of once for the whole drained batch.
      if (includedOps.isNotEmpty) {
        await db.transaction(() async {
          for (final op in includedOps) {
            await syncQueue.delete(op.id);
          }
        });
      }
      return true;
    } on DioException catch (e) {
      AppLogger().w('Push failed (DioException) — will retry', error: e);
      for (final op in includedOps) {
        await syncQueue.markAttempted(op.id, op.attempts);
      }
      return false;
    } on StateError catch (e) {
      AppLogger().w('Push: bad op data discarded', error: e);
      if (includedOps.isNotEmpty) {
        await db.transaction(() async {
          for (final op in includedOps) {
            await syncQueue.delete(op.id);
          }
        });
      }
      return true; // bad data discarded — not a transient push failure
    }
  }

  Future<void> _healOrphanedOps(List<PendingSyncOp> ops) async {
    final foldersWithCreate = {
      for (final op in ops)
        if (op.entityType == 'team_folder' && op.operation == 'create') op.entityId,
    };
    final teamsWithCreate = {
      for (final op in ops)
        if (op.entityType == 'team' && op.operation == 'create') op.entityId,
    };

    final now = DateTime.now();
    final healedFolders = <int>{};
    final healedTeams = <int>{};

    for (final op in ops) {
      if (op.entityType == 'team_folder' && op.operation == 'update') {
        if (foldersWithCreate.contains(op.entityId)) continue;
        if (healedFolders.contains(op.entityId)) continue;
        final folder = await folderRepo.getByIdOrNull(op.entityId);
        if (folder == null || folder.remoteId != null) continue;
        await syncQueue.enqueue(PendingSyncOpsCompanion(
          operation: const Value('create'),
          entityType: const Value('team_folder'),
          entityId: Value(op.entityId),
          payload: Value(jsonEncode({'name': folder.name})),
          createdAt: Value(now),
        ));
        healedFolders.add(op.entityId);
      } else if (op.entityType == 'team' && op.operation == 'update') {
        if (teamsWithCreate.contains(op.entityId)) continue;
        if (healedTeams.contains(op.entityId)) continue;
        final team = await teamRepo.getByIdOrNull(op.entityId);
        if (team == null || team.remoteId != null) continue;
        await syncQueue.enqueue(PendingSyncOpsCompanion(
          operation: const Value('create'),
          entityType: const Value('team'),
          entityId: Value(op.entityId),
          payload: Value(jsonEncode({
            'name': team.name,
            'folder_local_id': team.folderId,
            'format_label': team.formatLabel,
            'is_box': team.isBox,
          })),
          createdAt: Value(now),
        ));
        healedTeams.add(op.entityId);
      }
    }
  }

  Future<Map<String, dynamic>?> _buildOp(
    PendingSyncOp op,
    Set<int> creatingFolderIds,
    Set<int> creatingTeamIds,
    Set<int> creatingInstanceIds,
  ) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    switch ('${op.entityType}:${op.operation}') {
      // ── Folders ───────────────────────────────────────────────────────────
      case 'team_folder:create':
        final folder = await folderRepo.getByIdOrNull(op.entityId);
        if (folder == null) return _kDiscard; // deleted before first sync
        return {
          'type': 'folder_create',
          'client_local_id': op.entityId,
          'name': payload['name'] as String,
          // Use current DB sort_order so folders reordered before first sync
          // land at the right position on the server immediately.
          'sort_order': folder.sortOrder,
        };

      case 'team_folder:update':
        final folder = await folderRepo.getByIdOrNull(op.entityId);
        if (folder == null) return _kDiscard; // deleted locally, nothing to update
        if (folder.remoteId == null) return null; // wait for create
        final folderEntry = <String, dynamic>{
          'type': 'folder_update',
          'remote_id': int.parse(folder.remoteId!),
          'name': payload['name'] as String? ?? folder.name,
        };
        if (payload.containsKey('sort_order')) {
          folderEntry['update_sort_order'] = true;
          folderEntry['sort_order'] = payload['sort_order'] as int;
        }
        return folderEntry;

      case 'team_folder:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return _kDiscard; // never reached server
        return {'type': 'folder_delete', 'remote_id': int.parse(remoteId)};

      // ── Teams ─────────────────────────────────────────────────────────────
      case 'team:create':
        final team = await teamRepo.getByIdOrNull(op.entityId);
        if (team == null) return _kDiscard; // deleted before first sync
        final entry = <String, dynamic>{
          'type': 'team_create',
          'client_local_id': op.entityId,
          'name': payload['name'] as String,
          if (payload['format_label'] != null)
            'format_label': payload['format_label'] as String,
          // Use the current DB sort_order so teams reordered before first sync
          // land at the right position on the server immediately.
          'sort_order': team.sortOrder,
          'is_box': payload['is_box'] as bool? ?? false,
        };
        final folderLocalId = payload['folder_local_id'] as int?;
        if (folderLocalId != null) {
          if (creatingFolderIds.contains(folderLocalId)) {
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
        if (team == null) return _kDiscard; // deleted locally, nothing to update
        if (team.remoteId == null) return null; // wait for create (heal handles this)
        final entry = <String, dynamic>{
          'type': 'team_update',
          'remote_id': int.parse(team!.remoteId!),
          'name': payload['name'] as String? ?? team.name,
        };
        if (payload.containsKey('format_label')) {
          entry['update_format_label'] = true;
          entry['format_label'] = payload['format_label'] as String?;
        }
        if (payload.containsKey('sort_order')) {
          entry['update_sort_order'] = true;
          entry['sort_order'] = payload['sort_order'] as int;
        }
        if (payload.containsKey('is_box')) {
          entry['update_is_box'] = true;
          entry['is_box'] = payload['is_box'] as bool;
        }
        if (payload.containsKey('folder_local_id')) {
          entry['update_folder'] = true;
          final folderLocalId = payload['folder_local_id'] as int?;
          if (folderLocalId == null) {
            entry['folder_remote_id'] = null;
          } else if (creatingFolderIds.contains(folderLocalId)) {
            entry['folder_client_local_id'] = folderLocalId;
          } else {
            final folder = await folderRepo.getByIdOrNull(folderLocalId);
            if (folder?.remoteId == null) return null;
            entry['folder_remote_id'] = int.parse(folder!.remoteId!);
          }
        }
        return entry;

      case 'team:delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return _kDiscard; // never reached server
        return {'type': 'team_delete', 'remote_id': int.parse(remoteId)};

      // ── Instances ─────────────────────────────────────────────────────────
      case 'pokemon_instance:create':
        final entry = <String, dynamic>{
          'type': 'instance_create',
          'client_local_id': op.entityId,
          'pokemon_id': payload['pokemon_id'] as int,
          if (payload['nickname_aliases'] != null)
            'nickname_aliases': payload['nickname_aliases'],
          if (payload['inherited_ribbons'] != null)
            'inherited_ribbons': payload['inherited_ribbons'],
        };
        final parentLocalId = payload['parent_instance_client_local_id'] as int?;
        if (parentLocalId != null) {
          if (creatingInstanceIds.contains(parentLocalId)) {
            // Parent also being created in this batch — server resolves it.
            entry['parent_instance_client_local_id'] = parentLocalId;
          } else {
            final parent = await instanceRepo.getById(parentLocalId);
            if (parent?.remoteId == null) return null; // parent not yet synced
            entry['parent_instance_remote_id'] = int.parse(parent!.remoteId!);
          }
        }
        return entry;

      case 'pokemon_instance:update':
        final inst = await instanceRepo.getById(op.entityId);
        if (inst == null) return _kDiscard; // deleted locally
        if (inst.remoteId == null) return null; // wait for create
        return {
          'type': 'instance_update',
          'remote_id': int.parse(inst.remoteId!),
          if (payload['nickname_aliases'] != null)
            'nickname_aliases': payload['nickname_aliases'],
          if (payload['inherited_ribbons'] != null)
            'inherited_ribbons': payload['inherited_ribbons'],
          if (payload['update_parent'] == true) ...{
            'update_parent_instance': true,
            if (payload['parent_instance_remote_id'] != null)
              'parent_instance_remote_id': payload['parent_instance_remote_id'],
          },
        };

      // ── Slots ─────────────────────────────────────────────────────────────
      case 'team_slot:upsert':
        final teamLocalId = payload['team_local_id'] as int;
        final entry = <String, dynamic>{
          'type': 'slot_upsert',
          'slot': payload['slot'] as int,
          'pokemon_id': payload['pokemon_id'] as int,
          if (payload['nickname'] != null) 'nickname': payload['nickname'],
          // Full slot config — pass through whatever the client stored.
          if (payload['form_name'] != null) 'form_name': payload['form_name'],
          if (payload['level'] != null) 'level': payload['level'],
          if (payload['gender'] != null) 'gender': payload['gender'],
          'is_shiny': payload['is_shiny'] ?? false,
          if (payload['friendship'] != null) 'friendship': payload['friendship'],
          if (payload['ability_name'] != null) 'ability_name': payload['ability_name'],
          if (payload['nature_name'] != null) 'nature_name': payload['nature_name'],
          if (payload['held_item_name'] != null) 'held_item_name': payload['held_item_name'],
          if (payload['move1'] != null) 'move1': payload['move1'],
          if (payload['move2'] != null) 'move2': payload['move2'],
          if (payload['move3'] != null) 'move3': payload['move3'],
          if (payload['move4'] != null) 'move4': payload['move4'],
          if (payload['ev_hp'] != null) 'ev_hp': payload['ev_hp'],
          if (payload['ev_atk'] != null) 'ev_atk': payload['ev_atk'],
          if (payload['ev_def'] != null) 'ev_def': payload['ev_def'],
          if (payload['ev_spa'] != null) 'ev_spa': payload['ev_spa'],
          if (payload['ev_spd'] != null) 'ev_spd': payload['ev_spd'],
          if (payload['ev_spe'] != null) 'ev_spe': payload['ev_spe'],
          if (payload['iv_hp'] != null) 'iv_hp': payload['iv_hp'],
          if (payload['iv_atk'] != null) 'iv_atk': payload['iv_atk'],
          if (payload['iv_def'] != null) 'iv_def': payload['iv_def'],
          if (payload['iv_spa'] != null) 'iv_spa': payload['iv_spa'],
          if (payload['iv_spd'] != null) 'iv_spd': payload['iv_spd'],
          if (payload['iv_spe'] != null) 'iv_spe': payload['iv_spe'],
          if (payload['ribbons'] != null) 'ribbons': payload['ribbons'],
          'is_mega_evolved': payload['is_mega_evolved'] ?? false,
          'has_gigantamax': payload['has_gigantamax'] ?? false,
          'gigantamax_enabled': payload['gigantamax_enabled'] ?? false,
          'is_alpha': payload['is_alpha'] ?? false,
          if (payload['tera_type'] != null) 'tera_type': payload['tera_type'],
          if (payload['contest_cool'] != null) 'contest_cool': payload['contest_cool'],
          if (payload['contest_beautiful'] != null) 'contest_beautiful': payload['contest_beautiful'],
          if (payload['contest_cute'] != null) 'contest_cute': payload['contest_cute'],
          if (payload['contest_clever'] != null) 'contest_clever': payload['contest_clever'],
          if (payload['contest_tough'] != null) 'contest_tough': payload['contest_tough'],
          if (payload['contest_sheen'] != null) 'contest_sheen': payload['contest_sheen'],
        };
        if (creatingTeamIds.contains(teamLocalId)) {
          entry['team_client_local_id'] = teamLocalId;
        } else {
          final team = await teamRepo.getByIdOrNull(teamLocalId);
          if (team == null) return _kDiscard; // team deleted
          if (team.remoteId == null) return null; // wait for team create
          entry['team_remote_id'] = int.parse(team.remoteId!);
        }
        // Resolve instance reference if present.
        final instLocalId = payload['instance_client_local_id'] as int?;
        if (instLocalId != null) {
          if (creatingInstanceIds.contains(instLocalId)) {
            entry['instance_client_local_id'] = instLocalId;
          } else {
            final inst = await instanceRepo.getById(instLocalId);
            if (inst?.remoteId != null) {
              entry['instance_remote_id'] = int.parse(inst!.remoteId!);
            } else {
              entry['instance_client_local_id'] = instLocalId;
            }
          }
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
          if (team == null) return _kDiscard; // team deleted
          if (team.remoteId == null) return _kDiscard; // team never synced → slot never on server
          entry['team_remote_id'] = int.parse(team.remoteId!);
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
    AppLogger().d('Pull: since=${since?.toIso8601String() ?? 'full'}');

    final pullStart = DateTime.now().toUtc();
    final data = await api.pullSince(since);

    final folders = data['folders'] as List;
    final teams = data['teams'] as List;
    final instances = data['instances'] as List? ?? [];
    final slots = data['slots'] as List;
    AppLogger().i(
      'Pull: ${folders.length} folder(s), ${teams.length} team(s), '
      '${instances.length} instance(s), ${slots.length} slot(s)',
    );

    // Coalesce all merge writes into a single transaction so Drift emits one
    // table-invalidation notification per watched table at commit time, instead
    // of one per row. With 30+ teams and ~6 slots each, merging row-by-row
    // outside a transaction re-runs every active `.watch()` query (and rebuilds
    // every dependent widget) once per write — a "stream storm" during pull.
    await db.transaction(() async {
      await _mergeFolders(folders);
      await _mergeTeams(teams);
      await _mergeInstances(instances);
      await _mergeSlots(slots);
    });

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
        if (existing != null) {
          await (db.update(db.teams)
                ..where((t) => t.folderId.equals(existing.id)))
              .write(const TeamsCompanion(folderId: Value(null)));
          await folderRepo.delete(existing.id);
        }
        continue;
      }

      final remoteName = rf['name'] as String;
      final remoteSortOrder = rf['sort_order'] as int? ?? 0;
      if (existing == null) {
        await folderRepo.insert(TeamFoldersCompanion(
          name: Value(remoteName),
          sortOrder: Value(remoteSortOrder),
          remoteId: Value(remoteId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teamFolders)
              ..where((f) => f.id.equals(existing.id)))
            .write(TeamFoldersCompanion(
          name: Value(remoteName),
          sortOrder: Value(remoteSortOrder),
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
        if (existing != null) {
          await slotRepo.deleteAllForTeam(existing.id);
          await teamRepo.delete(existing.id);
        }
        continue;
      }

      final remoteName = rt['name'] as String;
      final remoteFormatLabel = rt['format_label'] as String?;
      final remoteSortOrder = rt['sort_order'] as int? ?? 0;
      final remoteIsBox = rt['is_box'] as bool? ?? false;
      final remoteFolderId = rt['folder_id'];

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
          formatLabel: Value(remoteFormatLabel),
          sortOrder: Value(remoteSortOrder),
          isBox: Value(remoteIsBox),
          folderId: Value(localFolderId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teams)..where((t) => t.id.equals(existing.id)))
            .write(TeamsCompanion(
          name: Value(remoteName),
          formatLabel: Value(remoteFormatLabel),
          sortOrder: Value(remoteSortOrder),
          isBox: Value(remoteIsBox),
          folderId: Value(localFolderId),
          updatedAt: Value(remoteUpdatedAt),
        ));
      }
    }
  }

  Future<void> _mergeInstances(List remote) async {
    final rows = remote.cast<Map<String, dynamic>>();

    // Pass 1 — upsert all instances. Parent links are resolved where possible;
    // children that arrive before their parent get parentInstanceId = null for
    // now and are fixed in pass 2.
    for (final ri in rows) {
      final remoteId = ri['id'].toString();
      final remoteDeleted = ri['is_deleted'] as bool? ?? false;
      final remoteUpdatedAt =
          DateTime.parse(ri['updated_at'] as String).toUtc();

      final existing = await instanceRepo.getByRemoteId(remoteId);

      if (remoteDeleted) {
        if (existing != null) await instanceRepo.delete(existing.id);
        continue;
      }

      final pokemonId = ri['pokemon_id'] as int;
      final nicknameAliases = ri['nickname_aliases'] as String?;
      final inheritedRibbons = ri['inherited_ribbons'] as String?;

      int? localParentId;
      final remoteParentId = ri['parent_instance_id'];
      if (remoteParentId != null) {
        final parent =
            await instanceRepo.getByRemoteId(remoteParentId.toString());
        localParentId = parent?.id;
      }

      if (existing == null) {
        await db.into(db.pokemonInstances).insert(
              PokemonInstancesCompanion.insert(
                pokemonId: pokemonId,
                parentInstanceId: Value(localParentId),
                nicknameAliases: Value(nicknameAliases),
                inheritedRibbons: Value(inheritedRibbons),
                remoteId: Value(remoteId),
                updatedAt: Value(remoteUpdatedAt),
              ),
            );
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.pokemonInstances)
              ..where((i) => i.id.equals(existing.id)))
            .write(PokemonInstancesCompanion(
          parentInstanceId: localParentId != null
              ? Value(localParentId)
              : const Value.absent(),
          nicknameAliases: nicknameAliases != null
              ? Value(nicknameAliases)
              : const Value.absent(),
          inheritedRibbons: inheritedRibbons != null
              ? Value(inheritedRibbons)
              : const Value.absent(),
          updatedAt: Value(remoteUpdatedAt),
        ));
      }
    }

    // Pass 2 — fix any parent links that were unresolvable in pass 1 because
    // the parent hadn't been inserted yet. Now that all instances are in the
    // local DB, every remote parent ID should resolve.
    for (final ri in rows) {
      final remoteParentId = ri['parent_instance_id'];
      if (remoteParentId == null) continue;
      if (ri['is_deleted'] as bool? ?? false) continue;

      final remoteId = ri['id'].toString();
      final local = await instanceRepo.getByRemoteId(remoteId);
      if (local == null) continue;

      // Already linked correctly — skip.
      if (local.parentInstanceId != null) continue;

      final parent =
          await instanceRepo.getByRemoteId(remoteParentId.toString());
      if (parent == null) continue;

      await (db.update(db.pokemonInstances)
            ..where((i) => i.id.equals(local.id)))
          .write(PokemonInstancesCompanion(
        parentInstanceId: Value(parent.id),
      ));
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
      if (localTeam == null) continue;

      final existing =
          await slotRepo.getByTeamAndSlot(localTeam.id, slotNumber);

      if (remoteDeleted) {
        if (existing != null) {
          await slotRepo.deleteSlot(localTeam.id, slotNumber);
        }
        continue;
      }

      final pokemonId = rs['pokemon_id'] as int;
      final nickname = rs['nickname'] as String?;

      // Resolve the instance reference from the server.
      int? localInstanceId;
      final remoteInstanceId = rs['instance_id'];
      if (remoteInstanceId != null) {
        final inst =
            await instanceRepo.getByRemoteId(remoteInstanceId.toString());
        localInstanceId = inst?.id;
      }

      final companion = TeamSlotsCompanion(
        pokemonId:        Value(pokemonId),
        nickname:         Value(nickname),
        instanceId:       Value(localInstanceId),
        formName:         Value(rs['form_name'] as String?),
        level:            Value(rs['level'] as int?),
        gender:           Value(rs['gender'] as String?),
        isShiny:          Value(rs['is_shiny'] as bool? ?? false),
        friendship:       Value(rs['friendship'] as int?),
        abilityName:      Value(rs['ability_name'] as String?),
        natureName:       Value(rs['nature_name'] as String?),
        heldItemName:     Value(rs['held_item_name'] as String?),
        move1:            Value(rs['move1'] as String?),
        move2:            Value(rs['move2'] as String?),
        move3:            Value(rs['move3'] as String?),
        move4:            Value(rs['move4'] as String?),
        evHp:             Value(rs['ev_hp'] as int?),
        evAtk:            Value(rs['ev_atk'] as int?),
        evDef:            Value(rs['ev_def'] as int?),
        evSpa:            Value(rs['ev_spa'] as int?),
        evSpd:            Value(rs['ev_spd'] as int?),
        evSpe:            Value(rs['ev_spe'] as int?),
        ivHp:             Value(rs['iv_hp'] as int?),
        ivAtk:            Value(rs['iv_atk'] as int?),
        ivDef:            Value(rs['iv_def'] as int?),
        ivSpa:            Value(rs['iv_spa'] as int?),
        ivSpd:            Value(rs['iv_spd'] as int?),
        ivSpe:            Value(rs['iv_spe'] as int?),
        ribbons:          Value(rs['ribbons'] as String?),
        isMegaEvolved:    Value(rs['is_mega_evolved'] as bool? ?? false),
        hasGigantamax:    Value(rs['has_gigantamax'] as bool? ?? false),
        gigantamaxEnabled: Value(rs['gigantamax_enabled'] as bool? ?? false),
        isAlpha:          Value(rs['is_alpha'] as bool? ?? false),
        teraType:         Value(rs['tera_type'] as String?),
        contestCool:      Value(rs['contest_cool'] as int?),
        contestBeautiful: Value(rs['contest_beautiful'] as int?),
        contestCute:      Value(rs['contest_cute'] as int?),
        contestClever:    Value(rs['contest_clever'] as int?),
        contestTough:     Value(rs['contest_tough'] as int?),
        contestSheen:     Value(rs['contest_sheen'] as int?),
        updatedAt:        Value(remoteUpdatedAt),
      );

      if (existing == null) {
        await slotRepo.insert(TeamSlotsCompanion(
          teamId:           Value(localTeam.id),
          slot:             Value(slotNumber),
          pokemonId:        companion.pokemonId,
          nickname:         companion.nickname,
          instanceId:       companion.instanceId,
          formName:         companion.formName,
          level:            companion.level,
          gender:           companion.gender,
          isShiny:          companion.isShiny,
          friendship:       companion.friendship,
          abilityName:      companion.abilityName,
          natureName:       companion.natureName,
          heldItemName:     companion.heldItemName,
          move1:            companion.move1,
          move2:            companion.move2,
          move3:            companion.move3,
          move4:            companion.move4,
          evHp:             companion.evHp,
          evAtk:            companion.evAtk,
          evDef:            companion.evDef,
          evSpa:            companion.evSpa,
          evSpd:            companion.evSpd,
          evSpe:            companion.evSpe,
          ivHp:             companion.ivHp,
          ivAtk:            companion.ivAtk,
          ivDef:            companion.ivDef,
          ivSpa:            companion.ivSpa,
          ivSpd:            companion.ivSpd,
          ivSpe:            companion.ivSpe,
          ribbons:          companion.ribbons,
          isMegaEvolved:    companion.isMegaEvolved,
          hasGigantamax:    companion.hasGigantamax,
          gigantamaxEnabled: companion.gigantamaxEnabled,
          isAlpha:          companion.isAlpha,
          teraType:         companion.teraType,
          contestCool:      companion.contestCool,
          contestBeautiful: companion.contestBeautiful,
          contestCute:      companion.contestCute,
          contestClever:    companion.contestClever,
          contestTough:     companion.contestTough,
          contestSheen:     companion.contestSheen,
          updatedAt:        companion.updatedAt,
        ));
      } else if (remoteUpdatedAt.isAfter(existing.updatedAt)) {
        await (db.update(db.teamSlots)
              ..where((s) => s.id.equals(existing.id)))
            .write(companion);
      }
    }
  }
}
