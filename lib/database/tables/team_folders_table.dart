import 'package:drift/drift.dart';

class TeamFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get remoteId => text().nullable()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))(); // display order among folders
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // 'synced'|'pending'|'error'
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
