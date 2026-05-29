import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/tables/team_folders_table.dart';

class Teams extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId =>
      integer().nullable().references(TeamFolders, #id)();
  TextColumn get name => text()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
