import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class DatabaseMaintenanceRepository {
  DatabaseMaintenanceRepository(this._db);
  final AppDatabase _db;

  /// Removes orphaned and logically-dead rows across all local tables.
  ///
  /// Returns a summary of how many rows were removed in each category so the
  /// UI can display a meaningful result to the user.
  Future<CleanupResult> cleanup() async {
    // 1. Slots whose team was hard-deleted without cascading to its slots.
    final orphanedSlots = await _db.customUpdate(
      'DELETE FROM team_slots WHERE team_id NOT IN (SELECT id FROM teams)',
      updates: {_db.teamSlots},
      updateKind: UpdateKind.delete,
    );

    // 2. Slots that were soft-deleted (is_deleted = 1) but never purged.
    //    These accumulate when Pokémon are removed from a slot individually.
    final softDeletedSlots = await _db.customUpdate(
      'DELETE FROM team_slots WHERE is_deleted = 1',
      updates: {_db.teamSlots},
      updateKind: UpdateKind.delete,
    );

    // 3. PokemonInstances no longer referenced by any remaining slot.
    final orphanedInstances = await _db.customUpdate(
      'DELETE FROM pokemon_instances '
      'WHERE id NOT IN ('
      '  SELECT DISTINCT instance_id FROM team_slots WHERE instance_id IS NOT NULL'
      ')',
      updates: {_db.pokemonInstances},
      updateKind: UpdateKind.delete,
    );

    return CleanupResult(
      slotsDeleted: orphanedSlots + softDeletedSlots,
      instancesDeleted: orphanedInstances,
    );
  }
}

class CleanupResult {
  const CleanupResult({
    required this.slotsDeleted,
    required this.instancesDeleted,
  });

  final int slotsDeleted;
  final int instancesDeleted;

  int get total => slotsDeleted + instancesDeleted;

  String get summary {
    if (total == 0) return 'Database is already clean — nothing to remove.';
    final parts = <String>[];
    if (slotsDeleted > 0) {
      parts.add('$slotsDeleted slot${slotsDeleted == 1 ? '' : 's'}');
    }
    if (instancesDeleted > 0) {
      parts.add(
          '$instancesDeleted instance${instancesDeleted == 1 ? '' : 's'}');
    }
    return 'Removed ${parts.join(' and ')}.';
  }
}
