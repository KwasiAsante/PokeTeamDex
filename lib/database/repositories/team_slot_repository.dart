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
      if (slot.nickname != null && slot.nickname!.isNotEmpty) 'nickname': slot.nickname,
      if (instanceId != null) 'instance_client_local_id': instanceId,
      if (slot.formName != null) 'form_name': slot.formName,
      'level': slot.level,
      if (slot.gender != null) 'gender': slot.gender,
      'is_shiny': slot.isShiny,
      if (slot.friendship != null) 'friendship': slot.friendship,
      if (slot.abilityName != null) 'ability_name': slot.abilityName,
      if (slot.natureName != null) 'nature_name': slot.natureName,
      if (slot.heldItemName != null) 'held_item_name': slot.heldItemName,
      if (slot.move1 != null) 'move1': slot.move1,
      if (slot.move2 != null) 'move2': slot.move2,
      if (slot.move3 != null) 'move3': slot.move3,
      if (slot.move4 != null) 'move4': slot.move4,
      'ev_hp': slot.evHp, 'ev_atk': slot.evAtk, 'ev_def': slot.evDef,
      'ev_spa': slot.evSpa, 'ev_spd': slot.evSpd, 'ev_spe': slot.evSpe,
      'iv_hp': slot.ivHp, 'iv_atk': slot.ivAtk, 'iv_def': slot.ivDef,
      'iv_spa': slot.ivSpa, 'iv_spd': slot.ivSpd, 'iv_spe': slot.ivSpe,
      if (slot.ribbons != null) 'ribbons': slot.ribbons,
      'is_mega_evolved': slot.isMegaEvolved,
      'has_gigantamax': slot.hasGigantamax,
      'gigantamax_enabled': slot.gigantamaxEnabled,
      'is_alpha': slot.isAlpha,
      'contest_cool': slot.contestCool, 'contest_beautiful': slot.contestBeautiful,
      'contest_cute': slot.contestCute, 'contest_clever': slot.contestClever,
      'contest_tough': slot.contestTough, 'contest_sheen': slot.contestSheen,
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
