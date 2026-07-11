// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/features/teams/data/dynamax_data.dart';
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
import 'package:poke_team_dex/features/teams/presentation/format_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/presentation/ps_import_sheet.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_config_screen.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/features/teams/presentation/move_copy_slot_sheet.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/features/teams/services/ps_export_service.dart';
import 'package:poke_team_dex/features/teams/services/showdown_export.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

// ── Stat calculator (Gen III+ formula) ───────────────────────────────────────

const _kNatureModifiers = <String, (String?, String?)>{
  'hardy': (null, null), 'docile': (null, null), 'serious': (null, null),
  'bashful': (null, null), 'quirky': (null, null),
  'lonely': ('attack', 'defense'), 'brave': ('attack', 'speed'),
  'adamant': ('attack', 'special-attack'), 'naughty': ('attack', 'special-defense'),
  'bold': ('defense', 'attack'), 'relaxed': ('defense', 'speed'),
  'impish': ('defense', 'special-attack'), 'lax': ('defense', 'special-defense'),
  'timid': ('speed', 'attack'), 'hasty': ('speed', 'defense'),
  'jolly': ('speed', 'special-attack'), 'naive': ('speed', 'special-defense'),
  'modest': ('special-attack', 'attack'), 'mild': ('special-attack', 'defense'),
  'quiet': ('special-attack', 'speed'), 'rash': ('special-attack', 'special-defense'),
  'calm': ('special-defense', 'attack'), 'gentle': ('special-defense', 'defense'),
  'sassy': ('special-defense', 'speed'), 'careful': ('special-defense', 'special-attack'),
};

int _calcHP(int base, int iv, int ev, int level) =>
    ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + level + 10;

int _calcStat(int base, int iv, int ev, int level, double mod) {
  return (((2 * base + iv + ev ~/ 4) * level) ~/ 100 + 5) * mod ~/ 1;
}

double _natureMod(String? nature, String key) {
  if (nature == null) return 1.0;
  final m = _kNatureModifiers[nature.toLowerCase()];
  if (m == null) return 1.0;
  if (m.$1 == key) return 1.1;
  if (m.$2 == key) return 0.9;
  return 1.0;
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _TeamAction {
  rename,
  changeFormat,
  importShowdown,
  saveAll,
  exportShowdown,
  promoteToBox,
  demoteToTeam,
  delete,
}

class TeamDetailScreen extends ConsumerStatefulWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  int? _selectedSlot;
  final _canCloseNotifier = ValueNotifier<Future<bool> Function()?>(null);

  // ── Multi-select state ────────────────────────────────────────────────────
  final Set<int> _selectedSlotIds = {};
  bool get _isMultiSelect => _selectedSlotIds.isNotEmpty;

  void _enterMultiSelect(TeamSlot slot) =>
      setState(() => _selectedSlotIds.add(slot.id));

  void _toggleSlotSelection(TeamSlot slot) => setState(() {
        if (!_selectedSlotIds.remove(slot.id)) _selectedSlotIds.add(slot.id);
      });

  void _clearSelection() => setState(() => _selectedSlotIds.clear());

  Future<void> _deleteSelected(List<TeamSlot> allSlots) async {
    final toDelete =
        allSlots.where((s) => _selectedSlotIds.contains(s.id)).toList();
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    for (final s in toDelete) {
      await slotRepo.deleteSlotWithQueue(s.teamId, s.slot, s.id);
    }
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    await instanceRepo.relinkOrphanedChain();
    await instanceRepo.deleteOrphanedInstances();
    _clearSelection();
    if (mounted) {
      showAppSnackBar(
          context, 'Deleted ${toDelete.length} Pokémon from team.');
    }
  }

  Future<void> _copyOrMoveSelected(
      List<TeamSlot> allSlots, bool deleteSource) async {
    final selected =
        allSlots.where((s) => _selectedSlotIds.contains(s.id)).toList();
    await showMoveCopySlotSheet(
      context,
      ref,
      sourceSlots: selected,
      deleteSource: deleteSource,
    );
    if (mounted) _clearSelection();
  }

  @override
  void dispose() {
    _canCloseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 840;
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final slotsAsync = ref.watch(teamSlotsProvider(widget.teamId));
    final maxBoxSize = ref.watch(maxBoxSizeProvider).asData?.value ?? 60;

    // Reset selected slot when switching to narrow layout
    if (!isWide && _selectedSlot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSlot = null);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Multi-select takes priority: back exits selection mode, not the screen.
        if (_isMultiSelect) {
          _clearSelection();
          return;
        }
        final canClose = _canCloseNotifier.value;
        if (canClose == null) {
          // No embedded slot config open — allow back normally.
          if (mounted) context.pop();
          return;
        }
        final ok = await canClose();
        if (ok && mounted) context.pop();
      },
      child: teamAsync.when(
        loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
        error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(error: e)),
        data: (team) {
          if (team == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.canPop()) context.pop();
            });
            return const Scaffold(body: LoadingState());
          }

          final slots = slotsAsync.asData?.value ?? [];

          return Scaffold(
            appBar: _isMultiSelect
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear selection',
                      onPressed: _clearSelection,
                    ),
                    title: Text('${_selectedSlotIds.length} selected'),
                  )
                : AppBar(
                    title: _TeamAppBarTitle(team: team),
                    actions: isWide
                        ? [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Rename',
                              onPressed: () => _renameTeam(context, team),
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune_outlined),
                              tooltip: 'Change format',
                              onPressed: () => _editFormat(context, team),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_outlined),
                              tooltip: 'Import from Showdown',
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) =>
                                    PsImportSheet(targetTeamId: widget.teamId),
                              ),
                            ),
                            if (slots.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.save_rounded),
                                tooltip: 'Save all slots',
                                onPressed: () =>
                                    _saveAllSlots(context, slots, team),
                              ),
                              IconButton(
                                icon: const Icon(Icons.upload_outlined),
                                tooltip: 'Export to Showdown',
                                onPressed: () =>
                                    _exportShowdown(context, slots, team),
                              ),
                            ],
                            IconButton(
                              icon: Icon(team.isBox
                                  ? Icons.groups_outlined
                                  : Icons.inventory_2_outlined),
                              tooltip: team.isBox
                                  ? 'Demote to Team'
                                  : 'Promote to Box',
                              onPressed: () => team.isBox
                                  ? _demoteToTeam(context, team, slots)
                                  : _promoteToBox(context, team),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete team',
                              onPressed: () => _deleteTeam(context, team),
                            ),
                            const ConnectivityStatusButton(),
                            const SettingsButton(),
                          ]
                        : [
                            const ConnectivityStatusButton(),
                            const SettingsButton(),
                            PopupMenuButton<_TeamAction>(
                              onSelected: (action) => _handleTeamAction(
                                  context, action, slots, team),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: _TeamAction.rename,
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Rename'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: _TeamAction.changeFormat,
                                  child: ListTile(
                                    leading: Icon(Icons.tune_outlined),
                                    title: Text('Change format'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: _TeamAction.importShowdown,
                                  child: ListTile(
                                    leading: Icon(Icons.download_outlined),
                                    title: Text('Import from Showdown'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                if (slots.isNotEmpty) ...[
                                  const PopupMenuItem(
                                    value: _TeamAction.saveAll,
                                    child: ListTile(
                                      leading: Icon(Icons.save_rounded),
                                      title: Text('Save all slots'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _TeamAction.exportShowdown,
                                    child: ListTile(
                                      leading: Icon(Icons.upload_outlined),
                                      title: Text('Export to Showdown'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                                PopupMenuItem(
                                  value: team.isBox
                                      ? _TeamAction.demoteToTeam
                                      : _TeamAction.promoteToBox,
                                  child: ListTile(
                                    leading: Icon(team.isBox
                                        ? Icons.groups_outlined
                                        : Icons.inventory_2_outlined),
                                    title: Text(team.isBox
                                        ? 'Demote to Team'
                                        : 'Promote to Box'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: _TeamAction.delete,
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    title: Text('Delete team',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                  ),
            bottomNavigationBar: _isMultiSelect
                ? _MultiSelectBar(
                    selectedCount: _selectedSlotIds.length,
                    onDelete: () => _deleteSelected(slots),
                    onCopy: () => _copyOrMoveSelected(slots, false),
                    onMove: () => _copyOrMoveSelected(slots, true),
                  )
                : null,
            body: slotsAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e),
              data: (slots) {
                final maxSlots = (team.isBox) ? maxBoxSize : 6;
                return isWide
                    ? _buildWideLayout(slots, team, maxSlots)
                    : _SlotList(
                        teamId: widget.teamId,
                        slots: slots,
                        formatId: team.formatLabel,
                        maxSlots: maxSlots,
                        selectedSlotIds: _selectedSlotIds,
                        isMultiSelect: _isMultiSelect,
                        onEnterMultiSelect: _enterMultiSelect,
                        onToggleSlot: _toggleSlotSelection,
                      );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(List<TeamSlot> slots, Team team, int maxSlots) {
    return Row(
      children: [
        Semantics(
          container: true,
          label: 'Team slots',
          child: SizedBox(
            width: 380,
            child: _SlotList(
              teamId: widget.teamId,
              slots: slots,
              formatId: team.formatLabel,
              selectedSlot: _selectedSlot,
              maxSlots: maxSlots,
              selectedSlotIds: _selectedSlotIds,
              isMultiSelect: _isMultiSelect,
              onEnterMultiSelect: _enterMultiSelect,
              onToggleSlot: _toggleSlotSelection,
              onSlotTap: (slotNumber) {
                _canCloseNotifier.value = null;
                setState(() => _selectedSlot = slotNumber);
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: Semantics(
            container: true,
            label: 'Slot configuration',
            child: _selectedSlot == null
                ? const EmptyState(
                    icon: Icons.tune_outlined,
                    title: 'Select a slot to configure',
                    subtitle:
                        'Tap a Pokémon in your team to edit its details here.',
                  )
                : SlotConfigScreen(
                    key: ValueKey(_selectedSlot),
                    teamId: widget.teamId,
                    slotNumber: _selectedSlot!,
                    embedded: true,
                    onClose: () {
                      _canCloseNotifier.value = null;
                      setState(() => _selectedSlot = null);
                    },
                    canCloseNotifier: _canCloseNotifier,
                  ),
          ),
        ),
      ],
    );
  }

  void _handleTeamAction(
    BuildContext context,
    _TeamAction action,
    List<TeamSlot> slots,
    Team team,
  ) {
    switch (action) {
      case _TeamAction.rename:
        _renameTeam(context, team);
      case _TeamAction.changeFormat:
        _editFormat(context, team);
      case _TeamAction.importShowdown:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => PsImportSheet(targetTeamId: widget.teamId),
        );
      case _TeamAction.saveAll:
        _saveAllSlots(context, slots, team);
      case _TeamAction.exportShowdown:
        _exportShowdown(context, slots, team);
      case _TeamAction.promoteToBox:
        _promoteToBox(context, team);
      case _TeamAction.demoteToTeam:
        _demoteToTeam(context, team, slots);
      case _TeamAction.delete:
        _deleteTeam(context, team);
    }
  }

  Future<void> _saveAllSlots(
      BuildContext context, List<TeamSlot> slots, Team team) async {
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final count = await slotRepo.saveAll(slots);
    // Best-effort PS export — runs after the DB write succeeds.
    await PsExportService.maybeExportTeam(ref: ref, team: team, slots: slots);
    if (context.mounted) {
      showAppSnackBar(context, 'Saved $count slot${count == 1 ? '' : 's'}.');
    }
  }

  Future<void> _exportShowdown(
      BuildContext context, List<TeamSlot> slots, Team team) async {
    final pokeApi = ref.read(pokeApiRepositoryProvider);
    try {
      final text = await buildShowdownExport(
        slots, pokeApi,
        teamName: team.name,
        formatLabel: team.formatLabel, // raw format id → PS format lookup
      );
      await Clipboard.setData(ClipboardData(text: text));
      HapticFeedback.lightImpact();
      if (context.mounted) {
        showAppSnackBar(context, 'Showdown export copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Export failed — try again', isError: true);
      }
    }
  }

  Future<void> _editFormat(BuildContext context, Team team) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormatPickerSheet(current: team.formatLabel),
    );
    if (result == null) return;
    final newLabel = isFormatCleared(result) ? null : (result as GameFormat).id;
    await updateTeamFormat(ref, team.id, newLabel);
  }

  Future<void> _renameTeam(BuildContext context, Team team) async {
    final controller = TextEditingController(text: team.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Team'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await renameTeam(ref, team.id, name);
  }

  Future<void> _deleteTeam(BuildContext context, Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Delete "${team.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteTeam(ref, team.id);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _promoteToBox(BuildContext context, Team team) async {
    await setTeamIsBox(ref, team.id, isBox: true);
    if (context.mounted) showAppSnackBar(context, 'Team promoted to Box.');
  }

  Future<void> _demoteToTeam(
      BuildContext context, Team team, List<TeamSlot> slots) async {
    final assigned = [...slots]..sort((a, b) => a.slot.compareTo(b.slot));

    List<TeamSlot> toKeep;

    if (assigned.length > 6) {
      final result = await showDialog<List<TeamSlot>>(
        context: context,
        builder: (_) => _DemoteSlotSelectionDialog(slots: assigned),
      );
      if (result == null || !context.mounted) return;
      toKeep = result;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Demote to Team'),
          content: const Text(
            'Convert this box to a team? It will hold a maximum of 6 Pokémon.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Demote'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      toKeep = assigned;
    }

    await _performDemotion(team.id, toKeep, assigned);
    if (context.mounted) showAppSnackBar(context, 'Box demoted to Team.');
  }

  Future<void> _performDemotion(
      int teamId, List<TeamSlot> toKeep, List<TeamSlot> all) async {
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    final keepIds = toKeep.map((s) => s.id).toSet();
    for (final slot in all) {
      if (!keepIds.contains(slot.id)) {
        await slotRepo.deleteSlotWithQueue(slot.teamId, slot.slot, slot.id);
      }
    }
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    await instanceRepo.relinkOrphanedChain();
    await instanceRepo.deleteOrphanedInstances();

    // Renumber kept slots to positions 1–6 in ascending order to avoid
    // transient conflicts when two slots swap positions.
    final sorted = [...toKeep]..sort((a, b) => a.slot.compareTo(b.slot));
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].slot != i + 1) {
        await slotRepo.updateSlotPosition(sorted[i].id, i + 1);
      }
    }

    await setTeamIsBox(ref, teamId, isBox: false);
  }
}

// ── AppBar title with format name resolved from ID ───────────────────────────

class _TeamAppBarTitle extends ConsumerWidget {
  final Team team;
  const _TeamAppBarTitle({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? formatName;
    if (team.formatLabel != null) {
      final fmtAsync = ref.watch(allFormatsProvider);
      fmtAsync.whenData((formats) {}); // ensure loaded
      final service = ref.watch(formatServiceProvider);
      formatName = service.formatById(team.formatLabel!)?.name ?? team.formatLabel;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(team.name),
        if (formatName != null)
          Text(
            formatName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
      ],
    );
  }
}

// ── Slot list (reorderable) ───────────────────────────────────────────────────

class _SlotList extends ConsumerWidget {
  final int teamId;
  final List<TeamSlot> slots;
  final String? formatId;
  final int? selectedSlot;
  final int maxSlots;
  final void Function(int slotNumber)? onSlotTap;
  final Set<int> selectedSlotIds;
  final bool isMultiSelect;
  final void Function(TeamSlot)? onEnterMultiSelect;
  final void Function(TeamSlot)? onToggleSlot;

  const _SlotList({
    required this.teamId,
    required this.slots,
    this.formatId,
    this.selectedSlot,
    this.maxSlots = 6,
    this.onSlotTap,
    this.selectedSlotIds = const {},
    this.isMultiSelect = false,
    this.onEnterMultiSelect,
    this.onToggleSlot,
  });

  // Build a maxSlots-element growable list keyed by position (0-based); null = empty slot.
  List<TeamSlot?> _positions() {
    final pos = List<TeamSlot?>.filled(maxSlots, null, growable: true);
    for (final s in slots) {
      if (s.slot >= 1 && s.slot <= maxSlots) pos[s.slot - 1] = s;
    }
    return pos;
  }

  Future<void> _onReorder(WidgetRef ref, int oldIndex, int newIndex) async {
    final pos = _positions();
    final moved = pos.removeAt(oldIndex);
    pos.insert(newIndex, moved);

    final repo = ref.read(teamSlotRepositoryProvider);
    for (int i = 0; i < maxSlots; i++) {
      final s = pos[i];
      if (s != null && s.slot != i + 1) {
        await repo.updateSlotPosition(s.id, i + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = _positions();

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      buildDefaultDragHandles: false, // explicit handles inside each card
      onReorderItem: (o, n) => _onReorder(ref, o, n),
      itemCount: maxSlots,
      itemBuilder: (_, i) {
        final slot = pos[i];
        return Padding(
          key: ValueKey(i),
          padding: const EdgeInsets.only(bottom: 10),
          child: slot != null
              ? _FilledSlotCard(
                  slot: slot,
                  teamId: teamId,
                  dragIndex: i,
                  formatId: formatId,
                  selected: selectedSlot == slot.slot,
                  onTap: onSlotTap != null
                      ? () => onSlotTap!(slot.slot)
                      : null,
                  isMultiSelectMode: isMultiSelect,
                  isChecked: selectedSlotIds.contains(slot.id),
                  onEnterMultiSelect: onEnterMultiSelect != null
                      ? () => onEnterMultiSelect!(slot)
                      : null,
                  onToggleSlot: onToggleSlot != null
                      ? () => onToggleSlot!(slot)
                      : null,
                )
              : _EmptySlotCard(teamId: teamId, slotNumber: i + 1, dragIndex: i),
        );
      },
    );
  }
}

// ── Filled slot card ──────────────────────────────────────────────────────────

class _FilledSlotCard extends ConsumerWidget {
  final TeamSlot slot;
  final int teamId;
  final int dragIndex;
  final String? formatId;
  final bool selected;
  final VoidCallback? onTap;
  final bool isMultiSelectMode;
  final bool isChecked;
  final VoidCallback? onEnterMultiSelect;
  final VoidCallback? onToggleSlot;

  const _FilledSlotCard({
    required this.slot,
    required this.teamId,
    required this.dragIndex,
    this.formatId,
    this.selected = false,
    this.onTap,
    this.isMultiSelectMode = false,
    this.isChecked = false,
    this.onEnterMultiSelect,
    this.onToggleSlot,
  });

  static const _statLabels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];
  static const _statKeys = [
    'hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed',
  ];

  static const _hpTypeNames = [
    'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug',
    'Ghost',    'Steel',  'Fire',   'Water',  'Grass', 'Electric',
    'Psychic',  'Ice',    'Dragon', 'Dark',
  ];

  static String _hiddenPowerTypeName(TeamSlot slot, {int? gen}) {
    final ivHp  = slot.ivHp  ?? 31;
    final ivAtk = slot.ivAtk ?? 31;
    final ivDef = slot.ivDef ?? 31;
    final ivSpa = slot.ivSpa ?? 31;
    final ivSpd = slot.ivSpd ?? 31;
    final ivSpe = slot.ivSpe ?? 31;
    int idx;
    if (gen == 2) {
      idx = (ivAtk % 4) * 4 + (ivDef % 4);
    } else {
      final n = (ivHp  & 1) +
                (ivAtk & 1) * 2 +
                (ivDef & 1) * 4 +
                (ivSpe & 1) * 8 +
                (ivSpa & 1) * 16 +
                (ivSpd & 1) * 32;
      idx = (n * 15) ~/ 63;
    }
    return _hpTypeNames[idx];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use resolvedPokemonProvider (keepAlive, already cached from Pokédex scroll)
    // instead of pokemonDetailProvider (autoDispose, separate network call per slot).
    final format = formatId != null
        ? ref.watch(formatServiceProvider).formatById(formatId!)
        : null;
    final formatGen = format?.gen;
    final resolvedAsync = ref.watch(resolvedPokemonProvider((id: slot.pokemonId, gen: formatGen)));
    final formsData = ref.watch(pokemonFormsProvider((id: slot.pokemonId, gen: formatGen))).asData?.value;
    final varietiesData = ref.watch(pokemonVarietiesProvider((id: slot.pokemonId, gen: formatGen))).asData?.value;
    final itemAsync = slot.heldItemName != null
        ? ref.watch(catalogItemProvider(slot.heldItemName!))
        : null;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return resolvedAsync.when(
      loading: () => Card(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) =>
          Card(child: Center(child: Text('Error', style: textTheme.bodySmall))),
      data: (resolved) {
        // ── Identity ───────────────────────────────────────────────────────
        final pokemon = resolved.detail;
        final speciesName = pokemon.displaySpeciesName;
        final nickname = slot.nickname?.trim();
        final hasNickname =
            nickname != null && nickname.isNotEmpty && nickname != speciesName;
        final displayName = hasNickname ? nickname : speciesName;
        final descriptor = FormDescriptor.from(
          formName: slot.formName,
          isShiny: slot.isShiny,
          isMegaEvolved: slot.isMegaEvolved,
          hasGigantamax: slot.hasGigantamax,
          gigantamaxEnabled: slot.gigantamaxEnabled,
          isAlpha: slot.isAlpha,
          gender: slot.gender,
        );

        // ── Form state ─────────────────────────────────────────────────────
        // Cosmetic forms share the base /pokemon resource (no separate stats).
        // resolved.cosmeticForms is pre-patched and keepAlive; same data as
        // cosmeticFormsProvider but without the extra network call.
        final isFormActive = descriptor.formName != null &&
            descriptor.formName!.isNotEmpty;
        final cosmeticFormEntries = resolved.cosmeticForms;
        final isCosmeticFormActive = isFormActive &&
            cosmeticFormEntries.any((f) => f.name == descriptor.formName);
        // Battle-meaningful forms are all confirmed varieties — no pokemonByNameProvider needed.
        final formVariety = (isFormActive && !isCosmeticFormActive)
            ? varietiesData?.where((v) => v.name == descriptor.formName).firstOrNull
            : null;
        final cosmeticFormChange = isCosmeticFormActive
            ? cosmeticFormEntries
                .where((f) => f.name == descriptor.formName)
                .firstOrNull
            : null;

        // ── Mega detection ─────────────────────────────────────────────────
        // Backend varieties carry is_mega, associated_item, associated_move.
        final slotMoves = [slot.move1, slot.move2, slot.move3, slot.move4];
        final megaVariety = descriptor.isMegaEvolved
            ? varietiesData?.where((v) {
                if (v.isMega != true) return false;
                if (v.associatedItem != null &&
                    slot.heldItemName == v.associatedItem) {
                  return true;
                }
                if (v.associatedMove != null &&
                    slotMoves.contains(v.associatedMove)) {
                  return true;
                }
                return false;
              }).firstOrNull
            : null;
        final isMegaApplicable = megaVariety != null;

        // ── Types ──────────────────────────────────────────────────────────
        final effectiveTypes = (formVariety?.types?.isNotEmpty == true)
            ? formVariety!.types!
            : (megaVariety?.types?.isNotEmpty == true)
                ? megaVariety!.types!
                : pokemon.types;
        final effectivePrimaryType =
            effectiveTypes.isNotEmpty ? effectiveTypes[0] : 'normal';
        final effectiveTypeColor =
            PokemonTypeColors.colors[effectivePrimaryType] ?? colorScheme.primary;

        // ── Stats ──────────────────────────────────────────────────────────
        // Priority: form > mega > base.
        final baseStats = pokemon.stats;
        final megaStats = megaVariety?.baseStats?.map((k, v) => MapEntry(k, v));
        final effectiveBaseStats = megaStats ?? baseStats;
        final formEffectiveStats = formVariety?.baseStats;
        final resolvedStats = formEffectiveStats ?? effectiveBaseStats;
        final level = slot.level ?? 50;
        final evs = [
          slot.evHp ?? 0, slot.evAtk ?? 0, slot.evDef ?? 0,
          slot.evSpa ?? 0, slot.evSpd ?? 0, slot.evSpe ?? 0,
        ];
        final ivs = [
          slot.ivHp ?? 31, slot.ivAtk ?? 31, slot.ivDef ?? 31,
          slot.ivSpa ?? 31, slot.ivSpd ?? 31, slot.ivSpe ?? 31,
        ];
        final calcStats = <int>[
          for (int i = 0; i < _statKeys.length; i++)
            _statKeys[i] == 'hp'
                ? _calcHP(resolvedStats['hp'] ?? 45, ivs[0], evs[0], level)
                : _calcStat(
                    resolvedStats[_statKeys[i]] ?? 50,
                    ivs[i], evs[i], level,
                    _natureMod(slot.natureName, _statKeys[i]),
                  ),
        ];

        // ── Sprites ────────────────────────────────────────────────────────
        final useFormatSprites =
            ref.watch(useFormatSpritesProvider).asData?.value ?? true;
        final useGen15Sprite = useFormatSprites && format != null && format.gen <= 5;

        // Cosmetic form sprite: full sprite data from formsData (backend-resolved).
        final cosmeticFullSprite = cosmeticFormChange != null
            ? formsData
                ?.where((fd) => fd.name == cosmeticFormChange.name)
                .firstOrNull
            : null;

        // Active sprite source: active form's SpriteUrlsFull takes priority
        // over the base pokemon's. Falls back to resolved.spriteUrls.
        final activeSpriteSource = formVariety?.spriteUrls
            ?? cosmeticFullSprite?.spriteUrls
            ?? resolved.spriteUrls;

        // Sprite record: gen 1-5 → game_front; gen 6+ → HOME.
        // Form sprites flow through automatically via activeSpriteSource.
        final spriteUrls = useGen15Sprite
            ? (
                defaultUrl: activeSpriteSource.gameFront,
                shinyUrl: activeSpriteSource.gameFrontShiny ??
                    activeSpriteSource.gameFront,
                femaleUrl: activeSpriteSource.gameFrontFemale,
                femaleShinyUrl: activeSpriteSource.gameFrontFemaleShiny,
                fallbackUrl: null as String?,
                fallbackUrl2: null as String?,
              )
            : (
                defaultUrl: activeSpriteSource.home,
                shinyUrl: activeSpriteSource.homeShiny ?? activeSpriteSource.home,
                femaleUrl: activeSpriteSource.homeFemale,
                femaleShinyUrl: activeSpriteSource.homeFemaleShiny,
                fallbackUrl: null as String?,
                fallbackUrl2: null as String?,
              );

        // Mega artwork (HOME only — true artwork override, not mixed with sprites).
        final megaHomeUrl = megaVariety != null
            ? (descriptor.isShiny
                ? (megaVariety.spriteUrls?.homeShiny ?? megaVariety.spriteUrls?.home)
                : megaVariety.spriteUrls?.home)
            : null;
        final megaOfficialUrl = megaVariety != null
            ? (descriptor.isShiny
                ? (megaVariety.spriteUrls?.officialArtworkShiny ??
                    megaVariety.spriteUrls?.officialArtwork)
                : megaVariety.spriteUrls?.officialArtwork)
            : null;

        // GMax sprite: use form species name so multi-form species (Urshifu,
        // Toxtricity) get the correct GMax artwork.
        final gmaxSpeciesName = formVariety?.name ?? pokemon.name;
        final isGMaxActive = descriptor.hasGigantamax &&
            descriptor.gigantamaxEnabled &&
            gmaxMoveForSpecies(gmaxSpeciesName) != null;
        final gmaxPokemon = isGMaxActive
            ? ref
                .watch(pokemonByNameProvider('$gmaxSpeciesName-gmax'))
                .asData
                ?.value
            : null;
        final gmaxHomeUrl = gmaxPokemon != null
            ? (descriptor.isShiny
                ? pokemonHomeShinyUrl(gmaxPokemon.id)
                : pokemonHomeUrl(gmaxPokemon.id))
            : null;

        // Override artwork: GMax > Mega only.
        // Form sprites are already in spriteUrls via activeSpriteSource.
        final megaArtworkUrl = gmaxHomeUrl ?? megaHomeUrl;
        final megaArtworkFallback = gmaxHomeUrl != null
            ? (descriptor.isShiny
                ? (gmaxPokemon?.officialArtworkShinyUrl ??
                    gmaxPokemon?.officialArtworkUrl)
                : gmaxPokemon?.officialArtworkUrl)
            : megaOfficialUrl;

        // ── Validation & misc ──────────────────────────────────────────────
        final validation = formatId != null
            ? ref
                .watch(slotValidationProvider((
                  slot: slot,
                  formatId: formatId!,
                )))
                .asData
                ?.value
            : null;
        final hasViolations = validation != null && !validation.isValid;
        final moves = [slot.move1, slot.move2, slot.move3, slot.move4]
            .where((m) => m != null)
            .cast<String>()
            .toList();
        final itemEntry = itemAsync?.whenOrNull(data: (e) => e);

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: (selected || isChecked)
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isChecked
                        ? colorScheme.tertiary
                        : colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: InkWell(
            onTap: isMultiSelectMode
                ? () {
                    HapticFeedback.selectionClick();
                    onToggleSlot?.call();
                  }
                : onTap ?? () => context.push('/teams/$teamId/config/${slot.slot}'),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showSlotMenu(context, ref);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Coloured accent strip ──
                Container(
                  width: double.infinity,
                  color: effectiveTypeColor.withValues(alpha: 0.15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        displayName,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (hasNickname) ...[
                        const SizedBox(width: 6),
                        Text(
                          speciesName,
                          style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                      const Spacer(),
                      if (hasViolations)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: validation.violations.values.join('\n'),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      FavoriteButton(
                          pokemonId: slot.pokemonId, iconSize: 18),
                      ReorderableDragStartListener(
                        index: dragIndex,
                        child: Icon(
                          Icons.drag_handle,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main body ──
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Col 1 — Sprite + item icon + species
                      SizedBox(
                        width: 100,
                        child: Column(
                          children: [
                            Builder(builder: (ctx) {
                              final isFemale = descriptor.gender == 'female';
                              // spriteUrls already holds the correct URL for the
                              // active gen: HOME for gen 6+/no-format, versioned
                              // sprite for gen 1-5.
                              final genderUrl = isFemale
                                  ? (descriptor.isShiny
                                      ? spriteUrls.femaleShinyUrl
                                      : spriteUrls.femaleUrl)
                                  : null;
                              final genFallback = descriptor.isShiny
                                  ? spriteUrls.shinyUrl
                                  : spriteUrls.defaultUrl;
                              final homeFemaleUrl = isFemale
                                  ? (descriptor.isShiny
                                      ? pokemonHomeShinyFemaleUrl(pokemon.id)
                                      : pokemonHomeFemaleUrl(pokemon.id))
                                  : null;
                              return PokemonSprite(
                                defaultUrl: megaArtworkUrl ??
                                    genderUrl ??
                                    spriteUrls.defaultUrl,
                                fallbackUrl: megaArtworkUrl != null
                                    ? megaArtworkFallback
                                    : genderUrl != null
                                        ? genFallback
                                        : spriteUrls.fallbackUrl,
                                fallbackUrl2: megaArtworkUrl != null
                                    ? spriteUrls.defaultUrl
                                    : genderUrl != null
                                        ? homeFemaleUrl
                                        : spriteUrls.fallbackUrl2,
                                shinyUrl: (megaArtworkUrl == null &&
                                        genderUrl == null)
                                    ? spriteUrls.shinyUrl
                                    : null,
                                shiny: megaArtworkUrl == null &&
                                    genderUrl == null &&
                                    descriptor.isShiny,
                                size: 96,
                              );
                            }),
                            if (itemEntry?.sprite != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: CachedNetworkImage(
                                  imageUrl: itemEntry!.sprite!,
                                  width: 36,
                                  height: 36,
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Col 2 — Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Types
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: effectiveTypes
                                  .map((t) => TypeBadge(type: t))
                                  .toList(),
                            ),
                            if (slot.teraType != null) ...[
                              const SizedBox(height: 4),
                              _TeraTypeBadge(teraType: slot.teraType!),
                            ],
                            const SizedBox(height: 4),
                            // Level · gender · shiny
                            Row(
                              children: [
                                Text('Lv $level',
                                    style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                if (descriptor.gender != null) ...[
                                  Text(
                                    ' · ${_genderSymbol(descriptor.gender!)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: descriptor.gender == 'male'
                                          ? Colors.blue
                                          : descriptor.gender == 'female'
                                              ? Colors.pink
                                              : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (descriptor.isShiny) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.auto_awesome,
                                      size: 12, color: Colors.amber),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Item
                            if (slot.heldItemName != null)
                              Text(
                                slot.heldItemName!.toCapitalCase(),
                                style: textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            // Ability — show mega form ability when evolved
                            Builder(builder: (_) {
                              // megaVariety abilities: PS format {"0": "tough-claws"}
                              final megaAbility = megaVariety?.abilities?.values.firstOrNull;
                              final abilityName = (isMegaApplicable && megaAbility != null)
                                  ? megaAbility
                                  : slot.abilityName;
                              if (abilityName == null) return const SizedBox.shrink();
                              return Text(
                                abilityName.toCapitalCase(),
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                            // Nature
                            if (slot.natureName != null)
                              Text(
                                slot.natureName!,
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Col 3 — Compact stat bars
                      SizedBox(
                        width: 88,
                        child: Column(
                          children: [
                            for (int i = 0; i < _statLabels.length; i++)
                              _CompactStatBar(
                                label: _statLabels[i],
                                value: calcStats[i],
                                ev: evs[i],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Moves strip ──
                if (moves.isNotEmpty) ...[
                  Divider(
                      height: 1,
                      color: colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: moves.map((m) {
                        final label = m == 'hidden-power'
                            ? 'Hidden Power (${_hiddenPowerTypeName(slot, gen: format?.gen)})'
                            : m.toCapitalCase();
                        return Text('• $label', style: textTheme.bodySmall);
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _genderSymbol(String gender) {
    switch (gender) {
      case 'male': return '♂';
      case 'female': return '♀';
      default: return '⚲';
    }
  }

  Future<void> _showSlotMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Configure slot'),
              onTap: () => Navigator.pop(ctx, 'config'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace Pokémon'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy to team'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to team'),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
            if (!isMultiSelectMode)
              ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('Select'),
                onTap: () => Navigator.pop(ctx, 'select'),
              ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove from team'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == 'config') {
      if (onTap != null) {
        onTap!();
      } else {
        context.push('/teams/$teamId/config/${slot.slot}');
      }
    } else if (action == 'replace') {
      context.push('/teams/$teamId/pick/${slot.slot}');
    } else if (action == 'copy') {
      await showMoveCopySlotSheet(
        context,
        ref,
        sourceSlots: [slot],
        deleteSource: false,
      );
    } else if (action == 'move') {
      await showMoveCopySlotSheet(
        context,
        ref,
        sourceSlots: [slot],
        deleteSource: true,
      );
    } else if (action == 'select') {
      onEnterMultiSelect?.call();
    } else if (action == 'remove') {
      await ref
          .read(teamSlotRepositoryProvider)
          .deleteSlotWithQueue(slot.teamId, slot.slot, slot.id);
      final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
      await instanceRepo.relinkOrphanedChain();
      await instanceRepo.deleteOrphanedInstances();
    }
  }
}

// ── Compact stat bar (for slot summary card) ──────────────────────────────────

class _CompactStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int ev;

  const _CompactStatBar({
    required this.label,
    required this.value,
    required this.ev,
  });

  Color _barColor(ColorScheme cs, int ev) {
    if (ev >= 252) return Colors.green.shade600;
    if (ev > 0) return Colors.amber.shade700;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const maxStat = 700.0;
    final fraction = (value / maxStat).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _barColor(colorScheme, ev)),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              ev > 0 ? '$ev' : '',
              textAlign: TextAlign.right,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: ev >= 252
                    ? Colors.green.shade600
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tera Type badge ───────────────────────────────────────────────────────────

class _TeraTypeBadge extends StatelessWidget {
  final String teraType;
  const _TeraTypeBadge({required this.teraType});

  @override
  Widget build(BuildContext context) {
    final color = PokemonTypeColors.colors[teraType] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Tera · ${teraType[0].toUpperCase()}${teraType.substring(1)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Empty slot card ───────────────────────────────────────────────────────────

class _EmptySlotCard extends StatelessWidget {
  final int teamId;
  final int slotNumber;
  final int dragIndex;

  const _EmptySlotCard({
    required this.teamId,
    required this.slotNumber,
    required this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: () => context.push('/teams/$teamId/pick/$slotNumber'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 28,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Slot $slotNumber — tap to add Pokémon',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: dragIndex,
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Multi-select bottom action bar ────────────────────────────────────────────

class _MultiSelectBar extends StatelessWidget {
  const _MultiSelectBar({
    required this.selectedCount,
    required this.onDelete,
    required this.onCopy,
    required this.onMove,
  });

  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: cs.error,
              onTap: onDelete,
            ),
            _ActionButton(
              icon: Icons.copy_outlined,
              label: 'Copy',
              onTap: onCopy,
            ),
            _ActionButton(
              icon: Icons.drive_file_move_outlined,
              label: 'Move',
              onTap: onMove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slot selection dialog for Box → Team demotion ─────────────────────────────

class _DemoteSlotSelectionDialog extends StatefulWidget {
  final List<TeamSlot> slots;
  const _DemoteSlotSelectionDialog({required this.slots});

  @override
  State<_DemoteSlotSelectionDialog> createState() =>
      _DemoteSlotSelectionDialogState();
}

class _DemoteSlotSelectionDialogState
    extends State<_DemoteSlotSelectionDialog> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    // Pre-select the first 6 by slot position (slots are already sorted).
    _selected = widget.slots.take(6).map((s) => s.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;

    return AlertDialog(
      title: const Text('Select Pokémon for Team'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose up to 6 Pokémon to keep ($count/6 selected).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.slots.length,
                itemBuilder: (_, i) {
                  final slot = widget.slots[i];
                  final isSelected = _selected.contains(slot.id);
                  final atLimit = count >= 6 && !isSelected;
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: atLimit
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(slot.id);
                              } else {
                                _selected.remove(slot.id);
                              }
                            }),
                    secondary: CachedNetworkImage(
                      imageUrl: pokemonHomeUrl(slot.pokemonId),
                      width: 40,
                      height: 40,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.catching_pokemon, size: 40),
                    ),
                    title: Text(
                      slot.nickname?.trim().isNotEmpty == true
                          ? slot.nickname!.trim()
                          : 'Slot ${slot.slot}',
                    ),
                    subtitle: Text('Position ${slot.slot}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final selected =
                widget.slots.where((s) => _selected.contains(s.id)).toList();
            Navigator.pop(context, selected);
          },
          child: const Text('Demote'),
        ),
      ],
    );
  }
}
