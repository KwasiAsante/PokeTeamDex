import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';

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
    if (mounted) {
      _urlController.text = url;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL saved')),
      );
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
            '• Web / iOS simulator: http://localhost:8000\n'
            '• Android emulator: http://10.0.2.2:8000\n'
            '• Production: https://your-app.fly.dev',
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
          const SizedBox(height: 8),
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
            error: (_, __) => const SizedBox.shrink(),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in to sync your teams to the cloud.'),
        action: SnackBarAction(
          label: 'Sign In',
          onPressed: () => router.push('/login'),
        ),
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
      error: (_, __) => 0,
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

class _AccentColorPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentValue = ref.watch(seedColorProvider).when(
          data: (v) => v,
          loading: () => kDefaultSeedColor,
          error: (_, __) => kDefaultSeedColor,
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
