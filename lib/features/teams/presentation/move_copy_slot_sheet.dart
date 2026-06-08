import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows the move/copy slot bottom sheet.
///
/// [deleteSource] = true → move semantics; false → copy semantics.
Future<void> showMoveCopySlotSheet(
  BuildContext context,
  WidgetRef ref, {
  required TeamSlot sourceSlot,
  required bool deleteSource,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoveCopySlotSheet(
      sourceSlot: sourceSlot,
      deleteSource: deleteSource,
    ),
  );
}

// ── Internal steps ────────────────────────────────────────────────────────────

enum _Step { teamPicker, slotPicker, newTeamForm }

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _MoveCopySlotSheet extends ConsumerStatefulWidget {
  const _MoveCopySlotSheet({
    required this.sourceSlot,
    required this.deleteSource,
  });

  final TeamSlot sourceSlot;
  final bool deleteSource;

  @override
  ConsumerState<_MoveCopySlotSheet> createState() => _MoveCopySlotSheetState();
}

class _MoveCopySlotSheetState extends ConsumerState<_MoveCopySlotSheet> {
  _Step _step = _Step.teamPicker;

  // Set when user picks an existing target team
  Team? _targetTeam;

  // Loaded slots of the picked existing team (for slot picker step)
  List<TeamSlot> _targetSlots = [];

  // New team form state
  final _nameController = TextEditingController();
  int? _newTeamFolderId;
  List<TeamFolder> _folders = [];

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Step transitions ────────────────────────────────────────────────────────

  Future<void> _pickExistingTeam(Team team) async {
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final slots = await slotRepo.getByTeam(team.id);
    setState(() {
      _targetTeam = team;
      _targetSlots = slots;
      _step = _Step.slotPicker;
    });
  }

  Future<void> _showNewTeamForm() async {
    final folderRepo = ref.read(teamFolderRepositoryProvider);
    final folders = await folderRepo.getAll();
    setState(() {
      _folders = folders;
      _step = _Step.newTeamForm;
    });
  }

  void _goBack() {
    setState(() {
      _step = _Step.teamPicker;
      _targetTeam = null;
      _targetSlots = [];
    });
  }

  // ── Commit actions ──────────────────────────────────────────────────────────

  Future<void> _copyToSlot(int slotPosition) async {
    setState(() => _saving = true);
    try {
      await copySlotToTeam(
        ref,
        source: widget.sourceSlot,
        targetTeamId: _targetTeam!.id,
        targetSlotPosition: slotPosition,
        deleteSource: widget.deleteSource,
      );
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(
          context,
          widget.deleteSource
              ? 'Moved to ${_targetTeam!.name}'
              : 'Copied to ${_targetTeam!.name}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createNewTeamAndCopy() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final newTeamId =
          await createTeam(ref, name, folderId: _newTeamFolderId);
      await copySlotToTeam(
        ref,
        source: widget.sourceSlot,
        targetTeamId: newTeamId,
        targetSlotPosition: 1,
        deleteSource: widget.deleteSource,
      );
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(
          context,
          widget.deleteSource
              ? 'Moved to new team "$name"'
              : 'Copied to new team "$name"',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final verb = widget.deleteSource ? 'Move' : 'Copy';
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    if (_step != _Step.teamPicker)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _goBack,
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _headerTitle(verb),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  String _headerTitle(String verb) {
    switch (_step) {
      case _Step.teamPicker:
        return '$verb to…';
      case _Step.slotPicker:
        return 'Pick a slot in ${_targetTeam!.name}';
      case _Step.newTeamForm:
        return 'New team';
    }
  }

  Widget _buildBody(ScrollController scrollController) {
    switch (_step) {
      case _Step.teamPicker:
        return _TeamPickerBody(
          sourceTeamId: widget.sourceSlot.teamId,
          scrollController: scrollController,
          onTeamSelected: _pickExistingTeam,
          onNewTeam: _showNewTeamForm,
        );
      case _Step.slotPicker:
        return _SlotPickerBody(
          targetTeam: _targetTeam!,
          existingSlots: _targetSlots,
          scrollController: scrollController,
          onSlotSelected: _copyToSlot,
        );
      case _Step.newTeamForm:
        return _NewTeamFormBody(
          nameController: _nameController,
          folders: _folders,
          selectedFolderId: _newTeamFolderId,
          onFolderChanged: (id) => setState(() => _newTeamFolderId = id),
          onConfirm: _createNewTeamAndCopy,
          scrollController: scrollController,
        );
    }
  }
}

// ── Team picker body ──────────────────────────────────────────────────────────

class _TeamPickerBody extends ConsumerStatefulWidget {
  const _TeamPickerBody({
    required this.sourceTeamId,
    required this.scrollController,
    required this.onTeamSelected,
    required this.onNewTeam,
  });

  final int sourceTeamId;
  final ScrollController scrollController;
  final void Function(Team) onTeamSelected;
  final VoidCallback onNewTeam;

  @override
  ConsumerState<_TeamPickerBody> createState() => _TeamPickerBodyState();
}

class _TeamPickerBodyState extends ConsumerState<_TeamPickerBody> {
  List<Team> _teams = [];
  List<TeamFolder> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final folderRepo = ref.read(teamFolderRepositoryProvider);
    final teams = await teamRepo.getAll();
    final folders = await folderRepo.getAll();
    if (mounted) {
      setState(() {
        _teams = teams
            .where((t) => !t.isDeleted && t.id != widget.sourceTeamId)
            .toList();
        _folders = folders;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group teams by folder
    final Map<int?, List<Team>> byFolder = {};
    for (final team in _teams) {
      byFolder.putIfAbsent(team.folderId, () => []).add(team);
    }

    final sections = <Widget>[];

    // Ungrouped teams first
    if (byFolder[null]?.isNotEmpty == true) {
      for (final team in byFolder[null]!) {
        sections.add(
            _TeamTile(team: team, onTap: () => widget.onTeamSelected(team)));
      }
    }

    // Folder sections
    for (final folder in _folders) {
      final teams = byFolder[folder.id];
      if (teams == null || teams.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            folder.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
          ),
        ),
      );
      for (final team in teams) {
        sections.add(
            _TeamTile(team: team, onTap: () => widget.onTeamSelected(team)));
      }
    }

    if (_teams.isEmpty) {
      sections.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No other teams yet.')),
        ),
      );
    }

    sections.add(const Divider());
    sections.add(
      ListTile(
        leading: const Icon(Icons.add),
        title: const Text('Create new team'),
        onTap: widget.onNewTeam,
      ),
    );

    return ListView(
      controller: widget.scrollController,
      children: sections,
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.onTap});

  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
          team.isBox ? Icons.inventory_2_outlined : Icons.groups_outlined),
      title: Text(team.name),
      subtitle: team.formatLabel != null ? Text(team.formatLabel!) : null,
      onTap: onTap,
    );
  }
}

// ── Slot picker body ──────────────────────────────────────────────────────────

class _SlotPickerBody extends StatelessWidget {
  const _SlotPickerBody({
    required this.targetTeam,
    required this.existingSlots,
    required this.scrollController,
    required this.onSlotSelected,
  });

  final Team targetTeam;
  final List<TeamSlot> existingSlots;
  final ScrollController scrollController;
  final void Function(int) onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final slotMap = {for (final s in existingSlots) s.slot: s};

    // Regular teams: 6 slots. Boxes: show occupied + a few empty at the end.
    final int maxSlot;
    if (!targetTeam.isBox) {
      maxSlot = 6;
    } else {
      final occupied = slotMap.keys.fold(0, (m, s) => s > m ? s : m);
      maxSlot = (occupied + 3).clamp(1, 60);
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: maxSlot,
      itemBuilder: (context, index) {
        final slotNumber = index + 1;
        final existing = slotMap[slotNumber];
        return _SlotTile(
          slotNumber: slotNumber,
          existingSlot: existing,
          onTap: () => onSlotSelected(slotNumber),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slotNumber,
    required this.existingSlot,
    required this.onTap,
  });

  final int slotNumber;
  final TeamSlot? existingSlot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final occupied = existingSlot != null;

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: occupied
            ? CachedNetworkImage(
                imageUrl: pokemonHomeUrl(existingSlot!.pokemonId),
                errorWidget: (_, _, _) =>
                    Icon(Icons.catching_pokemon, color: cs.onSurfaceVariant),
              )
            : Icon(Icons.add_circle_outline, color: cs.primary),
      ),
      title: Text(
        occupied ? 'Slot $slotNumber — replace' : 'Slot $slotNumber — empty',
      ),
      subtitle: occupied
          ? Text(
              'Pokémon #${existingSlot!.pokemonId}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            )
          : null,
      tileColor: occupied ? cs.errorContainer.withValues(alpha: 0.2) : null,
      onTap: onTap,
    );
  }
}

// ── New team form body ────────────────────────────────────────────────────────

class _NewTeamFormBody extends StatelessWidget {
  const _NewTeamFormBody({
    required this.nameController,
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderChanged,
    required this.onConfirm,
    required this.scrollController,
  });

  final TextEditingController nameController;
  final List<TeamFolder> folders;
  final int? selectedFolderId;
  final void Function(int?) onFolderChanged;
  final VoidCallback onConfirm;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Team name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          initialValue: selectedFolderId,
          decoration: const InputDecoration(
            labelText: 'Folder (optional)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('No folder'),
            ),
            ...folders.map(
              (f) =>
                  DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
            ),
          ],
          onChanged: onFolderChanged,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onConfirm,
          child: const Text('Create & add Pokémon'),
        ),
      ],
    );
  }
}
