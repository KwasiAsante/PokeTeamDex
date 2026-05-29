import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:poke_team_dex/database/tables/app_config_table.dart';
import 'package:poke_team_dex/database/tables/meta_table.dart';
import 'package:poke_team_dex/database/tables/pending_sync_ops_table.dart';
import 'package:poke_team_dex/database/tables/team_folders_table.dart';
import 'package:poke_team_dex/database/tables/team_slots_table.dart';
import 'package:poke_team_dex/database/tables/teams_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TeamFolders, Teams, TeamSlots, PendingSyncOps, Meta, AppConfigs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(appConfigs);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(
      name: 'poketeamdex',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            // ignore: avoid_print
            print(
              'Drift web: using ${result.chosenImplementation} '
              '(missing: ${result.missingFeatures})',
            );
          }
        },
      ),
    );
  });
}
