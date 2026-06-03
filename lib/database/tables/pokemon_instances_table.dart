import 'package:drift/drift.dart';

/// Tracks a specific Pokémon's identity across multiple teams and formats.
///
/// A chain of instances represents the same Pokémon through its journey:
///   origin instance (parentInstanceId = null)
///     └── next iteration (parentInstanceId = origin.id)
///           └── ...
///
/// Ribbons earned and nickname history travel with the instance so that
/// transferring a Pokémon to a new team preserves its full history.
class PokemonInstances extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// National Dex ID of the Pokémon species.
  IntColumn get pokemonId => integer()();

  /// Points to the previous iteration of this Pokémon (null = origin).
  /// Self-referential — not enforced as a FK to avoid SQLite circular issues.
  IntColumn get parentInstanceId => integer().nullable()();

  /// JSON array of past nicknames in chronological order.
  /// e.g. '["Lancelot","Sir Lance"]' — used for the "previously known as" label.
  TextColumn get nicknameAliases => text().nullable()();

  /// Ribbons inherited from the parent chain, stored as a JSON array of ids.
  /// Merged with the current slot's own ribbons for display.
  TextColumn get inheritedRibbons => text().nullable()();

  /// Server-assigned ID once this instance has been synced.
  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
