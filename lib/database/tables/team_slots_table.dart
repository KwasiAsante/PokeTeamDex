import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/tables/teams_table.dart';

class TeamSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get teamId => integer().references(Teams, #id)();
  IntColumn get slot => integer()(); // 1–6
  IntColumn get pokemonId => integer()(); // national dex ID
  TextColumn get nickname => text().nullable()();

  // Form / variant
  TextColumn get formName => text().nullable()();

  // Basics
  IntColumn get level => integer().nullable()(); // 1–100, UI default 50
  TextColumn get gender => text().nullable()(); // 'male' | 'female' | 'genderless'
  BoolColumn get isShiny => boolean().withDefault(const Constant(false))();
  IntColumn get friendship => integer().nullable()(); // 0–255

  // Build
  TextColumn get abilityName => text().nullable()();
  TextColumn get natureName => text().nullable()();
  TextColumn get heldItemName => text().nullable()();

  // Moves
  TextColumn get move1 => text().nullable()();
  TextColumn get move2 => text().nullable()();
  TextColumn get move3 => text().nullable()();
  TextColumn get move4 => text().nullable()();

  // EVs (0–252 each, total ≤ 510)
  IntColumn get evHp => integer().nullable()();
  IntColumn get evAtk => integer().nullable()();
  IntColumn get evDef => integer().nullable()();
  IntColumn get evSpa => integer().nullable()();
  IntColumn get evSpd => integer().nullable()();
  IntColumn get evSpe => integer().nullable()();

  // IVs (0–31 each, UI default 31)
  IntColumn get ivHp => integer().nullable()();
  IntColumn get ivAtk => integer().nullable()();
  IntColumn get ivDef => integer().nullable()();
  IntColumn get ivSpa => integer().nullable()();
  IntColumn get ivSpd => integer().nullable()();
  IntColumn get ivSpe => integer().nullable()();

  // Ribbons — JSON array of ribbon IDs, e.g. '["champion","effort"]'
  TextColumn get ribbons => text().nullable()();

  // Mega Evolution toggle (Gen 6–7 only)
  BoolColumn get isMegaEvolved =>
      boolean().withDefault(const Constant(false))();

  // Gigantamax (Gen 8)
  BoolColumn get hasGigantamax =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get gigantamaxEnabled =>
      boolean().withDefault(const Constant(false))();

  // Alpha Pokémon (Legends: Arceus)
  BoolColumn get isAlpha =>
      boolean().withDefault(const Constant(false))();

  // Contest conditions (Gen III+): 0–255 each
  IntColumn get contestCool      => integer().nullable()();
  IntColumn get contestBeautiful => integer().nullable()();
  IntColumn get contestCute      => integer().nullable()();
  IntColumn get contestClever    => integer().nullable()();
  IntColumn get contestTough     => integer().nullable()();
  IntColumn get contestSheen     => integer().nullable()();

  // Sync
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // 'synced'|'pending'|'error'

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
