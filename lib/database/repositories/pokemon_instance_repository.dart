import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';

class PokemonInstanceRepository {
  PokemonInstanceRepository(this._db, this._syncQueue);
  final AppDatabase _db;
  final SyncQueueRepository _syncQueue;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a new origin instance for a Pokémon (no parent).
  Future<int> createOrigin({
    required int pokemonId,
  }) async {
    final id = await _db.into(_db.pokemonInstances).insert(
          PokemonInstancesCompanion.insert(
            pokemonId: pokemonId,
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('create'),
      entityType: const Value('pokemon_instance'),
      entityId: Value(id),
      payload: Value(jsonEncode({'pokemon_id': pokemonId})),
      createdAt: Value(DateTime.now()),
    ));
    return id;
  }

  /// Creates a new iteration linked to [parentInstanceId], inheriting its
  /// ribbons. nicknameAliases starts null — aliases are written only by
  /// [addNicknameAlias] when a slot is renamed.
  Future<int> createIteration({
    required int pokemonId,
    required int parentInstanceId,
  }) async {
    final parent = await getById(parentInstanceId);
    if (parent == null) throw Exception('Parent instance $parentInstanceId not found');

    // Only ribbons propagate to the child — nicknameAliases always starts null.
    // Aliases are only written by addNicknameAlias when a slot is renamed.
    final inheritedRibbons = parent.inheritedRibbons;

    final id = await _db.into(_db.pokemonInstances).insert(
          PokemonInstancesCompanion.insert(
            pokemonId: pokemonId,
            parentInstanceId: Value(parentInstanceId),
            inheritedRibbons: Value(inheritedRibbons),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('create'),
      entityType: const Value('pokemon_instance'),
      entityId: Value(id),
      payload: Value(jsonEncode({
        'pokemon_id': pokemonId,
        'parent_instance_client_local_id': parentInstanceId,
        'inherited_ribbons': ?inheritedRibbons,
      })),
      createdAt: Value(DateTime.now()),
    ));
    return id;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<PokemonInstance?> getById(int id) =>
      (_db.select(_db.pokemonInstances)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<PokemonInstance?> watchById(int id) =>
      (_db.select(_db.pokemonInstances)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Future<PokemonInstance?> getByRemoteId(String remoteId) =>
      (_db.select(_db.pokemonInstances)
            ..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();

  /// Returns the full chain from the given instance back to the origin,
  /// ordered from oldest (origin) to newest.
  Future<List<PokemonInstance>> getChain(int instanceId) async {
    final chain = <PokemonInstance>[];
    PokemonInstance? current = await getById(instanceId);
    while (current != null) {
      chain.insert(0, current);
      final parentId = current.parentInstanceId;
      current = parentId != null ? await getById(parentId) : null;
    }
    return chain;
  }

  /// Returns all instances whose [parentInstanceId] equals [instanceId].
  Future<List<PokemonInstance>> getDirectChildren(int instanceId) =>
      (_db.select(_db.pokemonInstances)
            ..where((t) => t.parentInstanceId.equals(instanceId)))
          .get();

  /// Returns every descendant of [instanceId] — children, grandchildren, …,
  /// as a depth-first, pre-order flat list paired with their depth relative
  /// to [instanceId] (1 = direct child, 2 = grandchild, …).
  Future<List<(PokemonInstance instance, int depth)>> getDescendantTree(
    int instanceId,
  ) async {
    final result = <(PokemonInstance, int)>[];

    Future<void> visit(int parentId, int depth) async {
      for (final child in await getDirectChildren(parentId)) {
        result.add((child, depth));
        await visit(child.id, depth + 1);
      }
    }

    await visit(instanceId, 1);
    return result;
  }

  /// Returns all slots currently linked to [instanceId].
  Future<List<TeamSlot>> getSlotsForInstance(int instanceId) =>
      (_db.select(_db.teamSlots)
            ..where((s) =>
                s.instanceId.equalsNullable(instanceId) &
                s.isDeleted.equals(false)))
          .get();

  // ── Update ────────────────────────────────────────────────────────────────

  /// Appends [alias] to this instance's nickname history if not already present.
  Future<void> addNicknameAlias(int instanceId, String alias) async {
    final inst = await getById(instanceId);
    if (inst == null) return;
    final existing = inst.nicknameAliases != null
        ? (jsonDecode(inst.nicknameAliases!) as List).cast<String>()
        : <String>[];
    if (existing.contains(alias)) return;
    final updated = jsonEncode([...existing, alias]);
    await (_db.update(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .write(PokemonInstancesCompanion(
          nicknameAliases: Value(updated),
          updatedAt: Value(DateTime.now()),
        ));
    await _enqueueUpdate(instanceId);
  }

  /// Merges [ribbonIds] into the inherited ribbons of this instance (union).
  Future<void> mergeRibbons(int instanceId, List<String> ribbonIds) async {
    final inst = await getById(instanceId);
    if (inst == null) return;
    final existing = inst.inheritedRibbons != null
        ? (jsonDecode(inst.inheritedRibbons!) as List).cast<String>()
        : <String>[];
    final merged = {...existing, ...ribbonIds}.toList();
    await (_db.update(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .write(PokemonInstancesCompanion(
          inheritedRibbons: Value(jsonEncode(merged)),
          updatedAt: Value(DateTime.now()),
        ));
    await _enqueueUpdate(instanceId);
  }

  Future<void> _enqueueUpdate(int instanceId) async {
    final inst = await getById(instanceId);
    if (inst == null) return;
    await _syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('update'),
      entityType: const Value('pokemon_instance'),
      entityId: Value(instanceId),
      payload: Value(jsonEncode({
        if (inst.nicknameAliases != null) 'nickname_aliases': inst.nicknameAliases,
        if (inst.inheritedRibbons != null) 'inherited_ribbons': inst.inheritedRibbons,
      })),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// Re-parents direct children of orphaned instances (those with no active
  /// slot pointing to them) to their grandparent. Repeats until no further
  /// changes are needed so chains of consecutive orphans are fully collapsed.
  /// Enqueues instance_update sync ops for each re-parented instance.
  /// Returns the total number of instances updated.
  Future<int> relinkOrphanedChain() async {
    int total = 0;
    int changed;
    do {
      // Snapshot the children of orphaned instances BEFORE the SQL update so
      // we know which local IDs moved and can enqueue sync ops for them.
      final snapshot = await _db.customSelect(
        '''
        SELECT pi.id AS id, pi.remote_id AS remote_id
        FROM pokemon_instances pi
        WHERE pi.parent_instance_id IN (
          SELECT id FROM pokemon_instances
          WHERE id NOT IN (
            SELECT DISTINCT instance_id
            FROM team_slots
            WHERE instance_id IS NOT NULL AND is_deleted = 0
          )
        )
        ''',
        readsFrom: {_db.pokemonInstances, _db.teamSlots},
      ).get();

      changed = await _db.customUpdate(
        '''
        UPDATE pokemon_instances
        SET parent_instance_id = (
          SELECT orphan.parent_instance_id
          FROM pokemon_instances AS orphan
          WHERE orphan.id = pokemon_instances.parent_instance_id
            AND orphan.id NOT IN (
              SELECT DISTINCT instance_id
              FROM team_slots
              WHERE instance_id IS NOT NULL
                AND is_deleted = 0
            )
        )
        WHERE parent_instance_id IN (
          SELECT id FROM pokemon_instances
          WHERE id NOT IN (
            SELECT DISTINCT instance_id
            FROM team_slots
            WHERE instance_id IS NOT NULL
              AND is_deleted = 0
          )
        )
        ''',
        updates: {_db.pokemonInstances},
        updateKind: UpdateKind.update,
      );
      total += changed;

      if (changed > 0) {
        for (final row in snapshot) {
          final localId = row.read<int>('id');
          final remoteId = row.readNullable<String>('remote_id');
          if (remoteId == null) continue; // not yet synced; skip

          final inst = await getById(localId);
          if (inst == null) continue;

          int? newParentRemoteId;
          if (inst.parentInstanceId != null) {
            final parent = await getById(inst.parentInstanceId!);
            if (parent?.remoteId != null) {
              newParentRemoteId = int.tryParse(parent!.remoteId!);
            }
          }

          await _syncQueue.enqueue(PendingSyncOpsCompanion(
            operation: const Value('update'),
            entityType: const Value('pokemon_instance'),
            entityId: Value(localId),
            payload: Value(jsonEncode({
              'update_parent': true,
              'parent_instance_remote_id': ?newParentRemoteId,
            })),
            createdAt: Value(DateTime.now()),
          ));
        }
      }
    } while (changed > 0);
    return total;
  }

  /// Deletes all pokemon_instances that are no longer referenced by any
  /// active (non-deleted) slot. Call this after [relinkOrphanedChain] so
  /// children are re-parented before their former parent is removed.
  /// Returns the number of rows deleted.
  Future<int> deleteOrphanedInstances() => _db.customUpdate(
        'DELETE FROM pokemon_instances '
        'WHERE id NOT IN ('
        '  SELECT DISTINCT instance_id FROM team_slots '
        '  WHERE instance_id IS NOT NULL AND is_deleted = 0'
        ')',
        updates: {_db.pokemonInstances},
        updateKind: UpdateKind.delete,
      );

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(int instanceId) async {
    await (_db.update(_db.teamSlots)
          ..where((s) => s.instanceId.equalsNullable(instanceId)))
        .write(const TeamSlotsCompanion(instanceId: Value(null)));
    await (_db.delete(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .go();
  }
}
