import 'package:poke_team_dex/database/app_database.dart';

class TeamRepository {
  TeamRepository(this._db);
  final AppDatabase _db;

  Stream<List<Team>> watchAll() =>
      _db.select(_db.teams).watch();

  Stream<List<Team>> watchByFolder(int folderId) =>
      (_db.select(_db.teams)
            ..where((t) => t.folderId.equals(folderId)))
          .watch();

  Future<List<Team>> getAll() =>
      _db.select(_db.teams).get();

  Future<List<Team>> getByFolder(int folderId) =>
      (_db.select(_db.teams)
            ..where((t) => t.folderId.equals(folderId)))
          .get();

  Future<Team> getById(int id) =>
      (_db.select(_db.teams)..where((t) => t.id.equals(id))).getSingle();

  Future<Team?> getByRemoteId(String remoteId) =>
      (_db.select(_db.teams)..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();

  Future<int> insert(TeamsCompanion entry) =>
      _db.into(_db.teams).insert(entry);

  Future<bool> update(TeamsCompanion entry) =>
      _db.update(_db.teams).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.teams)..where((t) => t.id.equals(id))).go();
}
