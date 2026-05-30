import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/tables/team_folders_table.dart';

class Teams extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId =>
      integer().nullable().references(TeamFolders, #id)();
  TextColumn get name => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get formatLabel => text().nullable()(); // e.g. "VGC 2025"
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))(); // display order within folder
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // 'synced'|'pending'|'error'
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
