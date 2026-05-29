import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/connectivity/connectivity_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';
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
    final name = await _nameDialog(context, title: 'New Team', hint: 'Team name');
    if (name != null && name.isNotEmpty) {
      await createTeam(ref, name, folderId: folderId);
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

// ── Teams list with folders ───────────────────────────────────────────────────

class _TeamsList extends ConsumerWidget {
  final List<TeamFolder> folders;
  const _TeamsList({required this.folders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTeamsAsync = ref.watch(allTeamsProvider);

    return allTeamsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (allTeams) {
        final ungrouped =
            allTeams.where((t) => t.folderId == null).toList();

        if (folders.isEmpty && ungrouped.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: 'No teams yet',
            subtitle:
                'Tap "New Team" to create your first team, or use the folder icon to organise them.',
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            // Folders
            for (final folder in folders) ...[
              _FolderSection(folder: folder),
            ],
            // Ungrouped teams
            if (ungrouped.isNotEmpty) ...[
              if (folders.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
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
                ),
              for (final team in ungrouped)
                _TeamTile(team: team),
            ],
          ],
        );
      },
    );
  }
}

// ── Folder section ────────────────────────────────────────────────────────────

class _FolderSection extends ConsumerStatefulWidget {
  final TeamFolder folder;
  const _FolderSection({required this.folder});

  @override
  ConsumerState<_FolderSection> createState() => _FolderSectionState();
}

class _FolderSectionState extends ConsumerState<_FolderSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamsAsync =
        ref.watch(teamsByFolderProvider(widget.folder.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            _expanded ? Icons.folder_open : Icons.folder,
            color: colorScheme.primary,
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
                icon: Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
                onPressed: () =>
                    setState(() => _expanded = !_expanded),
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
                    padding:
                        const EdgeInsets.fromLTRB(24, 0, 16, 8),
                    child: Text(
                      'No teams — tap + to add one.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : Column(
                    children: teams
                        .map((t) => _TeamTile(team: t))
                        .toList(),
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
  const _TeamTile({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.catching_pokemon,
            color: colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(team.name),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _onTeamAction(context, ref, v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
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
