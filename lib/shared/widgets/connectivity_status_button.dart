import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/connectivity/connectivity_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';

/// AppBar action that shows a coloured dot reflecting device connectivity.
/// Tapping it opens a sheet with the status of the device network, PokéAPI,
/// backend API, and the user's sign-in state.
class ConnectivityStatusButton extends ConsumerWidget {
  const ConnectivityStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).when(
          data: (v) => v,
          loading: () => true,
          error: (_, __) => false,
        );

    return IconButton(
      tooltip: 'Connection status',
      icon: Badge(
        backgroundColor: isOnline ? Colors.green : Colors.red,
        smallSize: 8,
        child: const Icon(Icons.wifi_outlined),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => const _StatusSheet(),
      ),
    );
  }
}

// ── Status sheet ──────────────────────────────────────────────────────────────

class _StatusSheet extends ConsumerWidget {
  const _StatusSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final isOnline = ref.watch(isOnlineProvider).when(
          data: (v) => v,
          loading: () => null,
          error: (_, __) => false,
        );
    final backendAsync = ref.watch(backendHealthProvider);
    final pokeApiAsync = ref.watch(pokeApiHealthProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title + refresh
          Row(
            children: [
              Text('Connection Status', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(backendHealthProvider);
                  ref.invalidate(pokeApiHealthProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rows
          _StatusRow(
            label: 'Device network',
            icon: Icons.device_hub_outlined,
            status: switch (isOnline) {
              null => _RowStatus.checking,
              true => _RowStatus.ok,
              false => _RowStatus.error,
            },
            statusText: switch (isOnline) {
              null => 'Checking…',
              true => 'Online',
              false => 'Offline',
            },
          ),
          _StatusRow(
            label: 'PokéAPI',
            icon: Icons.catching_pokemon_outlined,
            status: pokeApiAsync.when(
              loading: () => _RowStatus.checking,
              error: (_, __) => _RowStatus.error,
              data: (s) => s == HealthStatus.healthy ? _RowStatus.ok : _RowStatus.error,
            ),
            statusText: pokeApiAsync.when(
              loading: () => 'Checking…',
              error: (_, __) => 'Unreachable',
              data: (s) => s == HealthStatus.healthy ? 'Healthy' : 'Unreachable',
            ),
          ),
          _StatusRow(
            label: 'Backend API',
            icon: Icons.cloud_outlined,
            status: backendAsync.when(
              loading: () => _RowStatus.checking,
              error: (_, __) => _RowStatus.error,
              data: (s) => s == HealthStatus.healthy ? _RowStatus.ok : _RowStatus.error,
            ),
            statusText: backendAsync.when(
              loading: () => 'Checking…',
              error: (_, __) => 'Unreachable',
              data: (s) => s == HealthStatus.healthy ? 'Healthy' : 'Unreachable',
            ),
          ),
          const Divider(height: 24),
          _StatusRow(
            label: 'Account',
            icon: Icons.person_outline,
            status: isLoggedIn ? _RowStatus.ok : _RowStatus.warn,
            statusText: isLoggedIn ? 'Signed in' : 'Not signed in',
          ),
        ],
      ),
    );
  }
}

// ── Row helpers ───────────────────────────────────────────────────────────────

enum _RowStatus { checking, ok, warn, error }

class _StatusRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final _RowStatus status;
  final String statusText;

  const _StatusRow({
    required this.label,
    required this.icon,
    required this.status,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (dotColor, chipColor) = switch (status) {
      _RowStatus.checking => (colorScheme.onSurfaceVariant, colorScheme.surfaceContainerHighest),
      _RowStatus.ok      => (Colors.green, Colors.green.withValues(alpha: 0.12)),
      _RowStatus.warn    => (Colors.amber, Colors.amber.withValues(alpha: 0.12)),
      _RowStatus.error   => (colorScheme.error, colorScheme.error.withValues(alpha: 0.12)),
    };

    Widget dot = status == _RowStatus.checking
        ? SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: colorScheme.onSurfaceVariant),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: textTheme.bodyMedium),
          const Spacer(),
          dot,
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: textTheme.labelSmall?.copyWith(color: dotColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
