import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

const _kApiBaseUrl = 'api_base_url';
const kDefaultApiBaseUrl = 'http://localhost:8000';

class AppConfigRepository {
  AppConfigRepository(this._db);
  final AppDatabase _db;

  // ── Generic get / set ──────────────────────────────────────────────────────

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appConfigs)
          ..where((c) => c.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      _db.into(_db.appConfigs).insertOnConflictUpdate(
            AppConfigsCompanion(
              key: Value(key),
              value: Value(value),
              updatedAt: Value(DateTime.now()),
            ),
          );

  Stream<String?> watch(String key) => (_db.select(_db.appConfigs)
        ..where((c) => c.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);

  // ── Typed accessors ────────────────────────────────────────────────────────

  Future<String> getApiBaseUrl() async =>
      (await get(_kApiBaseUrl)) ?? kDefaultApiBaseUrl;

  Future<void> setApiBaseUrl(String url) => set(_kApiBaseUrl, url);

  Stream<String> watchApiBaseUrl() =>
      watch(_kApiBaseUrl).map((v) => v ?? kDefaultApiBaseUrl);
}
