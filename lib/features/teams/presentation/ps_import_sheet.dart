import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';

// ── Parser models ─────────────────────────────────────────────────────────────

class _PsSlot {
  final String species; // normalised PokéAPI name (e.g. charizard-mega-x)
  final String? nickname;
  final String? item;     // normalised (e.g. choice-scarf)
  final String? ability;  // normalised
  final int level;
  final bool isShiny;
  final String? gender;   // 'male' | 'female' | null
  final String? nature;   // lowercase (e.g. jolly)
  final Map<String, int> evs; // {pokeapi-stat-name: value}
  final Map<String, int> ivs;
  final List<String> moves; // normalised pokeapi names

  const _PsSlot({
    required this.species,
    this.nickname,
    this.item,
    this.ability,
    this.level = 100,
    this.isShiny = false,
    this.gender,
    this.nature,
    this.evs = const {},
    this.ivs = const {},
    this.moves = const [],
  });
}

class _PsTeam {
  final String name;
  final String? formatId; // e.g. "gen9ou"
  final List<_PsSlot> slots;
  const _PsTeam({required this.name, this.formatId, required this.slots});
}

// ── Parser ────────────────────────────────────────────────────────────────────

const _kStatMap = {
  'HP': 'hp', 'Atk': 'attack', 'Def': 'defense',
  'SpA': 'special-attack', 'SpD': 'special-defense', 'Spe': 'speed',
};

String _norm(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(' ', '-')
    .replaceAll("'", '')      // U+0027 ASCII apostrophe
    .replaceAll('\u2019', '') // U+2019 RIGHT SINGLE QUOTATION MARK (used by some PS clients)
    .replaceAll('\u02BC', ''); // U+02BC MODIFIER LETTER APOSTROPHE

_PsTeam _parseTeam(String text) {
  String teamName = 'Imported Team';
  String? formatId;

  // Strip === Team Name === header.
  final headerRe = RegExp(r'===\s*(?:\[([^\]]+)\]\s*)?(.+?)\s*===');
  final headerMatch = headerRe.firstMatch(text);
  if (headerMatch != null) {
    if (headerMatch.group(1) != null) {
      // "[gen9ou] My Team" → extract format and name
      final rawFmt = headerMatch.group(1)!.trim().toLowerCase().replaceAll(' ', '');
      formatId = rawFmt.isNotEmpty ? rawFmt : null;
    }
    if ((headerMatch.group(2) ?? '').isNotEmpty) {
      teamName = headerMatch.group(2)!.trim();
    }
    text = text.substring(headerMatch.end);
  }

  // Split into Pokémon blocks (separated by blank lines).
  final blocks = text
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  final slots = <_PsSlot>[];
  for (final block in blocks) {
    final slot = _parseBlock(block);
    if (slot != null) slots.add(slot);
  }

  return _PsTeam(name: teamName, formatId: formatId, slots: slots);
}

_PsSlot? _parseBlock(String block) {
  final lines =
      block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return null;

  // ── Line 0: [Nickname (Species)] [(M/F)] [@ Item] ─────────────────────────
  var first = lines[0];
  String? item;
  if (first.contains(' @ ')) {
    final idx = first.lastIndexOf(' @ ');
    item = _norm(first.substring(idx + 3).trim());
    first = first.substring(0, idx).trim();
  }

  String? gender;
  if (first.endsWith('(M)')) {
    gender = 'male';
    first = first.substring(0, first.length - 3).trim();
  } else if (first.endsWith('(F)')) {
    gender = 'female';
    first = first.substring(0, first.length - 3).trim();
  }

  String? nickname;
  String species;
  final parenMatch = RegExp(r'^(.*?)\(([^)]+)\)\s*$').firstMatch(first);
  if (parenMatch != null && parenMatch.group(1)!.trim().isNotEmpty) {
    nickname = parenMatch.group(1)!.trim();
    species = _norm(parenMatch.group(2)!.trim());
  } else if (parenMatch != null) {
    species = _norm(parenMatch.group(2)!.trim());
  } else {
    species = _norm(first.trim());
  }

  // ── Remaining lines ────────────────────────────────────────────────────────
  String? ability;
  int level = 100;
  bool isShiny = false;
  String? nature;
  final evs = <String, int>{};
  final ivs = <String, int>{};
  final moves = <String>[];

  for (int i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('Ability: ')) {
      ability = _norm(line.substring(9).trim());
    } else if (line.startsWith('Level: ')) {
      level = int.tryParse(line.substring(7).trim()) ?? 100;
    } else if (line.startsWith('Shiny: Yes')) {
      isShiny = true;
    } else if (line.startsWith('EVs: ')) {
      _parseStatLine(line.substring(5), evs);
    } else if (line.startsWith('IVs: ')) {
      _parseStatLine(line.substring(5), ivs);
    } else if (line.endsWith(' Nature')) {
      // Keep PS casing: "Sassy Nature" → "Sassy" (matches DropdownButton items).
      final raw = line.substring(0, line.length - 7).trim();
      nature = raw.isNotEmpty
          ? raw[0].toUpperCase() + raw.substring(1).toLowerCase()
          : null;
    } else if (line.startsWith('- ')) {
      // Strip Hidden Power type annotation: "Hidden Power [Ice]" → "hidden-power"
      var move = line.substring(2).trim();
      move = move.replaceAll(RegExp(r'\s*\[.*?\]'), '').trim();
      moves.add(_norm(move));
    }
  }

  if (species.isEmpty) return null;

  return _PsSlot(
    species: species,
    nickname: nickname,
    item: item,
    ability: ability,
    level: level,
    isShiny: isShiny,
    gender: gender,
    nature: nature,
    evs: evs,
    ivs: ivs,
    moves: moves.take(4).toList(),
  );
}

void _parseStatLine(String s, Map<String, int> target) {
  for (final part in s.split('/')) {
    final m = RegExp(r'(\d+)\s+(\w+)').firstMatch(part.trim());
    if (m != null) {
      final stat = _kStatMap[m.group(2)];
      if (stat != null) target[stat] = int.parse(m.group(1)!);
    }
  }
}

// ── Import sheet ──────────────────────────────────────────────────────────────

class PsImportSheet extends ConsumerStatefulWidget {
  /// When set, slots are imported directly into this team (replacing all
  /// existing slots) instead of creating a new team.
  final int? targetTeamId;

  /// Only used in the create-new-team flow (when [targetTeamId] is null).
  final int? folderId;

  const PsImportSheet({super.key, this.targetTeamId, this.folderId});

  @override
  ConsumerState<PsImportSheet> createState() => _PsImportSheetState();
}

class _PsImportSheetState extends ConsumerState<PsImportSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parsed = _parseTeam(text);
      if (parsed.slots.isEmpty) {
        setState(() {
          _error = 'No valid Pokémon found. Check the format and try again.';
          _loading = false;
        });
        return;
      }

      if (widget.targetTeamId != null) {
        await _importIntoTeam(parsed, widget.targetTeamId!);
      } else {
        await _importAsNewTeam(parsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Import failed: $e';
          _loading = false;
        });
      }
    }
  }

  /// Appends parsed Pokémon into empty slots on the existing team.
  ///
  /// If all 6 team slots fill up, the team is automatically promoted to a Box
  /// so remaining Pokémon can continue filling up to [maxBoxSize] slots.
  /// If the box is also at capacity, remaining Pokémon are skipped and the
  /// user is informed of the count.
  Future<void> _importIntoTeam(_PsTeam parsed, int teamId) async {
    final pokeRepo = ref.read(pokeApiRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);
    final syncQueue = ref.read(syncQueueRepositoryProvider);
    final configRepo = ref.read(appConfigRepositoryProvider);
    final now = DateTime.now();

    final team = await teamRepo.getById(teamId);
    final existing = await slotRepo.getByTeam(teamId);
    final maxBoxSize = await configRepo.getMaxBoxSize();

    final occupied = {for (final s in existing) s.slot};
    bool isBox = team.isBox;
    int capacity = isBox ? maxBoxSize : 6;

    // Returns the lowest unoccupied slot number, or capacity+1 if full.
    int nextFree() {
      for (var n = 1; n <= capacity; n++) {
        if (!occupied.contains(n)) return n;
      }
      return capacity + 1;
    }

    final resolveErrors = <String>[];
    int imported = 0;
    int skipped = 0;
    bool promoted = false;

    for (final s in parsed.slots) {
      var slot = nextFree();

      // Auto-promote to box if we've exhausted the 6-slot team limit.
      if (slot > capacity && !isBox) {
        await teamRepo.setIsBox(teamId, isBox: true);
        isBox = true;
        capacity = maxBoxSize;
        promoted = true;
        slot = nextFree();
      }

      if (slot > capacity) {
        skipped++;
        continue;
      }

      int? pokemonId;
      String? resolvedFormName;
      try {
        final entry = await pokeRepo.fetchPokemonByNameOrDefault(s.species);
        pokemonId = entry.id;
      } catch (_) {
        // For form-qualified PS names (e.g. "gastrodon-east"), fall back to
        // the base species and pre-set the form so the slot opens correctly.
        if (s.species.contains('-')) {
          try {
            final base = await pokeRepo
                .fetchPokemonByNameOrDefault(s.species.split('-').first);
            pokemonId = base.id;
            resolvedFormName = s.species;
          } catch (_) {
            resolveErrors.add(s.species);
            continue;
          }
        } else {
          resolveErrors.add(s.species);
          continue;
        }
      }

      const ivDefault = 31;
      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: Value(slot),
        pokemonId: Value(pokemonId),
        nickname: Value(s.nickname),
        heldItemName: Value(s.item),
        abilityName: Value(s.ability),
        natureName: Value(s.nature),
        level: Value(s.level.clamp(1, 100)),
        isShiny: Value(s.isShiny),
        gender: Value(s.gender),
        formName: Value(resolvedFormName),
        evHp:  Value(s.evs['hp']  ?? 0),
        evAtk: Value(s.evs['attack'] ?? 0),
        evDef: Value(s.evs['defense'] ?? 0),
        evSpa: Value(s.evs['special-attack'] ?? 0),
        evSpd: Value(s.evs['special-defense'] ?? 0),
        evSpe: Value(s.evs['speed'] ?? 0),
        ivHp:  Value(s.ivs['hp']  ?? ivDefault),
        ivAtk: Value(s.ivs['attack'] ?? ivDefault),
        ivDef: Value(s.ivs['defense'] ?? ivDefault),
        ivSpa: Value(s.ivs['special-attack'] ?? ivDefault),
        ivSpd: Value(s.ivs['special-defense'] ?? ivDefault),
        ivSpe: Value(s.ivs['speed'] ?? ivDefault),
        move1: Value(s.moves.isNotEmpty ? s.moves[0] : null),
        move2: Value(s.moves.length > 1 ? s.moves[1] : null),
        move3: Value(s.moves.length > 2 ? s.moves[2] : null),
        move4: Value(s.moves.length > 3 ? s.moves[3] : null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await syncQueue.enqueue(PendingSyncOpsCompanion(
        operation: const Value('upsert'),
        entityType: const Value('team_slot'),
        entityId: Value(teamId),
        payload: Value(jsonEncode({
          'team_local_id': teamId,
          'slot': slot,
          'pokemon_id': pokemonId,
          'nickname': s.nickname,
          'level': s.level.clamp(1, 100),
        })),
        createdAt: Value(now),
      ));

      occupied.add(slot);
      imported++;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final parts = <String>[];
    if (imported > 0) parts.add('Imported $imported Pokémon.');
    if (promoted) parts.add('Team promoted to Box.');
    if (skipped > 0) parts.add('$skipped skipped — box is full.');
    if (resolveErrors.isNotEmpty) {
      parts.add('${resolveErrors.length} not found: ${resolveErrors.join(', ')}.');
    }
    if (imported == 0 && skipped == 0 && resolveErrors.isEmpty) {
      parts.add('No empty slots.');
    }
    showAppSnackBar(context, parts.join(' '));
  }

  /// Creates a new team record and populates it with the parsed Pokémon.
  Future<void> _importAsNewTeam(_PsTeam parsed) async {
    final repo = ref.read(pokeApiRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final syncQueue = ref.read(syncQueueRepositoryProvider);
    final now = DateTime.now();

    // >6 Pokémon → import as a Box; ≤6 → regular team.
    final isBox = parsed.slots.length > 6;

    final teamId = await teamRepo.insert(TeamsCompanion(
      name: Value(parsed.name),
      folderId: Value(widget.folderId),
      formatLabel: Value(parsed.formatId),
      isBox: Value(isBox),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    await syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('create'),
      entityType: const Value('team'),
      entityId: Value(teamId),
      payload: Value(jsonEncode({
        'name': parsed.name,
        'folder_local_id': widget.folderId,
        'format_label': parsed.formatId,
      })),
      createdAt: Value(now),
    ));

    final errors = await _insertSlots(
      parsed: parsed,
      teamId: teamId,
      repo: repo,
      slotRepo: slotRepo,
      syncQueue: syncQueue,
      now: now,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (errors.isNotEmpty) {
      showAppSnackBar(
        context,
        '${isBox ? 'Box' : 'Team'} imported with ${errors.length} skipped slot(s):\n${errors.join('\n')}',
      );
    } else if (isBox) {
      showAppSnackBar(context,
          'Imported as a Box (${parsed.slots.length} Pokémon).');
    }

    context.push('/teams/$teamId');
  }

  /// Inserts parsed slots into [teamId] and returns a list of error messages
  /// for any Pokémon that could not be resolved.
  Future<List<String>> _insertSlots({
    required _PsTeam parsed,
    required int teamId,
    required dynamic repo,
    required dynamic slotRepo,
    required dynamic syncQueue,
    required DateTime now,
  }) async {
    final errors = <String>[];
    const ivDefault = 31;

    for (int i = 0; i < parsed.slots.length; i++) {
      final s = parsed.slots[i];
      final slotNumber = i + 1;

      int? pokemonId;
      String? resolvedFormName;
      try {
        final entry = await repo.fetchPokemonByNameOrDefault(s.species);
        pokemonId = entry.id;
      } catch (_) {
        if (s.species.contains('-')) {
          try {
            final base = await repo
                .fetchPokemonByNameOrDefault(s.species.split('-').first);
            pokemonId = base.id;
            resolvedFormName = s.species;
          } catch (_) {
            errors.add('Could not find Pokémon "${s.species}"');
            continue;
          }
        } else {
          errors.add('Could not find Pokémon "${s.species}"');
          continue;
        }
      }

      await slotRepo.insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: Value(slotNumber),
        pokemonId: Value(pokemonId!),
        nickname: Value(s.nickname),
        heldItemName: Value(s.item),
        abilityName: Value(s.ability),
        natureName: Value(s.nature),
        level: Value(s.level.clamp(1, 100)),
        isShiny: Value(s.isShiny),
        gender: Value(s.gender),
        formName: Value(resolvedFormName),
        evHp:  Value(s.evs['hp']  ?? 0),
        evAtk: Value(s.evs['attack'] ?? 0),
        evDef: Value(s.evs['defense'] ?? 0),
        evSpa: Value(s.evs['special-attack'] ?? 0),
        evSpd: Value(s.evs['special-defense'] ?? 0),
        evSpe: Value(s.evs['speed'] ?? 0),
        ivHp:  Value(s.ivs['hp']  ?? ivDefault),
        ivAtk: Value(s.ivs['attack'] ?? ivDefault),
        ivDef: Value(s.ivs['defense'] ?? ivDefault),
        ivSpa: Value(s.ivs['special-attack'] ?? ivDefault),
        ivSpd: Value(s.ivs['special-defense'] ?? ivDefault),
        ivSpe: Value(s.ivs['speed'] ?? ivDefault),
        move1: Value(s.moves.isNotEmpty ? s.moves[0] : null),
        move2: Value(s.moves.length > 1 ? s.moves[1] : null),
        move3: Value(s.moves.length > 2 ? s.moves[2] : null),
        move4: Value(s.moves.length > 3 ? s.moves[3] : null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      await syncQueue.enqueue(PendingSyncOpsCompanion(
        operation: const Value('upsert'),
        entityType: const Value('team_slot'),
        entityId: Value(teamId),
        payload: Value(jsonEncode({
          'team_local_id': teamId,
          'slot': slotNumber,
          'pokemon_id': pokemonId,
          'nickname': s.nickname,
          'level': s.level.clamp(1, 100),
        })),
        createdAt: Value(now),
      ));
    }

    return errors;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.targetTeamId != null
                          ? 'Import into Team'
                          : 'Import from Showdown',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.targetTeamId != null
                    ? 'Paste a Showdown export below. Pokémon will fill empty slots; the team auto-promotes to a Box if needed.'
                    : 'Paste a Pokémon Showdown team export below.',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 12,
                  minLines: 8,
                  decoration: InputDecoration(
                    hintText:
                        'Charizard-Mega-X @ Charizardite X\nAbility: Tough Claws\nEVs: 252 Atk / 4 SpD / 252 Spe\nJolly Nature\n- Flare Blitz\n- Dragon Claw\n...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(_error!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _import,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label:
                        Text(_loading ? 'Importing…' : 'Import'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
