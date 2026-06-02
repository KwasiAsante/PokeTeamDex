import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';

// ── Folders ───────────────────────────────────────────────────────────────────

final foldersProvider = StreamProvider<List<TeamFolder>>((ref) {
  return ref.watch(teamFolderRepositoryProvider).watchAll();
});

// ── Teams ─────────────────────────────────────────────────────────────────────

final allTeamsProvider = StreamProvider<List<Team>>((ref) {
  return ref.watch(teamRepositoryProvider).watchAll();
});

final teamsByFolderProvider =
    StreamProvider.family<List<Team>, int>((ref, folderId) {
  return ref.watch(teamRepositoryProvider).watchByFolder(folderId);
});

// ── Pokemon ↔ Teams cross-reference ──────────────────────────────────────────

/// Emits all (Team, TeamSlot) pairs for a given pokemonId — i.e. every slot
/// across every team that contains this Pokémon. Updates live when slots change.
final teamsForPokemonProvider =
    StreamProvider.autoDispose.family<List<(Team, TeamSlot)>, int>((ref, pokemonId) {
  final slotRepo = ref.read(teamSlotRepositoryProvider);
  final teamRepo = ref.read(teamRepositoryProvider);

  return slotRepo.watchByPokemonId(pokemonId).asyncMap((slots) async {
    final pairs = <(Team, TeamSlot)>[];
    for (final slot in slots) {
      try {
        final team = await teamRepo.getById(slot.teamId);
        if (!team.isDeleted) pairs.add((team, slot));
      } catch (_) {
        // team was deleted locally but slot record hasn't been cleaned yet
      }
    }
    return pairs;
  });
});

// ── Actions ───────────────────────────────────────────────────────────────────

Future<void> createFolder(WidgetRef ref, String name) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final localId = await repo.insert(
    TeamFoldersCompanion(
      name: Value(name),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('create'),
    entityType: const Value('team_folder'),
    entityId: Value(localId),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> renameFolder(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.update(
    TeamFoldersCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team_folder'),
    entityId: Value(id),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> deleteFolder(WidgetRef ref, int id) async {
  final repo = ref.read(teamFolderRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  // Capture remoteId before deleting locally
  final folder = await repo.getById(id);
  await repo.delete(id);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('delete'),
    entityType: const Value('team_folder'),
    entityId: Value(id),
    payload: Value(jsonEncode({'remote_id': folder.remoteId})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<int> createTeam(
  WidgetRef ref,
  String name, {
  int? folderId,
  String? formatLabel,
}) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final localId = await repo.insert(
    TeamsCompanion(
      name: Value(name),
      folderId: Value(folderId),
      formatLabel: Value(formatLabel),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('create'),
    entityType: const Value('team'),
    entityId: Value(localId),
    payload: Value(jsonEncode({
      'name': name,
      'folder_local_id': folderId,
      'format_label': formatLabel,
    })),
    createdAt: Value(DateTime.now()),
  ));

  return localId;
}

Future<void> updateTeamFormat(WidgetRef ref, int id, String? formatLabel) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.updateFormatLabel(id, formatLabel);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'format_label': formatLabel})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> renameTeam(WidgetRef ref, int id, String name) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.update(
    TeamsCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'name': name})),
    createdAt: Value(DateTime.now()),
  ));
}

Future<void> moveTeamToFolder(
    WidgetRef ref, int teamId, int? folderId) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  await repo.update(
    TeamsCompanion(
      id: Value(teamId),
      folderId: Value(folderId),
      updatedAt: Value(DateTime.now()),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('update'),
    entityType: const Value('team'),
    entityId: Value(teamId),
    // Use the 'folder_local_id' key to signal a folder change to _buildOp.
    // null value means "move to ungrouped".
    payload: Value(jsonEncode({'folder_local_id': folderId})),
    createdAt: Value(DateTime.now()),
  ));
}

/// Deep-copies a team and all its slots into a new team named "[name] (Copy)".
Future<void> duplicateTeam(WidgetRef ref, int teamId) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final slotRepo = ref.read(teamSlotRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final original = await teamRepo.getById(teamId);
  final slots = await slotRepo.getByTeam(teamId);
  final now = DateTime.now();

  final newTeamId = await teamRepo.insert(
    TeamsCompanion(
      name: Value('${original.name} (Copy)'),
      folderId: Value(original.folderId),
      formatLabel: Value(original.formatLabel),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('create'),
    entityType: const Value('team'),
    entityId: Value(newTeamId),
    payload: Value(jsonEncode({
      'name': '${original.name} (Copy)',
      'folder_local_id': original.folderId,
      'format_label': original.formatLabel,
    })),
    createdAt: Value(now),
  ));

  for (final slot in slots) {
    await slotRepo.insert(TeamSlotsCompanion(
      teamId: Value(newTeamId),
      slot: Value(slot.slot),
      pokemonId: Value(slot.pokemonId),
      nickname: Value(slot.nickname),
      formName: Value(slot.formName),
      level: Value(slot.level),
      gender: Value(slot.gender),
      isShiny: Value(slot.isShiny),
      friendship: Value(slot.friendship),
      abilityName: Value(slot.abilityName),
      natureName: Value(slot.natureName),
      heldItemName: Value(slot.heldItemName),
      move1: Value(slot.move1),
      move2: Value(slot.move2),
      move3: Value(slot.move3),
      move4: Value(slot.move4),
      evHp: Value(slot.evHp),
      evAtk: Value(slot.evAtk),
      evDef: Value(slot.evDef),
      evSpa: Value(slot.evSpa),
      evSpd: Value(slot.evSpd),
      evSpe: Value(slot.evSpe),
      ivHp: Value(slot.ivHp),
      ivAtk: Value(slot.ivAtk),
      ivDef: Value(slot.ivDef),
      ivSpa: Value(slot.ivSpa),
      ivSpd: Value(slot.ivSpd),
      ivSpe: Value(slot.ivSpe),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    await syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('upsert'),
      entityType: const Value('team_slot'),
      entityId: Value(newTeamId),
      payload: Value(jsonEncode({
        'team_local_id': newTeamId,
        'slot': slot.slot,
        'pokemon_id': slot.pokemonId,
        'nickname': slot.nickname,
        'level': slot.level ?? 50,
      })),
      createdAt: Value(now),
    ));
  }
}

Future<void> deleteTeam(WidgetRef ref, int id) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final team = await repo.getById(id);
  await repo.delete(id);

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('delete'),
    entityType: const Value('team'),
    entityId: Value(id),
    payload: Value(jsonEncode({'remote_id': team.remoteId})),
    createdAt: Value(DateTime.now()),
  ));
}

/// Inserts or replaces a slot in [teamId] at position [slot] with [pokemonId].
/// Uses Gen III+ stat defaults (level 50, IVs 31). Queues a sync op.
/// Callers should handle replacement confirmation before calling this.
Future<void> addPokemonToSlot(
  WidgetRef ref, {
  required int teamId,
  required int slot,
  required int pokemonId,
}) async {
  final slotRepo = ref.read(teamSlotRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final existing = await slotRepo.getByTeamAndSlot(teamId, slot);
  final now = DateTime.now();

  if (existing != null) {
    await slotRepo.update(
      TeamSlotsCompanion(
        id: Value(existing.id),
        pokemonId: Value(pokemonId),
        // Clear slot-config fields so they don't carry over from the old Pokémon
        nickname: const Value.absent(),
        abilityName: const Value.absent(),
        natureName: const Value.absent(),
        heldItemName: const Value.absent(),
        move1: const Value.absent(),
        move2: const Value.absent(),
        move3: const Value.absent(),
        move4: const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  } else {
    await slotRepo.insert(
      TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: Value(slot),
        pokemonId: Value(pokemonId),
        level: const Value(50),
        ivHp: const Value(31),
        ivAtk: const Value(31),
        ivDef: const Value(31),
        ivSpa: const Value(31),
        ivSpd: const Value(31),
        ivSpe: const Value(31),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('upsert'),
    entityType: const Value('team_slot'),
    entityId: Value(teamId),
    payload: Value(jsonEncode({
      'team_local_id': teamId,
      'slot': slot,
      'pokemon_id': pokemonId,
      'level': 50,
    })),
    createdAt: Value(now),
  ));
}
