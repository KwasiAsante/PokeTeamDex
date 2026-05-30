import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class TeamFolderRepository {
  TeamFolderRepository(this._db);
  final AppDatabase _db;

  Stream<List<TeamFolder>> watchAll() =>
      (_db.select(_db.teamFolders)
            ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
          .watch();

  Future<List<TeamFolder>> getAll() =>
      (_db.select(_db.teamFolders)
            ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
          .get();

  Future<TeamFolder> getById(int id) =>
      (_db.select(_db.teamFolders)..where((f) => f.id.equals(id))).getSingle();

  Future<TeamFolder?> getByRemoteId(String remoteId) =>
      (_db.select(_db.teamFolders)..where((f) => f.remoteId.equals(remoteId)))
          .getSingleOrNull();

  Future<int> insert(TeamFoldersCompanion entry) =>
      _db.into(_db.teamFolders).insert(entry);

  Future<bool> update(TeamFoldersCompanion entry) =>
      _db.update(_db.teamFolders).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.teamFolders)..where((f) => f.id.equals(id))).go();

  Future<int> updateSortOrder(int id, int sortOrder) =>
      (_db.update(_db.teamFolders)..where((f) => f.id.equals(id)))
          .write(TeamFoldersCompanion(sortOrder: Value(sortOrder)));
}
