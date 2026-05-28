import 'package:drift/drift.dart';

/// Operations waiting to be synced to the remote backend.
class PendingSyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'create' | 'update' | 'delete'
  TextColumn get operation => text()();

  /// 'team_folder' | 'team' | 'team_slot'
  TextColumn get entityType => text()();

  IntColumn get entityId => integer()();

  /// JSON payload for create/update operations.
  TextColumn get payload => text().withDefault(const Constant('{}'))();

  IntColumn get attempts =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
