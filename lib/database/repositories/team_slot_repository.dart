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

  /// Removes a slot locally, cancels any pending upsert for it so it is not
  /// pushed back to the server, and enqueues a server-side delete op.
  ///
  /// Use this for all user-driven slot removals. Use [deleteSlot] only when
  /// the parent team is also being deleted — its team:delete op handles
  /// server-side slot cleanup.
  Future<void> deleteSlotWithQueue(
      int teamId, int slotPosition, int slotId) async {
    // Cancel any pending upsert for this slot so a just-removed slot is not
    // pushed back to the server on the next sync.
    final ops = await _syncQueue.getPending();
    for (final op in ops) {
      if (op.entityType != 'team_slot' || op.operation != 'upsert') continue;
      try {
        final p = jsonDecode(op.payload) as Map<String, dynamic>;
        if (p['team_local_id'] == teamId && p['slot'] == slotPosition) {
          await _syncQueue.delete(op.id);
        }
      } catch (_) {}
    }

    await deleteSlot(teamId, slotPosition);

    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('delete'),
      entityType: const Value('team_slot'),
      entityId: Value(slotId),
      payload: Value(jsonEncode({'team_local_id': teamId, 'slot': slotPosition})),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// All non-deleted slots that contain [pokemonId] across every team.
  Stream<List<TeamSlot>> watchByPokemonId(int pokemonId) =>
      (_db.select(_db.teamSlots)
            ..where(
              (s) => s.pokemonId.equals(pokemonId) & s.isDeleted.equals(false),
            ))
          .watch();

  Stream<List<TeamSlot>> watchAll() =>
      (_db.select(_db.teamSlots)..where((s) => s.isDeleted.equals(false))).watch();

  /// Marks a slot as locally modified so the slot config UI shows it as pending.
  Future<void> markPending(int id) =>
      (_db.update(_db.teamSlots)..where((s) => s.id.equals(id))).write(
        TeamSlotsCompanion(
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Updates only the slot-position column — safe to call during reorder.
  Future<int> updateSlotPosition(int id, int newSlot) =>
      (_db.update(_db.teamSlots)..where((s) => s.id.equals(id)))
          .write(TeamSlotsCompanion(slot: Value(newSlot)));

  /// Marks every slot in [slots] as pending and enqueues a full upsert sync op
  /// for each one. Returns the number of slots processed.
  Future<int> saveAll(List<TeamSlot> slots) async {
    int count = 0;
    // Coalesce all writes into one transaction so Drift fires a single
    // table-invalidation per watched table at commit time, instead of one
    // per slot — same "stream storm" fix applied to sync_service.dart.
    await _db.transaction(() async {
      for (final slot in slots) {
        await (_db.update(_db.teamSlots)..where((s) => s.id.equals(slot.id))).write(
          TeamSlotsCompanion(
            syncStatus: const Value('pending'),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final payload = _buildPayload(slot, slot.instanceId);
        await _syncQueue.enqueue(PendingSyncOpsCompanion(
          operation: const Value('upsert'),
          entityType: const Value('team_slot'),
          entityId: Value(slot.id),
          payload: Value(jsonEncode(payload)),
          createdAt: Value(DateTime.now()),
        ));
        count++;
      }
    });
    return count;
  }

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

    final payload = _buildPayload(slot, instanceId);
    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('upsert'),
      entityType: const Value('team_slot'),
      entityId: Value(slotId),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(DateTime.now()),
    ));
  }

  Map<String, dynamic> _buildPayload(TeamSlot slot, int? instanceId) => {
    'team_local_id': slot.teamId,
    'slot': slot.slot,
    'pokemon_id': slot.pokemonId,
    if (slot.nickname != null && slot.nickname!.isNotEmpty) 'nickname': slot.nickname,
    'instance_client_local_id': ?instanceId,
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
}
