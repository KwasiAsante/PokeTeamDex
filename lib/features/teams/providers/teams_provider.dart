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
  await repo.insert(
    TeamFoldersCompanion(
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<void> renameFolder(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  await repo.update(
    TeamFoldersCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<void> deleteFolder(WidgetRef ref, int id) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  await repo.delete(id);
}

Future<int> createTeam(WidgetRef ref, String name, {int? folderId}) async {
  final repo = ref.read(teamRepositoryProvider);
  return repo.insert(
    TeamsCompanion(
      name: Value(name),
      folderId: Value(folderId),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<void> renameTeam(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamRepositoryProvider);
  await repo.update(
    TeamsCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<void> deleteTeam(WidgetRef ref, int id) async {
  final repo = ref.read(teamRepositoryProvider);
  await repo.delete(id);
}
