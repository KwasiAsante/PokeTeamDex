import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:poke_team_dex/services/update/update_provider.dart';
import 'package:poke_team_dex/services/update/update_service.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';
import 'package:url_launcher/url_launcher.dart';

// Preset accent colours shown in the Appearance section.
const _kPresetColors = [
  (label: 'Red',    value: 0xFFCC0000), // default — Pokéball
  (label: 'Blue',   value: 0xFF1565C0), // Water
  (label: 'Green',  value: 0xFF2E7D32), // Grass
  (label: 'Yellow', value: 0xFFF9A825), // Electric
  (label: 'Purple', value: 0xFF6A1B9A), // Psychic
  (label: 'Pink',   value: 0xFFAD1457), // Fairy
  (label: 'Orange', value: 0xFFE65100), // Fire
  (label: 'Teal',   value: 0xFF00695C), // Dragon
  (label: 'Indigo', value: 0xFF283593), // Dark
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _urlDirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await ref.read(appConfigRepositoryProvider).getApiBaseUrl();
    if (mounted) _urlController.text = url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(appConfigRepositoryProvider).setApiBaseUrl(url);
    if (mounted) {
      setState(() { _saving = false; _urlDirty = false; });
      showAppSnackBar(context, 'API URL saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenAsync = ref.watch(authTokenProvider);
    final isLoggedIn = tokenAsync != null && tokenAsync.isNotEmpty;
    final apiUrlAsync = ref.watch(apiBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [const ConnectivityStatusButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App Configuration ──────────────────────────────────────────────
          _SectionHeader('App Configuration'),
          const SizedBox(height: 8),
          Text(
            'API Base URL',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'The address of the PokeTeamDex backend.\n'
            '• Production: https://poketeamdex.duckdns.org (default)\n'
            '• Local dev: http://localhost:8000\n'
            '• Android emulator: http://10.0.2.2:8000',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          apiUrlAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (_) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: kDefaultApiBaseUrl,
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() => _urlDirty = true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_urlDirty && !_saving) ? _saveUrl : null,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          const SizedBox(height: 16),
          Text(
            'Theme',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _ThemeModePicker(),
          const SizedBox(height: 20),
          Text(
            'Accent colour',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          _AccentColorPicker(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Sprites ────────────────────────────────────────────────────────
          _SectionHeader('Sprites'),
          const SizedBox(height: 8),
          ref.watch(useFormatSpritesProvider).when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (useFormatSprites) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use generation sprites'),
              subtitle: const Text(
                'When a team has a format assigned, show sprites '
                'from that generation. Off = always use HOME / official artwork.',
              ),
              value: useFormatSprites,
              onChanged: (v) => ref
                  .read(appConfigRepositoryProvider)
                  .setUseFormatSprites(v),
            ),
          ),
          // ── Box size ───────────────────────────────────────────────────────
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _SectionHeader('Box Size'),
          const SizedBox(height: 8),
          _BoxSizeTile(),

          // ── Pokémon Showdown sync (desktop only) ──────────────────────────
          if (!kIsWeb &&
              (Platform.isWindows ||
                  Platform.isMacOS ||
                  Platform.isLinux)) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _SectionHeader('Pokémon Showdown'),
            const SizedBox(height: 8),
            _PsDirectoryTile(),
          ],

          // ── Window behaviour (desktop only) ───────────────────────────────
          if (!kIsWeb &&
              (Platform.isWindows ||
                  Platform.isMacOS ||
                  Platform.isLinux)) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _SectionHeader('Window'),
            const SizedBox(height: 8),
            ref.watch(minimizeToTrayProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (minimizeToTray) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Minimize to system tray'),
                subtitle: const Text(
                  'When closing the window, keep the app running '
                  'in the system tray instead of exiting.',
                ),
                value: minimizeToTray,
                onChanged: (v) => ref
                    .read(appConfigRepositoryProvider)
                    .setMinimizeToTray(v),
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Sync ───────────────────────────────────────────────────────────
          _SectionHeader('Sync'),
          const SizedBox(height: 8),
          _SyncStatusTile(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Account ────────────────────────────────────────────────────────
          _SectionHeader('Account'),
          const SizedBox(height: 8),
          if (isLoggedIn) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Signed in'),
              subtitle: const Text('Your teams sync to the cloud'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await logout(ref);
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Not signed in'),
              subtitle: const Text('Sign in to sync teams across devices'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── About ──────────────────────────────────────────────────────────
          _SectionHeader('About'),
          const SizedBox(height: 8),
          _AppVersionTile(),
        ],
      ),
    );
  }
}

void _syncNow(BuildContext context, WidgetRef ref) {
  final token = ref.read(authTokenProvider);
  final loggedIn = token != null && token.isNotEmpty;
  if (!loggedIn) {
    final router = GoRouter.of(context);
    showAppSnackBar(
      context,
      'Sign in to sync your teams to the cloud.',
      action: SnackBarAction(
        label: 'Sign In',
        onPressed: () => router.push('/login'),
      ),
    );
    return;
  }
  ref.read(syncServiceProvider).run();
}

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    final (icon, color, label) = switch (syncState.status) {
      SyncStatus.idle => (Icons.cloud_outlined, Colors.grey, 'Idle'),
      SyncStatus.syncing => (Icons.sync, Colors.blue, 'Syncing…'),
      SyncStatus.success => (Icons.cloud_done_outlined, Colors.green, 'Up to date'),
      SyncStatus.error => (Icons.cloud_off_outlined, Colors.red, 'Error'),
    };

    final pending = pendingCount.when(
      data: (v) => v,
      loading: () => 0,
      error: (_, _) => 0,
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: syncState.status == SyncStatus.syncing
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, color: color),
      title: Text(label),
      subtitle: pending > 0
          ? Text('$pending operation${pending == 1 ? '' : 's'} pending')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: syncState.status == SyncStatus.syncing
                ? null
                : () => _syncNow(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Sync monitor',
            onPressed: () => context.push('/sync-monitor'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider).when(
          data: (v) => v,
          loading: () => ThemeMode.system,
          error: (_, _) => ThemeMode.system,
        );

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) => ref
          .read(appConfigRepositoryProvider)
          .setThemeMode(selection.first),
    );
  }
}

class _AccentColorPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentValue = ref.watch(seedColorProvider).when(
          data: (v) => v,
          loading: () => kDefaultSeedColor,
          error: (_, _) => kDefaultSeedColor,
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in _kPresetColors)
          _ColorSwatch(
            color: Color(preset.value),
            label: preset.label,
            selected: currentValue == preset.value,
            onTap: () => ref
                .read(appConfigRepositoryProvider)
                .setSeedColor(preset.value),
          ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

// ── Box / team size ───────────────────────────────────────────────────────────

class _BoxSizeTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BoxSizeTile> createState() => _BoxSizeTileState();
}

class _BoxSizeTileState extends ConsumerState<_BoxSizeTile> {
  late TextEditingController _ctrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadValue();
  }

  Future<void> _loadValue() async {
    final v = await ref.read(appConfigRepositoryProvider).getMaxBoxSize();
    if (mounted) _ctrl.text = v.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null) return;
    await ref.read(appConfigRepositoryProvider)
        .setMaxBoxSize(v.clamp(1, kMaxBoxSizeLimit));
    if (mounted) {
      setState(() => _dirty = false);
      showAppSnackBar(context, 'Team size saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Max Pokémon per box',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'How many Pokémon slots a Box holds (1–$kMaxBoxSizeLimit). '
          'Does not affect regular teams, which always have 6 slots.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _dirty ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// ── PS directory tile ─────────────────────────────────────────────────────────

class _PsDirectoryTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dirAsync = ref.watch(psDirectoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = dirAsync.asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teams directory',
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'When set, every team save writes a .txt file to this '
          'directory in Pokémon Showdown export format. '
          'Teams inside folders are saved in a matching sub-folder.',
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  current ?? 'Not set',
                  style: textTheme.bodySmall?.copyWith(
                    color: current != null
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontFamily: current != null ? 'monospace' : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final path =
                    await FilePicker.getDirectoryPath(
                  dialogTitle: 'Select Pokémon Showdown teams folder',
                );
                if (path != null) {
                  await ref
                      .read(appConfigRepositoryProvider)
                      .setPsDirectory(path);
                }
              },
              child: const Text('Browse'),
            ),
            if (current != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear),
                onPressed: () => ref
                    .read(appConfigRepositoryProvider)
                    .setPsDirectory(null),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── App version + update check ────────────────────────────────────────────────

class _AppVersionTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data != null
            ? '${snap.data!.version}+${snap.data!.buildNumber}'
            : '…';

        final updateAsync = ref.watch(updateCheckProvider);
        final hasUpdate = updateAsync.asData?.value != null;
        final hasError  = updateAsync.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text('App version'),
              subtitle: Text(version),
              trailing: hasUpdate
                  ? Chip(
                      label: Text(
                        'Update available',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: updateAsync.isLoading
                  ? null
                  : () => ref.invalidate(updateCheckProvider),
              icon: updateAsync.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasError
                      ? Icons.error_outline
                      : Icons.system_update_outlined),
              label: Text(hasError
                  ? 'Check failed — tap to retry'
                  : 'Check for updates'),
            ),
            if (hasUpdate) ...[
              const SizedBox(height: 8),
              _UpdateDownloadRow(info: updateAsync.asData!.value!),
            ],
          ],
        );
      },
    );
  }
}

class _UpdateDownloadRow extends StatelessWidget {
  const _UpdateDownloadRow({required this.info});
  final dynamic info;

  @override
  Widget build(BuildContext context) {
    final downloadUrl = platformDownloadUrl(info);
    return Wrap(
      spacing: 8,
      children: [
        if (downloadUrl != null)
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            icon: const Icon(Icons.download_outlined),
            label: Text('Download ${info.version}'),
          ),
        OutlinedButton(
          onPressed: () async {
            final uri = Uri.parse(info.releaseUrl);
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
          child: const Text("What's new"),
        ),
      ],
    );
  }
}
