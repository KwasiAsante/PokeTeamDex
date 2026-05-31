import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/presentation/format_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/connectivity/connectivity_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:poke_team_dex/features/teams/presentation/team_detail_screen.dart'
    show teamSlotsProvider;
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final allTeamsAsync = ref.watch(allTeamsProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final pending = pendingCount.when(data: (v) => v, loading: () => 0, error: (_, __) => 0);
    final isSyncing = syncState.status == SyncStatus.syncing;
    final isOnline = ref.watch(isOnlineProvider).when(
      data: (v) => v,
      loading: () => true,
      error: (_, __) => true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New folder',
            onPressed: () => _showFolderDialog(context, ref),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync now',
                onPressed: isSyncing
                    ? null
                    : () {
                        final token = ref.read(authTokenProvider);
                        final loggedIn = token != null && token.isNotEmpty;
                        if (!loggedIn) {
                          final router = GoRouter.of(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Sign in to sync your teams.'),
                              action: SnackBarAction(
                                label: 'Sign In',
                                onPressed: () => router.push('/login'),
                              ),
                            ),
                          );
                          return;
                        }
                        ref.read(syncServiceProvider).run();
                      },
              ),
              if (pending > 0 && !isSyncing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              content: const Text(
                'You are offline — changes will sync when reconnected',
              ),
              leading: const Icon(Icons.cloud_off_outlined),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              dividerColor: Colors.transparent,
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: allTeamsAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e),
              data: (_) => foldersAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e),
                data: (folders) => _TeamsList(folders: folders),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTeamDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
      ),
    );
  }

  Future<void> _showFolderDialog(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, title: 'New Folder', hint: 'Folder name');
    if (name != null && name.isNotEmpty) {
      await createFolder(ref, name);
    }
  }

  Future<void> _showTeamDialog(BuildContext context, WidgetRef ref,
      {int? folderId}) async {
    final result = await showDialog<({String name, String? formatId})>(
      context: context,
      builder: (ctx) => _CreateTeamDialog(),
    );
    if (result != null && result.name.isNotEmpty) {
      await createTeam(ref, result.name,
          folderId: folderId, formatLabel: result.formatId);
    }
  }

  Future<String?> _nameDialog(BuildContext context,
      {required String title, required String hint}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ── Teams list with folders (folder list is reorderable) ─────────────────────

class _TeamsList extends ConsumerWidget {
  final List<TeamFolder> folders;
  const _TeamsList({required this.folders});

  Future<void> _onReorderFolders(WidgetRef ref, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...folders];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final repo = ref.read(teamFolderRepositoryProvider);
    for (int i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await repo.updateSortOrder(reordered[i].id, i);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTeamsAsync = ref.watch(allTeamsProvider);

    return allTeamsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (allTeams) {
        final ungrouped = allTeams.where((t) => t.folderId == null).toList();

        if (folders.isEmpty && ungrouped.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: 'No teams yet',
            subtitle:
                'Tap "New Team" to create your first team, or use the folder icon to organise them.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(syncServiceProvider).run(),
          child: CustomScrollView(
          // AlwaysScrollableScrollPhysics lets RefreshIndicator trigger
          // even when the content is short; on desktop (no touch) the sync
          // button in the AppBar is the primary refresh mechanism.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Desktop refresh header — shown instead of pull gesture
            if (!_isTouchPlatform())
              SliverToBoxAdapter(
                child: _DesktopRefreshBar(
                  onRefresh: () => ref.read(syncServiceProvider).run(),
                ),
              ),
            // Reorderable folder list
            if (folders.isNotEmpty)
              SliverReorderableList(
                itemCount: folders.length,
                onReorder: (o, n) => _onReorderFolders(ref, o, n),
                itemBuilder: (_, i) => _FolderSection(
                  key: ValueKey(folders[i].id),
                  folder: folders[i],
                  index: i,
                ),
              ),
            // Ungrouped teams
            if (ungrouped.isNotEmpty) ...[
              if (folders.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Ungrouped',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TeamTile(team: ungrouped[i]),
                  childCount: ungrouped.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
        );
      },
    );
  }
}

// ── Folder section ────────────────────────────────────────────────────────────

class _FolderSection extends ConsumerStatefulWidget {
  final TeamFolder folder;
  final int index; // position in the reorderable folder list

  const _FolderSection({
    required super.key,
    required this.folder,
    required this.index,
  });

  @override
  ConsumerState<_FolderSection> createState() => _FolderSectionState();
}

class _FolderSectionState extends ConsumerState<_FolderSection> {
  bool _expanded = true;

  Future<void> _onReorderTeams(List<Team> teams, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...teams];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final repo = ref.read(teamRepositoryProvider);
    for (int i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await repo.updateSortOrder(reordered[i].id, i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamsAsync = ref.watch(teamsByFolderProvider(widget.folder.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: ReorderableDragStartListener(
            index: widget.index,
            child: Icon(
              _expanded ? Icons.folder_open : Icons.folder,
              color: colorScheme.primary,
            ),
          ),
          title: Text(
            widget.folder.name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add team to folder',
                onPressed: () => _addTeamToFolder(context),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _onFolderAction(context, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          teamsAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (teams) => teams.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                    child: Text(
                      'No teams — tap + to add one.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (o, n) => _onReorderTeams(teams, o, n),
                    itemCount: teams.length,
                    itemBuilder: (_, i) => _TeamTile(
                      key: ValueKey(teams[i].id),
                      team: teams[i],
                      dragIndex: i,
                    ),
                  ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _addTeamToFolder(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Team'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Team name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await createTeam(ref, name, folderId: widget.folder.id);
    }
  }

  Future<void> _onFolderAction(
      BuildContext context, String action) async {
    if (action == 'rename') {
      final controller =
          TextEditingController(text: widget.folder.name);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        await renameFolder(ref, widget.folder.id, name);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Folder'),
          content: Text(
              'Delete "${widget.folder.name}"? Teams inside will become ungrouped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await deleteFolder(ref, widget.folder.id);
      }
    }
  }
}

// ── Team tile ─────────────────────────────────────────────────────────────────

class _TeamTile extends ConsumerWidget {
  final Team team;
  // Non-null when inside a reorderable folder section; used for the drag handle.
  final int? dragIndex;

  const _TeamTile({super.key, required this.team, this.dragIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingIds = ref.watch(pendingTeamIdsProvider).when(
          data: (ids) => ids,
          loading: () => <int>{},
          error: (_, __) => <int>{},
        );
    final errorIds = ref.watch(errorTeamIdsProvider).when(
          data: (ids) => ids,
          loading: () => <int>{},
          error: (_, __) => <int>{},
        );
    final hasError = errorIds.contains(team.id);
    final hasPending = !hasError && pendingIds.contains(team.id);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.catching_pokemon,
                color: colorScheme.onPrimaryContainer, size: 20),
          ),
          if (hasError)
            Positioned(
              top: -4,
              right: -4,
              child: Icon(
                Icons.warning_rounded,
                size: 16,
                color: colorScheme.error,
              ),
            )
          else if (hasPending)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(team.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini sprite row — 6 slots, Poké Ball for empty
          _TeamSpriteRow(teamId: team.id),
          if (hasError)
            Text(
              'Sync issue — check sync monitor',
              style: TextStyle(color: colorScheme.error, fontSize: 11),
            )
          else if (team.formatLabel != null)
            Text(
              ref.watch(formatServiceProvider)
                      .formatById(team.formatLabel!)?.name ??
                  team.formatLabel!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => _onTeamAction(context, ref, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: () => context.push('/teams/${team.id}'),
    );
  }

  Future<void> _onTeamAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'rename') {
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        await renameTeam(ref, team.id, name);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Team'),
          content: Text('Delete "${team.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await deleteTeam(ref, team.id);
      }
    }
  }
}

// ── Create team dialog (name + optional format) ───────────────────────────────

class _CreateTeamDialog extends ConsumerStatefulWidget {
  const _CreateTeamDialog();

  @override
  ConsumerState<_CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends ConsumerState<_CreateTeamDialog> {
  final _ctrl = TextEditingController();
  GameFormat? _selectedFormat;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickFormat() async {
    final result = await showModalBottomSheet<GameFormat?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormatPickerSheet(
        current: _selectedFormat?.id,
      ),
    );
    if (result == null) return; // dismissed
    setState(() {
      _selectedFormat = isFormatCleared(result) ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('New Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Team name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          // Format selector
          InkWell(
            onTap: _pickFormat,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFormat?.name ?? 'No format',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedFormat == null
                                ? colorScheme.onSurfaceVariant
                                : null,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.pop(context, (
      name: _ctrl.text.trim(),
      formatId: _selectedFormat?.id, // store format id (e.g. "gen9")
    ));
  }
}

// ── Platform helpers ──────────────────────────────────────────────────────────

bool _isTouchPlatform() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

// ── Desktop refresh bar ───────────────────────────────────────────────────────

class _DesktopRefreshBar extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  const _DesktopRefreshBar({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final isSyncing = syncState.status == SyncStatus.syncing;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.sync, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Pull-to-refresh unavailable on desktop',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: isSyncing ? null : onRefresh,
            icon: isSyncing
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 14),
            label: const Text('Sync now'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Team sprite row (6 mini sprites) ─────────────────────────────────────────

class _TeamSpriteRow extends ConsumerWidget {
  final int teamId;
  const _TeamSpriteRow({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(teamSlotsProvider(teamId));
    final slots = slotsAsync.asData?.value ?? [];
    final slotMap = {for (final s in slots) s.slot: s};
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: List.generate(6, (i) {
          final slot = slotMap[i + 1];
          if (slot == null) {
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.catching_pokemon,
                size: 36,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            );
          }
          // Use PokéAPI icon sprites — small, pixel-art icons designed for
          // party/box views. Gen VIII icons cover the widest Pokémon range;
          // fall back to Gen VII then the regular front sprite.
          final id = slot.pokemonId;
          const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
          final iconGen8  = '$base/generation-viii/icons/$id.png';
          final iconGen7  = '$base/generation-vii/icons/$id.png';
          final fallback  = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
          final width = 60.0;
          final height = 50.0;

          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: CachedNetworkImage(
              imageUrl: iconGen7,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => CachedNetworkImage(
                imageUrl: iconGen8,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => CachedNetworkImage(
                  imageUrl: fallback,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Icon(
                    Icons.catching_pokemon,
                    size: 60,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
