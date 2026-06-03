import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:poke_team_dex/database/tables/app_config_table.dart';
import 'package:poke_team_dex/database/tables/favorites_table.dart';
import 'package:poke_team_dex/database/tables/meta_table.dart';
import 'package:poke_team_dex/database/tables/pending_sync_ops_table.dart';
import 'package:poke_team_dex/database/tables/team_folders_table.dart';
import 'package:poke_team_dex/database/tables/team_slots_table.dart';
import 'package:poke_team_dex/database/tables/teams_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TeamFolders, Teams, TeamSlots, PendingSyncOps, Meta, AppConfigs, Favorites],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(appConfigs);
          }
          if (from < 3) {
            // TeamFolders — sort order + soft-delete + sync status
            await m.addColumn(teamFolders, teamFolders.sortOrder);
            await m.addColumn(teamFolders, teamFolders.isDeleted);
            await m.addColumn(teamFolders, teamFolders.syncStatus);

            // Teams — format label + sort order + soft-delete + sync status
            await m.addColumn(teams, teams.formatLabel);
            await m.addColumn(teams, teams.sortOrder);
            await m.addColumn(teams, teams.isDeleted);
            await m.addColumn(teams, teams.syncStatus);

            // TeamSlots — all slot config fields + soft-delete + sync status
            await m.addColumn(teamSlots, teamSlots.formName);
            await m.addColumn(teamSlots, teamSlots.level);
            await m.addColumn(teamSlots, teamSlots.gender);
            await m.addColumn(teamSlots, teamSlots.isShiny);
            await m.addColumn(teamSlots, teamSlots.friendship);
            await m.addColumn(teamSlots, teamSlots.abilityName);
            await m.addColumn(teamSlots, teamSlots.natureName);
            await m.addColumn(teamSlots, teamSlots.heldItemName);
            await m.addColumn(teamSlots, teamSlots.move1);
            await m.addColumn(teamSlots, teamSlots.move2);
            await m.addColumn(teamSlots, teamSlots.move3);
            await m.addColumn(teamSlots, teamSlots.move4);
            await m.addColumn(teamSlots, teamSlots.evHp);
            await m.addColumn(teamSlots, teamSlots.evAtk);
            await m.addColumn(teamSlots, teamSlots.evDef);
            await m.addColumn(teamSlots, teamSlots.evSpa);
            await m.addColumn(teamSlots, teamSlots.evSpd);
            await m.addColumn(teamSlots, teamSlots.evSpe);
            await m.addColumn(teamSlots, teamSlots.ivHp);
            await m.addColumn(teamSlots, teamSlots.ivAtk);
            await m.addColumn(teamSlots, teamSlots.ivDef);
            await m.addColumn(teamSlots, teamSlots.ivSpa);
            await m.addColumn(teamSlots, teamSlots.ivSpd);
            await m.addColumn(teamSlots, teamSlots.ivSpe);
            await m.addColumn(teamSlots, teamSlots.isDeleted);
            await m.addColumn(teamSlots, teamSlots.syncStatus);
          }
          if (from < 4) {
            await m.createTable(favorites);
          }
          if (from < 5) {
            await m.addColumn(teamSlots, teamSlots.contestCool);
            await m.addColumn(teamSlots, teamSlots.contestBeautiful);
            await m.addColumn(teamSlots, teamSlots.contestCute);
            await m.addColumn(teamSlots, teamSlots.contestClever);
            await m.addColumn(teamSlots, teamSlots.contestTough);
            await m.addColumn(teamSlots, teamSlots.contestSheen);
          }
          if (from < 6) {
            await m.addColumn(teamSlots, teamSlots.ribbons);
          }
          if (from < 7) {
            await m.addColumn(teamSlots, teamSlots.isMegaEvolved);
          }
          if (from < 8) {
            await m.addColumn(teamSlots, teamSlots.hasGigantamax);
            await m.addColumn(teamSlots, teamSlots.gigantamaxEnabled);
            await m.addColumn(teamSlots, teamSlots.isAlpha);
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
