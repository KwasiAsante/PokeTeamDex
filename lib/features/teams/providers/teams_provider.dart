import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';

// ── Folders ───────────────────────────────────────────────────────────────────

final foldersProvider = StreamProvider<List<TeamFolder>>((ref) {
  return ref.watch(teamFolderRepositoryProvider).watchAll();
});

// ── Teams ─────────────────────────────────────────────────────────────────────

final allTeamsProvider = StreamProvider<List<Team>>((ref) {
  return ref.watch(teamRepositoryProvider).watchAll();
});

final teamsByFolderProvider =
    StreamProvider.family<List<Team>, int>((ref, folderId) {
  return ref.watch(teamRepositoryProvider).watchByFolder(folderId);
});

// ── Actions ───────────────────────────────────────────────────────────────────

Future<void> createFolder(WidgetRef ref, String name) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final localId = await repo.insert(
    TeamFoldersCompanion(
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('create'),
    entityType: const Value('team_folder'),
    entityId: Value(localId),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> renameFolder(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.update(
    TeamFoldersCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team_folder'),
    entityId: Value(id),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> deleteFolder(WidgetRef ref, int id) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  // Capture remoteId before deleting locally
  final folder = await repo.getById(id);
  await repo.delete(id);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('delete'),
    entityType: const Value('team_folder'),
    entityId: Value(id),
    payload: Value(jsonEncode({'remote_id': folder.remoteId})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<int> createTeam(
  WidgetRef ref,
  String name, {
  int? folderId,
  String? formatLabel,
}) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final localId = await repo.insert(
    TeamsCompanion(
      name: Value(name),
      folderId: Value(folderId),
      formatLabel: Value(formatLabel),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('create'),
    entityType: const Value('team'),
    entityId: Value(localId),
    payload: Value(jsonEncode({
      'name': name,
      'folder_local_id': folderId,
      'format_label': formatLabel,
    })),
    createdAt: Value(DateTime.now()),
  ));

  return localId;
}

Future<void> updateTeamFormat(WidgetRef ref, int id, String? formatLabel) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.updateFormatLabel(id, formatLabel);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'format_label': formatLabel})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> renameTeam(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.update(
    TeamsCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> deleteTeam(WidgetRef ref, int id) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final team = await repo.getById(id);
  await repo.delete(id);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('delete'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'remote_id': team.remoteId})),
    createdAt: Value(DateTime.now()),
  ));
}
