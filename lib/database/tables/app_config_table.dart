import 'package:drift/drift.dart';

/// Local-only key-value configuration for this app instance.
/// Never included in the sync queue.
class AppConfigs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
