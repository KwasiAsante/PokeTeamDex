import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:poke_team_dex/database/tables/meta_table.dart';
import 'package:poke_team_dex/database/tables/pending_sync_ops_table.dart';
import 'package:poke_team_dex/database/tables/team_folders_table.dart';
import 'package:poke_team_dex/database/tables/team_slots_table.dart';
import 'package:poke_team_dex/database/tables/teams_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TeamFolders, Teams, TeamSlots, PendingSyncOps, Meta],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(name: 'poketeamdex');
  });
}
