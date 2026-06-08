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
  bool isBox = false,
}) async {
  final repo = ref.read(teamRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final localId = await repo.insert(
    TeamsCompanion(
      name: Value(name),
      folderId: Value(folderId),
      formatLabel: Value(formatLabel),
      isBox: Value(isBox),
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

  // Use updateFolder() instead of update()/replace() — replace() requires all
  // non-nullable columns to be present and would fail with absent name.
  await repo.updateFolder(teamId, folderId);

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
  final slotRepo = ref.read(teamSlotRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);

  final team = await repo.getById(id);
  // Delete slots first — team row deletion doesn't cascade in SQLite.
  await slotRepo.deleteAllForTeam(id);
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
/// Copies [source] to [targetTeamId] at [targetSlotPosition], optionally
/// deleting the source slot afterwards (move semantics when [deleteSource] is true).
/// If the target position is already occupied, it is overwritten.
Future<void> copySlotToTeam(
  WidgetRef ref, {
  required TeamSlot source,
  required int targetTeamId,
  required int targetSlotPosition,
  required bool deleteSource,
}) async {
  final slotRepo = ref.read(teamSlotRepositoryProvider);
  final syncQueue = ref.read(syncQueueRepositoryProvider);
  final now = DateTime.now();

  // Overwrite any existing slot at the target position.
  final existing = await slotRepo.getByTeamAndSlot(targetTeamId, targetSlotPosition);
  if (existing != null) {
    await slotRepo.deleteSlot(targetTeamId, targetSlotPosition);
  }

  final newSlotId = await slotRepo.insert(TeamSlotsCompanion(
    teamId: Value(targetTeamId),
    slot: Value(targetSlotPosition),
    pokemonId: Value(source.pokemonId),
    nickname: Value(source.nickname),
    formName: Value(source.formName),
    level: Value(source.level),
    gender: Value(source.gender),
    isShiny: Value(source.isShiny),
    friendship: Value(source.friendship),
    abilityName: Value(source.abilityName),
    natureName: Value(source.natureName),
    heldItemName: Value(source.heldItemName),
    move1: Value(source.move1),
    move2: Value(source.move2),
    move3: Value(source.move3),
    move4: Value(source.move4),
    evHp: Value(source.evHp),
    evAtk: Value(source.evAtk),
    evDef: Value(source.evDef),
    evSpa: Value(source.evSpa),
    evSpd: Value(source.evSpd),
    evSpe: Value(source.evSpe),
    ivHp: Value(source.ivHp),
    ivAtk: Value(source.ivAtk),
    ivDef: Value(source.ivDef),
    ivSpa: Value(source.ivSpa),
    ivSpd: Value(source.ivSpd),
    ivSpe: Value(source.ivSpe),
    isMegaEvolved: Value(source.isMegaEvolved),
    hasGigantamax: Value(source.hasGigantamax),
    gigantamaxEnabled: Value(source.gigantamaxEnabled),
    isAlpha: Value(source.isAlpha),
    ribbons: Value(source.ribbons),
    contestCool: Value(source.contestCool),
    contestBeautiful: Value(source.contestBeautiful),
    contestCute: Value(source.contestCute),
    contestClever: Value(source.contestClever),
    contestTough: Value(source.contestTough),
    contestSheen: Value(source.contestSheen),
    createdAt: Value(now),
    updatedAt: Value(now),
  ));

  await syncQueue.enqueue(PendingSyncOpsCompanion(
    operation: const Value('upsert'),
    entityType: const Value('team_slot'),
    entityId: Value(newSlotId),
    payload: Value(jsonEncode({
      'team_local_id': targetTeamId,
      'slot': targetSlotPosition,
      'pokemon_id': source.pokemonId,
      if (source.nickname != null && source.nickname!.isNotEmpty)
        'nickname': source.nickname,
      if (source.formName != null) 'form_name': source.formName,
      'level': source.level ?? 50,
      if (source.gender != null) 'gender': source.gender,
      'is_shiny': source.isShiny,
      if (source.friendship != null) 'friendship': source.friendship,
      if (source.abilityName != null) 'ability_name': source.abilityName,
      if (source.natureName != null) 'nature_name': source.natureName,
      if (source.heldItemName != null) 'held_item_name': source.heldItemName,
      if (source.move1 != null) 'move1': source.move1,
      if (source.move2 != null) 'move2': source.move2,
      if (source.move3 != null) 'move3': source.move3,
      if (source.move4 != null) 'move4': source.move4,
      'ev_hp': source.evHp, 'ev_atk': source.evAtk, 'ev_def': source.evDef,
      'ev_spa': source.evSpa, 'ev_spd': source.evSpd, 'ev_spe': source.evSpe,
      'iv_hp': source.ivHp, 'iv_atk': source.ivAtk, 'iv_def': source.ivDef,
      'iv_spa': source.ivSpa, 'iv_spd': source.ivSpd, 'iv_spe': source.ivSpe,
      if (source.ribbons != null) 'ribbons': source.ribbons,
      'is_mega_evolved': source.isMegaEvolved,
      'has_gigantamax': source.hasGigantamax,
      'gigantamax_enabled': source.gigantamaxEnabled,
      'is_alpha': source.isAlpha,
      'contest_cool': source.contestCool,
      'contest_beautiful': source.contestBeautiful,
      'contest_cute': source.contestCute,
      'contest_clever': source.contestClever,
      'contest_tough': source.contestTough,
      'contest_sheen': source.contestSheen,
    })),
    createdAt: Value(now),
  ));

  if (deleteSource) {
    await slotRepo.deleteSlot(source.teamId, source.slot);
  }
}

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
