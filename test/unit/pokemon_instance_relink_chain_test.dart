// Tests for PokemonInstanceRepository.relinkOrphanedChain().
//
// relinkOrphanedChain() has two responsibilities:
//   1. Re-parent children of orphaned instances to their grandparent so the
//      chain stays continuous after an unlink or slot removal.
//   2. Enqueue pokemon_instance:update sync ops for each re-parented instance
//      that has a remoteId, so the server's chain stays consistent.
//
// Legend used in test names:
//   [L]  – instance is referenced by at least one active (non-deleted) slot
//   [O]  – instance is orphaned (no active slot)
//   [S]  – instance has a remoteId (has been synced to server)
//   [U]  – instance has no remoteId (never synced; sync op skipped)

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/pokemon_instance_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import '../helpers/test_database.dart';

// ── DB helpers ─────────────────────────────────────────────────────────────────

/// Inserts a PokemonInstance and returns its id. Pass [remoteId] to simulate
/// an instance that has already been synced to the server.
Future<int> _mkInstance(AppDatabase db, {int? parentId, String? remoteId}) =>
    db.into(db.pokemonInstances).insert(PokemonInstancesCompanion(
          pokemonId: const Value(1),
          parentInstanceId: Value(parentId),
          remoteId: Value(remoteId),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

/// Creates a bare team (required FK for slots) and returns its id.
Future<int> _mkTeam(AppDatabase db) =>
    db.into(db.teams).insert(TeamsCompanion(
          name: const Value('Test Team'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

/// Links [instanceId] to an active slot (is_deleted = 0), making the
/// instance "not orphaned".
Future<void> _link(AppDatabase db, int teamId, int slot, int instanceId) =>
    db.into(db.teamSlots).insert(TeamSlotsCompanion(
          teamId: Value(teamId),
          slot: Value(slot),
          pokemonId: const Value(1),
          instanceId: Value(instanceId),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

/// Links [instanceId] to a soft-deleted slot (is_deleted = 1). The instance
/// must still be treated as orphaned — soft-deleted slots do not count.
Future<void> _linkDeleted(
        AppDatabase db, int teamId, int slot, int instanceId) =>
    db.into(db.teamSlots).insert(TeamSlotsCompanion(
          teamId: Value(teamId),
          slot: Value(slot),
          pokemonId: const Value(1),
          instanceId: Value(instanceId),
          isDeleted: const Value(true),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

/// Returns the current parentInstanceId for [instanceId].
Future<int?> _parent(AppDatabase db, int instanceId) async {
  final row = await (db.select(db.pokemonInstances)
        ..where((i) => i.id.equals(instanceId)))
      .getSingle();
  return row.parentInstanceId;
}

/// Returns all instance ids still in the table, sorted.
Future<List<int>> _allIds(AppDatabase db) async {
  final rows = await db.select(db.pokemonInstances).get();
  return rows.map((r) => r.id).toList()..sort();
}

/// Decodes the JSON payload of a pending sync op.
Map<String, dynamic> _payload(PendingSyncOp op) =>
    jsonDecode(op.payload) as Map<String, dynamic>;

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('relinkOrphanedChain', () {
    // ── 1. Chain repair — parent links ────────────────────────────────────────
    group('chain repair — parent links', () {
      test('empty DB — 0 changes, no crash', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));

        expect(await repo.relinkOrphanedChain(), 0);
      });

      test('all linked, no orphans — 0 changes, parent links unchanged', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // A[L] → C[L]
        final a = await _mkInstance(db);
        final c = await _mkInstance(db, parentId: a);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        expect(await repo.relinkOrphanedChain(), 0);
        expect(await _parent(db, c), a);
      });

      test('orphan leaf with no children — 0 changes (nothing to re-parent)', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // A[L] → B[O] (leaf — no children below B)
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        await _link(db, teamId, 1, a);
        // B has no slot

        expect(await repo.relinkOrphanedChain(), 0);
        expect(await _parent(db, b), a); // B untouched
      });

      test('A[L] → B[O] → C[L]  →  C.parent becomes A, returns 1', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);
        // B orphaned

        expect(await repo.relinkOrphanedChain(), 1);
        expect(await _parent(db, c), a);
      });

      test('B[O] root orphan → C[L]  →  C.parent becomes null (C is new root)', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // B is itself the origin (no parent); C is B's child
        final b = await _mkInstance(db);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, c);
        // B has no slot

        expect(await repo.relinkOrphanedChain(), 1);
        expect(await _parent(db, c), isNull);
      });

      test(
          'A[L] → B[O] → D[O] → C[L]  →  C.parent becomes A, '
          'requires 2 loop passes', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final d = await _mkInstance(db, parentId: b);
        final c = await _mkInstance(db, parentId: d);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        expect(await repo.relinkOrphanedChain(), greaterThanOrEqualTo(2));
        expect(await _parent(db, c), a);
      });

      test(
          'A[L] → B[O] → D[O] → E[O] → C[L]  →  C.parent becomes A '
          'after 3 loop passes', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final d = await _mkInstance(db, parentId: b);
        final e = await _mkInstance(db, parentId: d);
        final c = await _mkInstance(db, parentId: e);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();
        expect(await _parent(db, c), a);
      });

      test('A[L] → B[O] → {C1[L], C2[L]}  →  both children re-parented to A', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a  = await _mkInstance(db);
        final b  = await _mkInstance(db, parentId: a);
        final c1 = await _mkInstance(db, parentId: b);
        final c2 = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c1);
        await _link(db, teamId, 3, c2);

        expect(await repo.relinkOrphanedChain(), 2);
        expect(await _parent(db, c1), a);
        expect(await _parent(db, c2), a);
      });

      test('two independent chains with one orphan each — both repaired', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // Chain 1: A → B[O] → C
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        // Chain 2: X → Y[O] → Z
        final x = await _mkInstance(db);
        final y = await _mkInstance(db, parentId: x);
        final z = await _mkInstance(db, parentId: y);
        await _link(db, teamId, 3, x);
        await _link(db, teamId, 4, z);

        expect(await repo.relinkOrphanedChain(), 2);
        expect(await _parent(db, c), a);
        expect(await _parent(db, z), x);
      });

      test('orphan leaf child also gets re-parented even though it has no children',
          () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // B[O] → C[O, leaf], B[O] → D[L]
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b); // orphan leaf
        final d = await _mkInstance(db, parentId: b); // linked
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, d);
        // B and C have no slots

        await repo.relinkOrphanedChain();

        expect(await _parent(db, c), a); // C (orphan leaf) re-parented too
        expect(await _parent(db, d), a);
      });

      test('slot with is_deleted=1 makes instance appear orphaned', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // A[L] → B (only soft-deleted slot → treated as [O]) → C[L]
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _linkDeleted(db, teamId, 2, b); // soft-deleted — B is still orphaned
        await _link(db, teamId, 3, c);

        expect(await repo.relinkOrphanedChain(), 1);
        expect(await _parent(db, c), a);
      });

      test('one active + one soft-deleted slot on same instance — treated as linked',
          () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // A[L] → B (active slot + soft-deleted slot → B is [L]) → C[L]
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, b);        // active → B is linked
        await _linkDeleted(db, teamId, 3, b); // soft-deleted (should not matter)
        await _link(db, teamId, 4, c);

        expect(await repo.relinkOrphanedChain(), 0); // B is active → no orphan
        expect(await _parent(db, c), b); // unchanged
      });

      test('complex tree: A→B[O]→C→D[O]→E[O]→F  (C and F linked)  →  C.parent=A, F.parent=C',
          () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        final d = await _mkInstance(db, parentId: c);
        final e = await _mkInstance(db, parentId: d);
        final f = await _mkInstance(db, parentId: e);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);
        await _link(db, teamId, 3, f);

        await repo.relinkOrphanedChain();

        expect(await _parent(db, c), a); // B collapsed
        expect(await _parent(db, f), c); // D + E collapsed
      });

      test('relinkOrphanedChain does NOT delete any instance rows', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        // B still exists — deletion is handled by DatabaseMaintenanceRepository.cleanup()
        expect(await _allIds(db), containsAll([a, b, c]));
      });

      test(
          'all-orphan chain B[O]→C[O]→D[L]: D and C become roots after two passes',
          () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // No linked ancestor — C and D inherit null as parent
        final b = await _mkInstance(db);           // root orphan
        final c = await _mkInstance(db, parentId: b); // orphan
        final d = await _mkInstance(db, parentId: c); // linked
        await _link(db, teamId, 1, d);

        await repo.relinkOrphanedChain();

        expect(await _parent(db, d), isNull); // D is now a root
      });
    });

    // ── 2. Sync op enqueueing ─────────────────────────────────────────────────
    group('sync op enqueueing', () {
      test('no sync ops when nothing changed', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        // All linked
        final a = await _mkInstance(db, remoteId: '10');
        final c = await _mkInstance(db, parentId: a, remoteId: '30');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        expect(await syncQueue.getPending(), isEmpty);
      });

      test('no sync ops for an orphan leaf — nothing was re-parented', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db, remoteId: '10');
        await _mkInstance(db, parentId: a, remoteId: '20'); // orphan leaf
        await _link(db, teamId, 1, a);

        await repo.relinkOrphanedChain();

        expect(await syncQueue.getPending(), isEmpty);
      });

      test('re-parented instance [S] → gets operation=update, entityType=pokemon_instance', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db, remoteId: '10');
        final b = await _mkInstance(db, parentId: a, remoteId: '20');
        final c = await _mkInstance(db, parentId: b, remoteId: '30');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(1));
        expect(ops.first.operation, 'update');
        expect(ops.first.entityType, 'pokemon_instance');
        expect(ops.first.entityId, c);
      });

      test('re-parented instance [U] (no remoteId) — no sync op enqueued', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db, remoteId: '10');
        final b = await _mkInstance(db, parentId: a, remoteId: '20');
        final c = await _mkInstance(db, parentId: b); // no remoteId → never synced
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        expect(await syncQueue.getPending(), isEmpty);
      });

      test('mixed [S]/[U] children of same orphan — only [S] gets a sync op', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        final a  = await _mkInstance(db, remoteId: '10');
        final b  = await _mkInstance(db, parentId: a, remoteId: '20'); // orphan
        final c  = await _mkInstance(db, parentId: b, remoteId: '30'); // synced child
        final d  = await _mkInstance(db, parentId: b);                 // unsynced child
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);
        await _link(db, teamId, 3, d);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(1));
        expect(ops.first.entityId, c);
      });

      test('sync op payload: update_parent=true and parent_instance_remote_id=<int>', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        // A's remoteId is '100' — numeric string so int.tryParse returns 100.
        final a = await _mkInstance(db, remoteId: '100');
        final b = await _mkInstance(db, parentId: a, remoteId: '200');
        final c = await _mkInstance(db, parentId: b, remoteId: '300');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        final payload = _payload(ops.single);
        expect(payload['update_parent'], true);
        expect(payload['parent_instance_remote_id'], 100);
      });

      test(
          'root orphan: payload has update_parent=true but '
          'NO parent_instance_remote_id key', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        // B is itself the root — has no parent
        final b = await _mkInstance(db, remoteId: '200');
        final c = await _mkInstance(db, parentId: b, remoteId: '300');
        await _link(db, teamId, 1, c);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(1));
        final payload = _payload(ops.single);
        expect(payload['update_parent'], true);
        expect(payload.containsKey('parent_instance_remote_id'), isFalse);
      });

      test(
          'new parent [U] (no remoteId): payload has update_parent=true '
          'but no parent_instance_remote_id', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        // A is unsynced (no remoteId) — its id cannot be communicated to server
        final a = await _mkInstance(db);             // unsynced
        final b = await _mkInstance(db, parentId: a, remoteId: '200'); // orphan
        final c = await _mkInstance(db, parentId: b, remoteId: '300');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(1));
        final payload = _payload(ops.single);
        expect(payload['update_parent'], true);
        expect(payload.containsKey('parent_instance_remote_id'), isFalse);
      });

      test('branching orphan: both [S] children each get a separate sync op', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        final a  = await _mkInstance(db, remoteId: '10');
        final b  = await _mkInstance(db, parentId: a, remoteId: '20'); // orphan
        final c1 = await _mkInstance(db, parentId: b, remoteId: '31');
        final c2 = await _mkInstance(db, parentId: b, remoteId: '32');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c1);
        await _link(db, teamId, 3, c2);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(2));
        final entityIds = ops.map((o) => o.entityId).toSet();
        expect(entityIds, containsAll([c1, c2]));

        for (final op in ops) {
          final payload = _payload(op);
          expect(payload['update_parent'], true);
          expect(payload['parent_instance_remote_id'], 10); // A's remote id as int
        }
      });

      test('two independent chains: each [S] child gets a correctly-keyed sync op', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final syncQueue = SyncQueueRepository(db);
        final repo = PokemonInstanceRepository(db, syncQueue);
        final teamId = await _mkTeam(db);

        // Chain 1: A[r:10] → B[O,r:20] → C[r:30]
        final a = await _mkInstance(db, remoteId: '10');
        final b = await _mkInstance(db, parentId: a, remoteId: '20');
        final c = await _mkInstance(db, parentId: b, remoteId: '30');
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        // Chain 2: X[r:40] → Y[O,r:50] → Z[r:60]
        final x = await _mkInstance(db, remoteId: '40');
        final y = await _mkInstance(db, parentId: x, remoteId: '50');
        final z = await _mkInstance(db, parentId: y, remoteId: '60');
        await _link(db, teamId, 3, x);
        await _link(db, teamId, 4, z);

        await repo.relinkOrphanedChain();

        final ops = await syncQueue.getPending();
        expect(ops, hasLength(2));

        final cOp = ops.firstWhere((o) => o.entityId == c);
        expect(_payload(cOp)['parent_instance_remote_id'], 10);

        final zOp = ops.firstWhere((o) => o.entityId == z);
        expect(_payload(zOp)['parent_instance_remote_id'], 40);
      });
    });

    // ── 3. Return value ───────────────────────────────────────────────────────
    group('return value', () {
      test('returns 0 for empty DB', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));

        expect(await repo.relinkOrphanedChain(), 0);
      });

      test('returns 0 when all instances are linked', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, b);

        expect(await repo.relinkOrphanedChain(), 0);
      });

      test('returns 1 for a single intermediate orphan with one child', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final c = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        expect(await repo.relinkOrphanedChain(), 1);
      });

      test('returns 2 for branching orphan with two linked children', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        final a  = await _mkInstance(db);
        final b  = await _mkInstance(db, parentId: a);
        final c1 = await _mkInstance(db, parentId: b);
        final c2 = await _mkInstance(db, parentId: b);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c1);
        await _link(db, teamId, 3, c2);

        expect(await repo.relinkOrphanedChain(), 2);
      });

      test('returns sum across all loop passes for consecutive orphans', () async {
        final db = openTestDatabase();
        addTearDown(db.close);
        final repo = PokemonInstanceRepository(db, SyncQueueRepository(db));
        final teamId = await _mkTeam(db);

        // A → B[O] → D[O] → C — needs 2 passes, total ≥ 2 rows updated
        final a = await _mkInstance(db);
        final b = await _mkInstance(db, parentId: a);
        final d = await _mkInstance(db, parentId: b);
        final c = await _mkInstance(db, parentId: d);
        await _link(db, teamId, 1, a);
        await _link(db, teamId, 2, c);

        expect(await repo.relinkOrphanedChain(), greaterThanOrEqualTo(2));
      });
    });
  });
}
