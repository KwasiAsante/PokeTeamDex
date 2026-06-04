// Integration tests: repository-level CRUD operations with an in-memory database.
// These tests verify the full data layer without any widget or provider machinery.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';
import '../helpers/test_database.dart';

void main() {
  group('Folder CRUD', () {
    test('insert and watchAll returns the new folder', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamFolderRepository(db);

      await repo.insert(TeamFoldersCompanion(
        name: const Value('VGC'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final folders = await repo.getAll();
      expect(folders, hasLength(1));
      expect(folders.first.name, 'VGC');
    });

    test('update changes the folder name', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamFolderRepository(db);

      final id = await repo.insert(TeamFoldersCompanion(
        name: const Value('Old Name'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final folder = await repo.getById(id);
      await repo.update(folder.copyWith(name: 'New Name').toCompanion(true));

      final updated = await repo.getById(id);
      expect(updated.name, 'New Name');
    });

    test('delete removes the folder from the database', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamFolderRepository(db);

      final id = await repo.insert(TeamFoldersCompanion(
        name: const Value('Temporary'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await repo.delete(id);

      final folders = await repo.getAll();
      expect(folders, isEmpty);
    });

    test('getByRemoteId returns null when no match', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamFolderRepository(db);

      final result = await repo.getByRemoteId('nonexistent-id');
      expect(result, isNull);
    });

    test('getByRemoteId returns the folder with the matching remote id', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamFolderRepository(db);

      await repo.insert(TeamFoldersCompanion(
        name: const Value('Synced Folder'),
        remoteId: const Value('remote-42'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final result = await repo.getByRemoteId('remote-42');
      expect(result?.name, 'Synced Folder');
    });
  });

  group('Team CRUD', () {
    test('insert creates a team and getAll returns it', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamRepository(db);

      final now = DateTime.now();
      await repo.insert(TeamsCompanion(
        name: const Value('Sun Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final teams = await repo.getAll();
      expect(teams, hasLength(1));
      expect(teams.first.name, 'Sun Team');
    });

    test('team is inserted with correct folderId', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final folderRepo = TeamFolderRepository(db);
      final teamRepo = TeamRepository(db);

      final now = DateTime.now();
      final folderId = await folderRepo.insert(TeamFoldersCompanion(
        name: const Value('Competitive'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await teamRepo.insert(TeamsCompanion(
        name: const Value('Trick Room'),
        folderId: Value(folderId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final teams = await teamRepo.getAll();
      expect(teams.first.folderId, folderId);
    });

    test('updateFormatLabel changes the format label', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamRepository(db);

      final now = DateTime.now();
      final id = await repo.insert(TeamsCompanion(
        name: const Value('Format Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await repo.updateFormatLabel(id, 'vgc2024');

      final team = await repo.getById(id);
      expect(team.formatLabel, 'vgc2024');
    });

    test('delete removes the team', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamRepository(db);

      final now = DateTime.now();
      final id = await repo.insert(TeamsCompanion(
        name: const Value('Deletable'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await repo.delete(id);
      expect(await repo.getAll(), isEmpty);
    });

    test('getByRemoteId returns team with matching remoteId', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TeamRepository(db);

      final now = DateTime.now();
      await repo.insert(TeamsCompanion(
        name: const Value('Remote Team'),
        remoteId: const Value('srv-1'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final found = await repo.getByRemoteId('srv-1');
      expect(found?.name, 'Remote Team');
    });
  });

  group('Slot CRUD', () {
    test('insert creates a slot and getByTeam returns it', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final syncQueue = SyncQueueRepository(db);
      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      final now = DateTime.now();
      final teamId = await teamRepo.insert(TeamsCompanion(
        name: const Value('Slot Test Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(1),
        pokemonId: const Value(25), // pikachu
        level: const Value(50),
        ivHp:  const Value(31),
        ivAtk: const Value(31),
        ivDef: const Value(31),
        ivSpa: const Value(31),
        ivSpd: const Value(31),
        ivSpe: const Value(31),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final slots = await slotRepo.getByTeam(teamId);
      expect(slots, hasLength(1));
      expect(slots.first.pokemonId, 25);
      expect(slots.first.slot, 1);
      expect(slots.first.level, 50);
    });

    test('slot defaults IVs to 31 when inserted via addPokemonToSlot pattern', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final syncQueue = SyncQueueRepository(db);
      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      final now = DateTime.now();
      final teamId = await teamRepo.insert(TeamsCompanion(
        name: const Value('IV Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(1),
        pokemonId: const Value(1), // bulbasaur
        level: const Value(50),
        ivHp:  const Value(31),
        ivAtk: const Value(31),
        ivDef: const Value(31),
        ivSpa: const Value(31),
        ivSpd: const Value(31),
        ivSpe: const Value(31),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final slot = (await slotRepo.getByTeam(teamId)).first;
      expect(slot.ivHp, 31);
      expect(slot.ivAtk, 31);
      expect(slot.ivSpe, 31);
    });

    test('deleteAllForTeam removes every slot for the team', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final syncQueue = SyncQueueRepository(db);
      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      final now = DateTime.now();
      final teamId = await teamRepo.insert(TeamsCompanion(
        name: const Value('Delete All Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      for (var slot = 1; slot <= 3; slot++) {
        await slotRepo.insert(TeamSlotsCompanion(
          teamId: Value(teamId),
          slot: Value(slot),
          pokemonId: Value(slot),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }

      await slotRepo.deleteAllForTeam(teamId);

      expect(await slotRepo.getByTeam(teamId), isEmpty);
    });

    test('getByTeamAndSlot returns the correct slot', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final syncQueue = SyncQueueRepository(db);
      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      final now = DateTime.now();
      final teamId = await teamRepo.insert(TeamsCompanion(
        name: const Value('Slot Lookup Team'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(3),
        pokemonId: const Value(4), // charmander
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      final found = await slotRepo.getByTeamAndSlot(teamId, 3);
      expect(found?.pokemonId, 4);

      final notFound = await slotRepo.getByTeamAndSlot(teamId, 5);
      expect(notFound, isNull);
    });
  });

  group('Sync queue', () {
    test('enqueue adds a pending op and getPending returns it', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = SyncQueueRepository(db);

      await repo.enqueue(PendingSyncOpsCompanion(
        operation: const Value('create'),
        entityType: const Value('team_folder'),
        entityId: const Value(1),
        payload: const Value('{"name":"Test"}'),
        createdAt: Value(DateTime.now()),
      ));

      final ops = await repo.getPending();
      expect(ops, hasLength(1));
      expect(ops.first.operation, 'create');
      expect(ops.first.entityType, 'team_folder');
    });

    test('delete removes the pending op', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = SyncQueueRepository(db);

      await repo.enqueue(PendingSyncOpsCompanion(
        operation: const Value('create'),
        entityType: const Value('team'),
        entityId: const Value(1),
        payload: const Value('{}'),
        createdAt: Value(DateTime.now()),
      ));

      final opId = (await repo.getPending()).first.id;
      await repo.delete(opId);

      expect(await repo.getPending(), isEmpty);
    });

    test('markAttempted increments the attempt counter', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = SyncQueueRepository(db);

      await repo.enqueue(PendingSyncOpsCompanion(
        operation: const Value('create'),
        entityType: const Value('team'),
        entityId: const Value(1),
        payload: const Value('{}'),
        createdAt: Value(DateTime.now()),
      ));

      final op = (await repo.getPending()).first;
      await repo.markAttempted(op.id, op.attempts);

      final updated = (await repo.getPending()).first;
      expect(updated.attempts, 1);
    });
  });

  group('Full CRUD flow — folder → team → slot', () {
    test('creates folder, team, and slot; then verifies all relationships', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final syncQueue = SyncQueueRepository(db);
      final folderRepo = TeamFolderRepository(db);
      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      final now = DateTime.now();

      // 1 — create folder
      final folderId = await folderRepo.insert(TeamFoldersCompanion(
        name: const Value('Nationals'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // 2 — create team in that folder
      final teamId = await teamRepo.insert(TeamsCompanion(
        name: const Value('Masterball Tier'),
        folderId: Value(folderId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // 3 — add two slots
      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(1),
        pokemonId: const Value(483), // dialga
        level: const Value(50),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(2),
        pokemonId: const Value(484), // palkia
        level: const Value(50),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // Verify
      final folders = await folderRepo.getAll();
      expect(folders.single.name, 'Nationals');

      final teams = await teamRepo.getByFolder(folderId);
      expect(teams.single.name, 'Masterball Tier');

      final slots = await slotRepo.getByTeam(teamId);
      expect(slots, hasLength(2));
      expect(slots.map((s) => s.pokemonId), containsAll([483, 484]));
    });
  });
}
