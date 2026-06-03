import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';

class TeamSlotRepository {
  TeamSlotRepository(this._db, this._syncQueue);
  final AppDatabase _db;
  final SyncQueueRepository _syncQueue;

  Stream<List<TeamSlot>> watchByTeam(int teamId) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId))
            ..orderBy([(s) => OrderingTerm.asc(s.slot)]))
          .watch();

  Future<TeamSlot?> getByTeamAndSlot(int teamId, int slot) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId) & s.slot.equals(slot)))
          .getSingleOrNull();

  Future<List<TeamSlot>> getByTeam(int teamId) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId))
            ..orderBy([(s) => OrderingTerm.asc(s.slot)]))
          .get();

  Future<int> insert(TeamSlotsCompanion entry) =>
      _db.into(_db.teamSlots).insert(entry);

  Future<bool> update(TeamSlotsCompanion entry) =>
      _db.update(_db.teamSlots).replace(entry);

  Future<int> deleteSlot(int teamId, int slot) =>
      (_db.delete(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId) & s.slot.equals(slot)))
          .go();

  Future<int> deleteAllForTeam(int teamId) =>
      (_db.delete(_db.teamSlots)..where((s) => s.teamId.equals(teamId))).go();

  /// All non-deleted slots that contain [pokemonId] across every team.
  Stream<List<TeamSlot>> watchByPokemonId(int pokemonId) =>
      (_db.select(_db.teamSlots)
            ..where(
              (s) => s.pokemonId.equals(pokemonId) & s.isDeleted.equals(false),
            ))
          .watch();

  /// Updates only the slot-position column — safe to call during reorder.
  Future<int> updateSlotPosition(int id, int newSlot) =>
      (_db.update(_db.teamSlots)..where((s) => s.id.equals(id)))
          .write(TeamSlotsCompanion(slot: Value(newSlot)));

  /// Partial-updates only instanceId, bumping syncStatus and enqueueing a sync
  /// op so the link is pushed to the server on the next sync cycle.
  Future<void> setInstanceId(int slotId, int? instanceId) async {
    await (_db.update(_db.teamSlots)..where((s) => s.id.equals(slotId))).write(
      TeamSlotsCompanion(
        instanceId: Value(instanceId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final slot = await (_db.select(_db.teamSlots)
          ..where((s) => s.id.equals(slotId)))
        .getSingleOrNull();
    if (slot == null) return;

    final payload = <String, dynamic>{
      'team_local_id': slot.teamId,
      'slot': slot.slot,
      'pokemon_id': slot.pokemonId,
      if (instanceId != null) 'instance_client_local_id': instanceId,
    };
    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('upsert'),
      entityType: const Value('team_slot'),
      entityId: Value(slotId),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(DateTime.now()),
    ));
  }
}
