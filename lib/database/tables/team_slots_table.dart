import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/tables/teams_table.dart';

class TeamSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get teamId => integer().references(Teams, #id)();
  IntColumn get slot => integer()(); // 1–6
  IntColumn get pokemonId => integer()(); // national dex ID
  TextColumn get nickname => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
