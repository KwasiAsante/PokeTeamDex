// Unit tests for DatabaseMaintenanceRepository.relinkOrphanedDescendants().
//
// Each test builds an in-memory chain using raw DB inserts, then calls
// relinkOrphanedDescendants() and asserts the resulting parentInstanceId
// values. Slot insertions are used to mark an instance as "linked" (i.e.
// not orphaned). No slot = orphaned.
//
// Legend used in test names:
//   [linked]  – instance is referenced by at least one active slot
//   [orphan]  – instance has NO active slot reference

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/database_maintenance_repository.dart';
import '../helpers/test_database.dart';

// ── DB helpers ────────────────────────────────────────────────────────────────

/// Inserts a PokemonInstance and returns its id.
Future<int> _mkInstance(AppDatabase db, {int? parentId}) =>
    db.into(db.pokemonInstances).insert(PokemonInstancesCompanion(
          pokemonId: const Value(1),
          parentInstanceId: Value(parentId),
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

/// Links [instanceId] to a slot, making it "not orphaned".
Future<void> _link(AppDatabase db, int teamId, int slot, int instanceId) =>
    db.into(db.teamSlots).insert(TeamSlotsCompanion(
          teamId: Value(teamId),
          slot: Value(slot),
          pokemonId: const Value(1),
          instanceId: Value(instanceId),
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

/// Returns all instance ids still in the table.
Future<List<int>> _allIds(AppDatabase db) async {
  final rows = await db.select(db.pokemonInstances).get();
  return rows.map((r) => r.id).toList()..sort();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('relinkOrphanedDescendants', () {
    // ── 1. Nothing to do ──────────────────────────────────────────────────────
    test('all instances linked — no changes', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      // A[linked] → C[linked]
      final a = await _mkInstance(db);
      final c = await _mkInstance(db, parentId: a);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 0);
      expect(await _parent(db, c), a);
    });

    // ── 2. Leaf orphan — nothing to relink ────────────────────────────────────
    test('H[orphan] is a leaf with no children — 0 relinks', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      // G[linked] → H[orphan]
      final g = await _mkInstance(db);
      final h = await _mkInstance(db, parentId: g);
      await _link(db, teamId, 1, g);
      // H has no slot

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 0);
      expect(await _parent(db, h), g); // unchanged — cleanup() will delete H later
    });

    // ── 3. Simple intermediate orphan ─────────────────────────────────────────
    test('A → B[orphan] → C  →  C.parent becomes A', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);
      // B has no slot

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 1);
      expect(await _parent(db, c), a);
    });

    // ── 4. Root orphan ────────────────────────────────────────────────────────
    test('B[orphan] → C  →  C.parent becomes null (root)', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final b = await _mkInstance(db); // no parent itself
      final c = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, c);
      // B has no slot

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 1);
      expect(await _parent(db, c), isNull);
    });

    // ── 5. Two consecutive orphans (requires 2 passes) ────────────────────────
    test('A → B[orphan] → D[orphan] → C  →  C.parent becomes A', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final d = await _mkInstance(db, parentId: b);
      final c = await _mkInstance(db, parentId: d);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, greaterThanOrEqualTo(2));
      expect(await _parent(db, c), a);
    });

    // ── 6. Full mixed scenario from design discussion ─────────────────────────
    test(
        'A → B[orphan] → C → D[orphan] → E[orphan] → F → G → H[orphan]'
        '  →  C.parent=A, F.parent=C, G unchanged, H unchanged', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      final d = await _mkInstance(db, parentId: c);
      final e = await _mkInstance(db, parentId: d);
      final f = await _mkInstance(db, parentId: e);
      final g = await _mkInstance(db, parentId: f);
      final h = await _mkInstance(db, parentId: g);

      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);
      await _link(db, teamId, 3, f);
      await _link(db, teamId, 4, g);
      // B, D, E orphaned; H leaf orphan

      await repo.relinkOrphanedDescendants();

      expect(await _parent(db, c), a); // B skipped
      expect(await _parent(db, f), c); // D+E collapsed
      expect(await _parent(db, g), f); // G unchanged
      expect(await _parent(db, h), g); // H leaf — unchanged
    });

    // ── 7. Branching orphan ───────────────────────────────────────────────────
    test('A → B[orphan] → C1 and B → C2  →  both C1,C2 parent becomes A', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a  = await _mkInstance(db);
      final b  = await _mkInstance(db, parentId: a);
      final c1 = await _mkInstance(db, parentId: b);
      final c2 = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c1);
      await _link(db, teamId, 3, c2);

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 2);
      expect(await _parent(db, c1), a);
      expect(await _parent(db, c2), a);
    });

    // ── 8. Multiple independent chains ────────────────────────────────────────
    test('two separate chains each with an orphan — both fixed', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      // Chain 1: A → B[orphan] → C
      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      // Chain 2: X → Y[orphan] → Z
      final x = await _mkInstance(db);
      final y = await _mkInstance(db, parentId: x);
      final z = await _mkInstance(db, parentId: y);
      await _link(db, teamId, 3, x);
      await _link(db, teamId, 4, z);

      final relinked = await repo.relinkOrphanedDescendants();

      expect(relinked, 2);
      expect(await _parent(db, c), a);
      expect(await _parent(db, z), x);
    });

    // ── 9. Orphan with both linked and orphan children ────────────────────────
    test('B[orphan] has one linked child C and one orphan child D[orphan] → C → E'
        '  →  C.parent=A, E.parent=C, D.parent=A', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      //   A[linked]
      //   └─ B[orphan]
      //       ├─ C[linked]
      //       │   └─ E[linked]
      //       └─ D[orphan]  (leaf orphan, no further children)
      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      final e = await _mkInstance(db, parentId: c);
      final d = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);
      await _link(db, teamId, 3, e);
      // B, D orphaned

      await repo.relinkOrphanedDescendants();

      expect(await _parent(db, c), a); // C skips B → A
      expect(await _parent(db, e), c); // E unchanged
      expect(await _parent(db, d), a); // D (leaf orphan) skips B → A
    });

    // ── 10. Relink does not delete — orphans still exist after ────────────────
    test('relinkOrphanedDescendants does not delete any instances', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      await repo.relinkOrphanedDescendants();

      // B still exists — deletion is a separate cleanup step
      expect(await _allIds(db), containsAll([a, b, c]));
    });

    // ── 11. cleanup() runs relink then deletes orphans ────────────────────────
    test('cleanup() relinks then deletes orphans — B removed, C connected to A',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final c = await _mkInstance(db, parentId: b);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      await repo.cleanup();

      expect(await _allIds(db), containsAll([a, c]));
      expect(await _allIds(db), isNot(contains(b)));
      expect(await _parent(db, c), a);
    });

    // ── 12. Three consecutive orphans ─────────────────────────────────────────
    test('A → B[o] → D[o] → E[o] → C  →  C.parent becomes A after 3 passes',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DatabaseMaintenanceRepository(db);
      final teamId = await _mkTeam(db);

      final a = await _mkInstance(db);
      final b = await _mkInstance(db, parentId: a);
      final d = await _mkInstance(db, parentId: b);
      final e = await _mkInstance(db, parentId: d);
      final c = await _mkInstance(db, parentId: e);
      await _link(db, teamId, 1, a);
      await _link(db, teamId, 2, c);

      await repo.relinkOrphanedDescendants();

      expect(await _parent(db, c), a);
    });
  });
}
