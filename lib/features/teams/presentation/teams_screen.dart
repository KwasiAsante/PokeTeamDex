import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/features/teams/presentation/format_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/presentation/ps_import_sheet.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/connectivity/connectivity_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/teams/data/mega_forms_data.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart'
    show teamSlotsProvider;
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final allTeamsAsync = ref.watch(allTeamsProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final pending = pendingCount.when(data: (v) => v, loading: () => 0, error: (_, _) => 0);
    final isSyncing = syncState.status == SyncStatus.syncing;
    // final authToken = ref.watch(authTokenProvider);
    final isOnline = ref.watch(isOnlineProvider).when(
      data: (v) => v,
      loading: () => true,
      error: (_, _) => true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import from Showdown',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const PsImportSheet(),
            ),
          ),
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
                          showAppSnackBar(
                            context,
                            'Sign in to sync your teams.',
                            action: SnackBarAction(
                              label: 'Sign In',
                              onPressed: () => router.push('/login'),
                            ),
                          );
                          return;
                        }
                        ref.read(syncServiceProvider).run(token: token);
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
          const ConnectivityStatusButton(),
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
    final result = await showDialog<({String name, String? formatId, bool isBox})>(
      context: context,
      builder: (ctx) => const _CreateTeamDialog(),
    );
    if (result != null && result.name.isNotEmpty) {
      await createTeam(ref, result.name,
          folderId: folderId,
          formatLabel: result.formatId,
          isBox: result.isBox);
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

  Future<void> _moveFolderTo(WidgetRef ref, List<TeamFolder> folders, int from, int to) async {
    final reordered = [...folders];
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);
    for (int i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await updateFolderSortOrder(ref, reordered[i].id, i);
      }
    }
  }

  Future<void> _onReorderFolders(WidgetRef ref, List<TeamFolder> folders, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    await _moveFolderTo(ref, folders, oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTeamsAsync = ref.watch(allTeamsProvider);
    final authToken = ref.watch(authTokenProvider);

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
          onRefresh: () => ref.read(syncServiceProvider).run(token: authToken),
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
                  onRefresh: () => ref.read(syncServiceProvider).run(token: authToken),
                ),
              ),
            // Reorderable folder list
            if (folders.isNotEmpty)
              SliverReorderableList(
                itemCount: folders.length,
                onReorder: (o, n) => _onReorderFolders(ref, folders, o, n),
                itemBuilder: (_, i) => _FolderSection(
                  key: ValueKey(folders[i].id),
                  folder: folders[i],
                  index: i,
                  folderCount: folders.length,
                  onMove: (f, t) => _moveFolderTo(ref, folders, f, t),
                ),
              ),
            // Ungrouped teams
            if (ungrouped.isNotEmpty || folders.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: DragTarget<Team>(
                  onWillAcceptWithDetails: (d) => d.data.folderId != null,
                  onAcceptWithDetails: (d) =>
                      moveTeamToFolder(ref, d.data.id, null),
                  builder: (context, candidates, _) {
                    final highlight = candidates.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: highlight
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.6)
                          : null,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          if (folders.isNotEmpty)
                            Text(
                              'Ungrouped',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          if (highlight) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_downward,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Drop here to ungroup',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (ungrouped.isNotEmpty)
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
  final int folderCount;
  final Future<void> Function(int from, int to) onMove;

  const _FolderSection({
    required super.key,
    required this.folder,
    required this.index,
    required this.folderCount,
    required this.onMove,
  });

  @override
  ConsumerState<_FolderSection> createState() => _FolderSectionState();
}

class _FolderSectionState extends ConsumerState<_FolderSection> {
  bool _expanded = true;
  bool _reordering = false;

  Future<void> _moveTeamTo(List<Team> teams, int from, int to) async {
    setState(() => _reordering = true);
    try {
      final reordered = [...teams];
      final moved = reordered.removeAt(from);
      reordered.insert(to, moved);
      for (int i = 0; i < reordered.length; i++) {
        if (reordered[i].sortOrder != i) {
          await updateTeamSortOrder(ref, reordered[i].id, i);
        }
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _onReorderTeams(List<Team> teams, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    await _moveTeamTo(teams, oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 600;
    final teamsAsync = ref.watch(teamsByFolderProvider(widget.folder.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<Team>(
          onWillAcceptWithDetails: (d) => d.data.folderId != widget.folder.id,
          onAcceptWithDetails: (d) =>
              moveTeamToFolder(ref, d.data.id, widget.folder.id),
          builder: (context, candidates, _) {
            final highlight = candidates.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: highlight
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: widget.index,
                  child: Icon(
                    _expanded ? Icons.folder_open : Icons.folder,
                    color: highlight
                        ? colorScheme.primary
                        : colorScheme.primary,
                  ),
                ),
                title: Text(
                  widget.folder.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWide) ...[
                IconButton(
                  icon: const Icon(Icons.vertical_align_top),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Move to top',
                  onPressed: widget.index > 0 ? () => widget.onMove(widget.index, 0) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Move up',
                  onPressed: widget.index > 0 ? () => widget.onMove(widget.index, widget.index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Move down',
                  onPressed: widget.index < widget.folderCount - 1 ? () => widget.onMove(widget.index, widget.index + 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.vertical_align_bottom),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Move to bottom',
                  onPressed: widget.index < widget.folderCount - 1 ? () => widget.onMove(widget.index, widget.folderCount - 1) : null,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add team to folder',
                onPressed: () => _addTeamToFolder(context),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'move_top') {
                    widget.onMove(widget.index, 0);
                  } else if (v == 'move_up') {
                    widget.onMove(widget.index, widget.index - 1);
                  } else if (v == 'move_down') {
                    widget.onMove(widget.index, widget.index + 1);
                  } else if (v == 'move_bottom') {
                    widget.onMove(widget.index, widget.folderCount - 1);
                  } else {
                    _onFolderAction(context, v);
                  }
                },
                itemBuilder: (_) => [
                  if (!isWide) ...[
                    PopupMenuItem(
                      value: 'move_top',
                      enabled: widget.index > 0,
                      child: const Text('Move to top'),
                    ),
                    PopupMenuItem(
                      value: 'move_up',
                      enabled: widget.index > 0,
                      child: const Text('Move up'),
                    ),
                    PopupMenuItem(
                      value: 'move_down',
                      enabled: widget.index < widget.folderCount - 1,
                      child: const Text('Move down'),
                    ),
                    PopupMenuItem(
                      value: 'move_bottom',
                      enabled: widget.index < widget.folderCount - 1,
                      child: const Text('Move to bottom'),
                    ),
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(
                    value: 'import',
                    child: Text('Import from Showdown'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
            );
          },
        ),
        if (_reordering)
          const LinearProgressIndicator(minHeight: 2),
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
                      teamCount: teams.length,
                      onMove: (from, to) => _moveTeamTo(teams, from, to),
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
    if (action == 'import') {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PsImportSheet(folderId: widget.folder.id),
      );
    } else if (action == 'rename') {
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
  final int? teamCount;
  final Future<void> Function(int from, int to)? onMove;

  const _TeamTile({
    super.key,
    required this.team,
    this.dragIndex,
    this.teamCount,
    this.onMove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 600;
    // Select just this team's membership bool — watching the raw Set would
    // rebuild every tile in the list on every sync-queue emission, even when
    // this team's pending/error status didn't change.
    final hasError = ref.watch(errorTeamIdsProvider.select(
      (async) => async.asData?.value.contains(team.id) ?? false,
    ));
    final hasPending = !hasError && ref.watch(pendingTeamIdsProvider.select(
      (async) => async.asData?.value.contains(team.id) ?? false,
    ));

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
      title: Row(
        children: [
          if (team.isBox) ...[
            Icon(Icons.inventory_2_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(team.name)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeamSpriteRow(teamId: team.id, isBox: team.isBox, formatLabel: team.formatLabel),
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
          if (isWide && dragIndex != null && onMove != null && teamCount != null) ...[
            IconButton(
              icon: const Icon(Icons.vertical_align_top),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Move to top',
              onPressed: dragIndex! > 0 ? () => onMove!(dragIndex!, 0) : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Move up',
              onPressed: dragIndex! > 0 ? () => onMove!(dragIndex!, dragIndex! - 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Move down',
              onPressed: dragIndex! < teamCount! - 1 ? () => onMove!(dragIndex!, dragIndex! + 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.vertical_align_bottom),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Move to bottom',
              onPressed: dragIndex! < teamCount! - 1 ? () => onMove!(dragIndex!, teamCount! - 1) : null,
            ),
          ],
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          // Cross-folder drag handle — separate from the intra-folder handle
          // above so they don't compete for the same gesture.
          Draggable<Team>(
            data: team,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.catching_pokemon, size: 18),
                    const SizedBox(width: 6),
                    Text(team.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: Icon(Icons.drive_file_move_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            child: Tooltip(
              message: 'Drag to move folder',
              child: Icon(Icons.drive_file_move_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (!isWide && dragIndex != null && onMove != null && teamCount != null) {
                if (v == 'move_top') { onMove!(dragIndex!, 0); return; }
                if (v == 'move_up') { onMove!(dragIndex!, dragIndex! - 1); return; }
                if (v == 'move_down') { onMove!(dragIndex!, dragIndex! + 1); return; }
                if (v == 'move_bottom') { onMove!(dragIndex!, teamCount! - 1); return; }
              }
              _onTeamAction(context, ref, v);
            },
            itemBuilder: (_) => [
              if (!isWide && dragIndex != null && onMove != null && teamCount != null) ...[
                PopupMenuItem(
                  value: 'move_top',
                  enabled: dragIndex! > 0,
                  child: const Text('Move to top'),
                ),
                PopupMenuItem(
                  value: 'move_up',
                  enabled: dragIndex! > 0,
                  child: const Text('Move up'),
                ),
                PopupMenuItem(
                  value: 'move_down',
                  enabled: dragIndex! < teamCount! - 1,
                  child: const Text('Move down'),
                ),
                PopupMenuItem(
                  value: 'move_bottom',
                  enabled: dragIndex! < teamCount! - 1,
                  child: const Text('Move to bottom'),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'move', child: Text('Move to folder')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    } else if (action == 'move') {
      final folders = ref.read(foldersProvider).asData?.value ?? [];
      if (!context.mounted) return;
      final result = await showModalBottomSheet<({int? folderId, bool confirmed})>(
        context: context,
        builder: (_) => _MoveFolderSheet(
          folders: folders,
          currentFolderId: team.folderId,
        ),
      );
      if (result != null && result.confirmed) {
        await moveTeamToFolder(ref, team.id, result.folderId);
      }
    } else if (action == 'duplicate') {
      await duplicateTeam(ref, team.id);
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
  bool _isBox = false;

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

    final maxBoxSize =
        ref.watch(maxBoxSizeProvider).asData?.value ?? kDefaultMaxBoxSize;

    return AlertDialog(
      title: const Text('New Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Team type toggle ────────────────────────────────────────────────
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.groups_outlined),
                label: Text('Team'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('Box'),
              ),
            ],
            selected: {_isBox},
            onSelectionChanged: (s) => setState(() => _isBox = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            _isBox
                ? 'A box holds up to $maxBoxSize Pokémon.'
                : 'A team holds up to 6 Pokémon.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _isBox ? 'Box name' : 'Team name',
              border: const OutlineInputBorder(),
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
      formatId: _selectedFormat?.id,
      isBox: _isBox,
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

// ── Team sprite row (6 mini sprites, or all filled slots for boxes) ───────────

class _TeamSpriteRow extends ConsumerWidget {
  final int teamId;
  final bool isBox;
  final String? formatLabel;
  const _TeamSpriteRow({required this.teamId, this.isBox = false, this.formatLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(teamSlotsProvider(teamId));
    final slots = slotsAsync.asData?.value ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    const double width = 60.0;
    const double height = 50.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * dpr).round();
    final cacheHeight = (height * dpr).round();

    Widget buildEmpty() => Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Icon(
        Icons.catching_pokemon,
        size: 36,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    );

    final List<Widget> children;
    if (isBox) {
      final filled = slots.toList()..sort((a, b) => a.slot.compareTo(b.slot));
      children = filled.isEmpty
          ? List.generate(6, (_) => buildEmpty())
          : filled.map((s) => _SlotSprite(
              key: ValueKey(s.id),
              slot: s,
              formatLabel: formatLabel,
              width: width,
              height: height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
            )).toList();
    } else {
      final slotMap = {for (final s in slots) s.slot: s};
      children = List.generate(6, (i) {
        final slot = slotMap[i + 1];
        return slot == null
            ? buildEmpty()
            : _SlotSprite(
                key: ValueKey(slot.id),
                slot: slot,
                formatLabel: formatLabel,
                width: width,
                height: height,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
              );
      });
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }
}

// ── Team slot sprite (form-aware) ─────────────────────────────────────────────

/// Single party-icon sprite for a team slot. Resolves the correct pokemonId for:
/// - Variety-based form variants (via [pokemonByNameProvider] on formName)
/// - Mega Evolution, Primal Reversion, and Gigantamax when the format supports
///   them and the slot has the relevant toggle/item active.
///
/// Falls back to the base species ID when no format is set ("no format" or
/// "all formats" context) or when a transformation is not active.
class _SlotSprite extends ConsumerWidget {
  final TeamSlot slot;
  final String? formatLabel;
  final double width;
  final double height;
  final int cacheWidth;
  final int cacheHeight;

  const _SlotSprite({
    super.key,
    required this.slot,
    required this.formatLabel,
    required this.width,
    required this.height,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Resolve format mechanics. Null means no format set → don't apply
    // Mega/Primal/Gmax icons (transformation context is ambiguous).
    final mechanics = formatLabel != null
        ? ref.read(formatServiceProvider).formatById(formatLabel!)?.mechanics
        : null;

    // Determine whether the slot is actively using a Mega, Primal, or Gmax
    // transformation that is valid for the current format.
    String? transformFormName;
    if (mechanics != null) {
      final item = slot.heldItemName;
      if (mechanics.hasMegaStone && slot.isMegaEvolved && item != null) {
        // Mega Evolution: derive form name from the held Mega Stone.
        final megaEntry = kMegaStoneMap[item];
        if (megaEntry != null) transformFormName = megaEntry.megaForm;
      } else if ((mechanics.gen == 6 || mechanics.gen == 7) && item != null) {
        // Primal Reversion: only applies in Gen 6/7 via orb.
        if (item == 'red-orb')  transformFormName = 'groudon-primal';
        if (item == 'blue-orb') transformFormName = 'kyogre-primal';
      } else if (mechanics.hasGigantamax && slot.hasGigantamax && slot.gigantamaxEnabled) {
        // Gigantamax: construct form name from the base (or active form) species.
        // Watch the base pokemon to get its name; falls back to base ID while loading.
        final baseName = ref
            .watch(pokemonDetailProvider(slot.pokemonId))
            .asData
            ?.value
            .name;
        if (baseName != null) transformFormName = '$baseName-gmax';
      }
    }

    // Resolve sprite ID: transformation > formName variant > base species.
    final int id;
    if (transformFormName != null) {
      final formId = ref
          .watch(pokemonByNameProvider(transformFormName))
          .asData
          ?.value
          .id;
      id = formId ?? slot.pokemonId;
    } else if (slot.formName != null) {
      final formId = ref
          .watch(pokemonByNameProvider(slot.formName!))
          .asData
          ?.value
          .id;
      id = formId ?? slot.pokemonId;
    } else {
      id = slot.pokemonId;
    }

    const versionsBase =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
    const spriteBase =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final spriteGen8 = '$versionsBase/generation-viii/sword-shield/$id.png';
    final spriteGen7 = '$versionsBase/generation-vii/ultra-sun-ultra-moon/$id.png';
    final spriteGen6 = '$versionsBase/generation-vi/x-y/$id.png';
    final spriteFallback = '$spriteBase/$id.png';

    final placeholder = SizedBox(
      width: width,
      height: height,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: CachedNetworkImage(
        imageUrl: spriteGen8,
        width: width,
        height: height,
        fit: BoxFit.contain,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => CachedNetworkImage(
          imageUrl: spriteGen7,
          width: width,
          height: height,
          fit: BoxFit.contain,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => CachedNetworkImage(
            imageUrl: spriteGen6,
            width: width,
            height: height,
            fit: BoxFit.contain,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => CachedNetworkImage(
              imageUrl: spriteFallback,
              width: width,
              height: height,
              fit: BoxFit.contain,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => Icon(
                Icons.catching_pokemon,
                size: 60,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Move to folder bottom sheet ───────────────────────────────────────────────

/// Lists all folders + Ungrouped. Returns `(folderId, confirmed: true)` on
/// selection, or null on dismiss.
class _MoveFolderSheet extends StatelessWidget {
  final List<TeamFolder> folders;
  final int? currentFolderId;

  const _MoveFolderSheet({
    required this.folders,
    required this.currentFolderId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Move to…',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.inbox_outlined,
                color: currentFolderId == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant),
            title: const Text('Ungrouped'),
            trailing: currentFolderId == null
                ? Icon(Icons.check, color: colorScheme.primary)
                : null,
            enabled: currentFolderId != null,
            onTap: currentFolderId == null
                ? null
                : () => Navigator.pop(
                    context, (folderId: null as int?, confirmed: true)),
          ),
          if (folders.isNotEmpty) const Divider(height: 1),
          ...folders.map((f) => ListTile(
                leading: Icon(Icons.folder_outlined,
                    color: currentFolderId == f.id
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant),
                title: Text(f.name),
                trailing: currentFolderId == f.id
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                enabled: currentFolderId != f.id,
                onTap: currentFolderId == f.id
                    ? null
                    : () => Navigator.pop(
                        context, (folderId: f.id as int?, confirmed: true)),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
