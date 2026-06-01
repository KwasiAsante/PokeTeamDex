import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class SyncMonitorScreen extends ConsumerStatefulWidget {
  const SyncMonitorScreen({super.key});

  @override
  ConsumerState<SyncMonitorScreen> createState() => _SyncMonitorScreenState();
}

class _SyncMonitorScreenState extends ConsumerState<SyncMonitorScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update relative timestamps every second
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncNow() {
    final token = ref.read(authTokenProvider);
    final loggedIn = token != null && token.isNotEmpty;
    if (!loggedIn) {
      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
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

  void _refreshHealth() {
    ref.invalidate(backendHealthProvider);
    ref.invalidate(pokeApiHealthProvider);
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final pendingOps = ref.watch(pendingSyncOpsProvider);
    final backendHealth = ref.watch(backendHealthProvider);
    final pokeApiHealth = ref.watch(pokeApiHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh health checks',
            onPressed: _refreshHealth,
          ),
          const ConnectivityStatusButton(),
          const SettingsButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sync status ──────────────────────────────────────────────────────
          _SyncStatusCard(syncState: syncState, now: _now, onSyncNow: _syncNow),
          const SizedBox(height: 16),

          // ── API health ───────────────────────────────────────────────────────
          _HealthCard(
            backendHealth: backendHealth,
            pokeApiHealth: pokeApiHealth,
            onRefresh: _refreshHealth,
          ),
          const SizedBox(height: 16),

          // ── Pending queue ────────────────────────────────────────────────────
          _PendingQueueCard(
            pendingCount: pendingCount,
            pendingOps: pendingOps,
            now: _now,
          ),
        ],
      ),
    );
  }
}

// ── Sync status card ──────────────────────────────────────────────────────────

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.syncState,
    required this.now,
    required this.onSyncNow,
  });

  final SyncState syncState;
  final DateTime now;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (syncState.status) {
      SyncStatus.idle => (Icons.cloud_outlined, Colors.grey, 'Idle'),
      SyncStatus.syncing => (Icons.sync, Colors.blue, 'Syncing…'),
      SyncStatus.success => (Icons.cloud_done_outlined, Colors.green, 'Up to date'),
      SyncStatus.error => (Icons.cloud_off_outlined, Colors.red, 'Sync error'),
    };

    final lastSync = syncState.lastSyncAt;
    final nextSync = lastSync?.add(const Duration(hours: 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                syncState.status == SyncStatus.syncing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (syncState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                syncState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Last sync',
                        value: lastSync != null
                            ? _relative(now.difference(lastSync))
                            : 'Never',
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        label: 'Next scheduled',
                        value: nextSync != null
                            ? nextSync.isBefore(now)
                                ? 'Due now'
                                : 'in ${_relative(nextSync.difference(now))}'
                            : '—',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: syncState.status == SyncStatus.syncing
                      ? null
                      : onSyncNow,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Health card ───────────────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.backendHealth,
    required this.pokeApiHealth,
    required this.onRefresh,
  });

  final AsyncValue<HealthStatus> backendHealth;
  final AsyncValue<HealthStatus> pokeApiHealth;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Health',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _HealthRow(label: 'Backend API', status: backendHealth),
            const SizedBox(height: 8),
            _HealthRow(label: 'PokéAPI', status: pokeApiHealth),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.status});
  final String label;
  final AsyncValue<HealthStatus> status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = status.when(
      loading: () => (Icons.circle, Colors.grey, 'Checking…'),
      error: (_, __) => (Icons.cancel_outlined, Colors.red, 'Error'),
      data: (h) => switch (h) {
        HealthStatus.healthy =>
          (Icons.check_circle_outline, Colors.green, 'Reachable'),
        HealthStatus.unreachable =>
          (Icons.cancel_outlined, Colors.red, 'Unreachable'),
        HealthStatus.checking =>
          (Icons.circle, Colors.grey, 'Checking…'),
      },
    );

    return Row(
      children: [
        status.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label),
        const Spacer(),
        Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Pending queue card ────────────────────────────────────────────────────────

class _PendingQueueCard extends StatelessWidget {
  const _PendingQueueCard({
    required this.pendingCount,
    required this.pendingOps,
    required this.now,
  });

  final AsyncValue<int> pendingCount;
  final AsyncValue<List<PendingSyncOp>> pendingOps;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final count = pendingCount.when(
      data: (v) => v,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pending Queue',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (count > 0)
                  Badge(
                    label: Text('$count'),
                    child: const Icon(Icons.pending_outlined),
                  )
                else
                  const Icon(Icons.check_circle_outline, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            pendingOps.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (ops) => ops.isEmpty
                  ? const Text('No pending operations',
                      style: TextStyle(color: Colors.grey))
                  : Column(
                      children: ops
                          .map((op) => _PendingOpTile(op: op, now: now))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingOpTile extends StatelessWidget {
  const _PendingOpTile({required this.op, required this.now});
  final PendingSyncOp op;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final age = _relative(now.difference(op.createdAt));
    final opColor = switch (op.operation) {
      'create' => Colors.green,
      'update' => Colors.blue,
      'delete' => Colors.red,
      _ => Colors.orange,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: opColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              op.operation.toUpperCase(),
              style: TextStyle(
                  color: opColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              op.entityType.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (op.attempts > 0)
            Text('${op.attempts} attempts',
                style: const TextStyle(color: Colors.orange, fontSize: 11)),
          const SizedBox(width: 8),
          Text(age,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _relative(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  return '${d.inHours}h ago';
}
