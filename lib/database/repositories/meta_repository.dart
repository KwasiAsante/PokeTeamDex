import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class MetaRepository {
  MetaRepository(this._db);
  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.meta)
          ..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      _db.into(_db.meta).insertOnConflictUpdate(
            MetaCompanion(key: Value(key), value: Value(value)),
          );

  Future<int> remove(String key) =>
      (_db.delete(_db.meta)..where((m) => m.key.equals(key))).go();
}
