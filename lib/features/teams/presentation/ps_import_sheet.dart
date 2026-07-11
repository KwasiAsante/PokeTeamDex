import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/logic/ps_form_resolver.dart';
import 'package:poke_team_dex/features/teams/logic/ps_import_parser.dart';
import 'package:poke_team_dex/features/teams/logic/ps_import_resolvers.dart';
import 'package:poke_team_dex/features/teams/presentation/format_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart' show setTeamIsBox;
import 'package:poke_team_dex/features/teams/services/ps_export_service.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';

Future<String?> _resolveFormName(
    dynamic repo, int basePokemonId, String psName) async {
  // Exceptions table — checked before the API call.
  final exception = applyPsFormExceptions(psName);
  if (exception != null) return exception;

  try {
    final species = await repo.fetchPokemonSpecies(basePokemonId);
    final varieties = species.varieties.map((v) => v.name).toList();
    return resolveFormFromVarieties(psName, varieties);
  } catch (_) {
    return null;
  }
}

/// Resolves the DV/IV value to store for a parsed PS stat entry, converting
/// PS's doubled 0–31 scale down to raw 0–15 DVs for Gen 1/2 (see
/// psIvToStored) and falling back to the gen-appropriate default when the
/// stat was omitted from the pasted export.
int _resolveIv(int? psIv, int? gen) =>
    psIv != null ? psIvToStored(psIv, gen) : psIvDefault(gen);

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
  final _nameCtrl = TextEditingController();
  GameFormat? _selectedFormat;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFormat() async {
    final result = await showModalBottomSheet<GameFormat?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormatPickerSheet(current: _selectedFormat?.id),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedFormat = isFormatCleared(result) ? null : result;
    });
  }

  Widget _buildOverrideFields(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Team Name',
              hintText: 'e.g. Sun Team · optional',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickFormat,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                _selectedFormat != null
                    ? _selectedFormat!.name
                    : 'No format · optional',
                style: textTheme.bodyMedium?.copyWith(
                  color: _selectedFormat != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parsed = parsePsTeam(text);
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
  Future<void> _importIntoTeam(PsTeam parsed, int teamId) async {
    final pokeRepo = ref.read(pokeApiRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);
    final configRepo = ref.read(appConfigRepositoryProvider);
    final now = DateTime.now();

    final team = await teamRepo.getById(teamId);
    final existing = await slotRepo.getByTeam(teamId);
    final maxBoxSize = await configRepo.getMaxBoxSize();
    final gen = await PsExportService.resolveGen(ref, team.formatLabel);

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
    final newSlotPositions = <int>[];
    int imported = 0;
    int skipped = 0;
    bool promoted = false;

    for (final rawSlot in parsed.slots) {
      final s = applyGenGates(rawSlot, gen);
      var slot = nextFree();

      // Auto-promote to box if we've exhausted the 6-slot team limit.
      if (slot > capacity && !isBox) {
        await setTeamIsBox(ref, teamId, isBox: true);
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
        // If the entry is a form variant (e.g. urshifu-rapid-strike whose
        // defaultFormLabel = "rapid-strike"), normalise to the base species
        // so pokemonSpeciesProvider can load varieties and form chips appear.
        if (entry.defaultFormLabel != null) {
          // Derive base name: prefer speciesName field, fall back to first
          // hyphen segment (covers entries where speciesName is null).
          final baseSN = entry.speciesName ?? entry.name.split('-').first;
          try {
            final base = await pokeRepo.fetchPokemonByNameOrDefault(baseSN);
            pokemonId = base.id;
            // If the resolved form entry IS the default variety (entry.id ==
            // base.id), leave formName null — the base pokemon already IS that
            // form, so no explicit chip selection is needed.
            resolvedFormName = (entry.id != base.id) ? entry.name : null;
          } catch (_) {
            pokemonId = entry.id; // fallback: keep form ID
            resolvedFormName = entry.name; // still record form even if base fetch failed
          }
        } else {
          pokemonId = entry.id;
        }
      } catch (_) {
        // For form-qualified PS names (e.g. "gastrodon-east", "ogerpon-wellspring")
        // whose /pokemon endpoint doesn't exist, look up the base species and
        // map the PS name to the closest PokéAPI variety name.
        if (s.species.contains('-')) {
          try {
            final base = await pokeRepo
                .fetchPokemonByNameOrDefault(s.species.split('-').first);
            pokemonId = base.id;
            final matched = await _resolveFormName(pokeRepo, base.id, s.species);
            if (matched != null) {
              resolvedFormName = matched;
            } else {
              // No variety match — check if the base pokemon's default form
              // IS the requested form (last-segment match against defaultFormLabel),
              // e.g. base = "maushold-family-of-four", PS = "maushold-four".
              // If so, formName = null (default chip selected). Otherwise fall
              // back to the PS name to cover cosmetic forms ("polteageist-antique").
              final baseLastSeg = base.defaultFormLabel?.split('-').last;
              final psLastSeg = s.species.split('-').last;
              resolvedFormName =
                  (baseLastSeg != null && baseLastSeg == psLastSeg) ? null : s.species;
            }
          } catch (_) {
            resolveErrors.add(s.species);
            continue;
          }
        } else {
          resolveErrors.add(s.species);
          continue;
        }
      }

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
        friendship: Value(s.friendship),
        hasGigantamax: Value(s.isGigantamax),
        teraType: Value(s.teraType),
        evHp:  Value(s.evs['hp']  ?? 0),
        evAtk: Value(s.evs['attack'] ?? 0),
        evDef: Value(s.evs['defense'] ?? 0),
        evSpa: Value(s.evs['special-attack'] ?? 0),
        evSpd: Value(s.evs['special-defense'] ?? 0),
        evSpe: Value(s.evs['speed'] ?? 0),
        ivHp:  Value(_resolveIv(s.ivs['hp'], gen)),
        ivAtk: Value(_resolveIv(s.ivs['attack'], gen)),
        ivDef: Value(_resolveIv(s.ivs['defense'], gen)),
        ivSpa: Value(_resolveIv(s.ivs['special-attack'], gen)),
        ivSpd: Value(_resolveIv(s.ivs['special-defense'], gen)),
        ivSpe: Value(_resolveIv(s.ivs['speed'], gen)),
        move1: Value(s.moves.isNotEmpty ? s.moves[0] : null),
        move2: Value(s.moves.length > 1 ? s.moves[1] : null),
        move3: Value(s.moves.length > 2 ? s.moves[2] : null),
        move4: Value(s.moves.length > 3 ? s.moves[3] : null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      newSlotPositions.add(slot);
      occupied.add(slot);
      imported++;
    }

    if (newSlotPositions.isNotEmpty) {
      final allSlots = await slotRepo.getByTeam(teamId);
      final toSave =
          allSlots.where((s) => newSlotPositions.contains(s.slot)).toList();
      await slotRepo.saveAll(toSave);
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
  Future<void> _importAsNewTeam(PsTeam parsed) async {
    final repo = ref.read(pokeApiRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final syncQueue = ref.read(syncQueueRepositoryProvider);
    final now = DateTime.now();

    // >6 Pokémon → import as a Box; ≤6 → regular team.
    final isBox = parsed.slots.length > 6;

    final teamName = resolveTeamName(_nameCtrl.text, parsed.name);
    final formatId = resolveFormatId(_selectedFormat, parsed.formatId);
    final gen = _selectedFormat?.gen ??
        await PsExportService.resolveGen(ref, formatId);

    final teamId = await teamRepo.insert(TeamsCompanion(
      name: Value(teamName),
      folderId: Value(widget.folderId),
      formatLabel: Value(formatId),
      isBox: Value(isBox),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    await syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('create'),
      entityType: const Value('team'),
      entityId: Value(teamId),
      payload: Value(jsonEncode({
        'name': teamName,
        'folder_local_id': widget.folderId,
        'format_label': formatId,
        'is_box': isBox,
      })),
      createdAt: Value(now),
    ));

    final errors = await _insertSlots(
      parsed: parsed,
      teamId: teamId,
      repo: repo,
      slotRepo: slotRepo,
      now: now,
      gen: gen,
    );

    final insertedSlots = await slotRepo.getByTeam(teamId);
    if (insertedSlots.isNotEmpty) await slotRepo.saveAll(insertedSlots);

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
    required PsTeam parsed,
    required int teamId,
    required dynamic repo,
    required dynamic slotRepo,
    required DateTime now,
    required int? gen,
  }) async {
    final errors = <String>[];

    for (int i = 0; i < parsed.slots.length; i++) {
      final s = applyGenGates(parsed.slots[i], gen);
      final slotNumber = i + 1;

      int? pokemonId;
      String? resolvedFormName;
      try {
        final entry = await repo.fetchPokemonByNameOrDefault(s.species);
        if (entry.defaultFormLabel != null) {
          final baseSN = entry.speciesName ?? entry.name.split('-').first;
          try {
            final base = await repo.fetchPokemonByNameOrDefault(baseSN);
            pokemonId = base.id;
            resolvedFormName = (entry.id != base.id) ? entry.name : null;
          } catch (_) {
            pokemonId = entry.id;
            resolvedFormName = entry.name;
          }
        } else {
          pokemonId = entry.id;
        }
      } catch (_) {
        if (s.species.contains('-')) {
          try {
            final base = await repo
                .fetchPokemonByNameOrDefault(s.species.split('-').first);
            pokemonId = base.id;
            final matched = await _resolveFormName(repo, base.id, s.species);
            if (matched != null) {
              resolvedFormName = matched;
            } else {
              final baseLastSeg = base.defaultFormLabel?.split('-').last;
              final psLastSeg = s.species.split('-').last;
              resolvedFormName =
                  (baseLastSeg != null && baseLastSeg == psLastSeg) ? null : s.species;
            }
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
        friendship: Value(s.friendship),
        hasGigantamax: Value(s.isGigantamax),
        teraType: Value(s.teraType),
        evHp:  Value(s.evs['hp']  ?? 0),
        evAtk: Value(s.evs['attack'] ?? 0),
        evDef: Value(s.evs['defense'] ?? 0),
        evSpa: Value(s.evs['special-attack'] ?? 0),
        evSpd: Value(s.evs['special-defense'] ?? 0),
        evSpe: Value(s.evs['speed'] ?? 0),
        ivHp:  Value(_resolveIv(s.ivs['hp'], gen)),
        ivAtk: Value(_resolveIv(s.ivs['attack'], gen)),
        ivDef: Value(_resolveIv(s.ivs['defense'], gen)),
        ivSpa: Value(_resolveIv(s.ivs['special-attack'], gen)),
        ivSpd: Value(_resolveIv(s.ivs['special-defense'], gen)),
        ivSpe: Value(_resolveIv(s.ivs['speed'], gen)),
        move1: Value(s.moves.isNotEmpty ? s.moves[0] : null),
        move2: Value(s.moves.length > 1 ? s.moves[1] : null),
        move3: Value(s.moves.length > 2 ? s.moves[2] : null),
        move4: Value(s.moves.length > 3 ? s.moves[3] : null),
        createdAt: Value(now),
        updatedAt: Value(now),
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
            if (widget.targetTeamId == null) _buildOverrideFields(context),
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
