import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class SyncQueueRepository {
  SyncQueueRepository(this._db);
  final AppDatabase _db;

  Future<List<PendingSyncOp>> getPending() =>
      (_db.select(_db.pendingSyncOps)
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
          .get();

  Stream<int> watchPendingCount() =>
      _db.pendingSyncOps.count().watchSingle();

  Future<int> enqueue(PendingSyncOpsCompanion entry) =>
      _db.into(_db.pendingSyncOps).insert(entry);

  Future<void> incrementAttempts(int id) =>
      (_db.update(_db.pendingSyncOps)..where((o) => o.id.equals(id)))
          .write(const PendingSyncOpsCompanion(
            attempts: Value.absent(),
          ));

  Future<void> markAttempted(int id, int currentAttempts) =>
      (_db.update(_db.pendingSyncOps)..where((o) => o.id.equals(id)))
          .write(PendingSyncOpsCompanion(
            attempts: Value(currentAttempts + 1),
          ));

  Future<int> delete(int id) =>
      (_db.delete(_db.pendingSyncOps)..where((o) => o.id.equals(id))).go();

  Future<int> clearAll() => _db.delete(_db.pendingSyncOps).go();
}
