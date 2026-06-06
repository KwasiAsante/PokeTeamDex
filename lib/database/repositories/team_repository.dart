import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class TeamRepository {
  TeamRepository(this._db);
  final AppDatabase _db;

  Stream<List<Team>> watchAll() =>
      (_db.select(_db.teams)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Stream<List<Team>> watchByFolder(int folderId) =>
      (_db.select(_db.teams)
            ..where((t) => t.folderId.equals(folderId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<Team>> getAll() =>
      (_db.select(_db.teams)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<List<Team>> getByFolder(int folderId) =>
      (_db.select(_db.teams)
            ..where((t) => t.folderId.equals(folderId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<Team> getById(int id) =>
      (_db.select(_db.teams)..where((t) => t.id.equals(id))).getSingle();

  Future<Team?> getByIdOrNull(int id) =>
      (_db.select(_db.teams)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Team?> getByRemoteId(String remoteId) =>
      (_db.select(_db.teams)..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();

  Future<int> insert(TeamsCompanion entry) =>
      _db.into(_db.teams).insert(entry);

  Future<bool> update(TeamsCompanion entry) =>
      _db.update(_db.teams).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.teams)..where((t) => t.id.equals(id))).go();

  Future<int> updateFolder(int id, int? folderId) =>
      (_db.update(_db.teams)..where((t) => t.id.equals(id)))
          .write(TeamsCompanion(
            folderId: Value(folderId),
            updatedAt: Value(DateTime.now()),
          ));

  Future<int> updateSortOrder(int id, int sortOrder) =>
      (_db.update(_db.teams)..where((t) => t.id.equals(id)))
          .write(TeamsCompanion(sortOrder: Value(sortOrder)));

  Future<int> updateFormatLabel(int id, String? formatLabel) =>
      (_db.update(_db.teams)..where((t) => t.id.equals(id)))
          .write(TeamsCompanion(
            formatLabel: Value(formatLabel),
            updatedAt: Value(DateTime.now()),
          ));

  Future<int> setIsBox(int id, {required bool isBox}) =>
      (_db.update(_db.teams)..where((t) => t.id.equals(id)))
          .write(TeamsCompanion(
            isBox: Value(isBox),
            updatedAt: Value(DateTime.now()),
          ));
}
