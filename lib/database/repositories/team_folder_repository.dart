import 'package:poke_team_dex/database/app_database.dart';

class TeamFolderRepository {
  TeamFolderRepository(this._db);
  final AppDatabase _db;

  Stream<List<TeamFolder>> watchAll() =>
      _db.select(_db.teamFolders).watch();

  Future<List<TeamFolder>> getAll() =>
      _db.select(_db.teamFolders).get();

  Future<TeamFolder> getById(int id) =>
      (_db.select(_db.teamFolders)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insert(TeamFoldersCompanion entry) =>
      _db.into(_db.teamFolders).insert(entry);

  Future<bool> update(TeamFoldersCompanion entry) =>
      _db.update(_db.teamFolders).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.teamFolders)..where((t) => t.id.equals(id))).go();
}
