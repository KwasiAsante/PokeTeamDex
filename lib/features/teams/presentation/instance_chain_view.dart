import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';

/// Displays the full instance chain for [instanceId] as a compact vertical
/// timeline:
///
///   [Origin]
///     ↓
///   [Intermediate…]
///     ↓
///   [Current slot]   ← highlighted
///     ↓
///   [Child 1]
///   [Child 2]  (if multiple direct children)
///
/// Each row shows: team name · slot number · nickname (if set).
class InstanceChainView extends ConsumerWidget {
  final int instanceId;

  /// ID of the slot currently being configured — highlighted in the chain.
  final int currentSlotId;

  const InstanceChainView({
    super.key,
    required this.instanceId,
    required this.currentSlotId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainAsync = ref.watch(instanceChainProvider(instanceId));

    return chainAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Could not load chain: $e'),
      data: (chain) {
        if (chain.isEmpty) return const SizedBox.shrink();
        return _ChainList(
          chain: chain,
          currentSlotId: currentSlotId,
        );
      },
    );
  }
}

// ── Chain list ─────────────────────────────────────────────────────────────────

class _ChainList extends ConsumerStatefulWidget {
  final List<PokemonInstance> chain;
  final int currentSlotId;

  const _ChainList({required this.chain, required this.currentSlotId});

  @override
  ConsumerState<_ChainList> createState() => _ChainListState();
}

class _ChainListState extends ConsumerState<_ChainList> {
  /// instance id → slots that reference it
  final _slotCache = <int, List<TeamSlot>>{};
  /// team id → team name
  final _teamCache = <int, String>{};
  /// direct children of the current instance (the last in the chain)
  final _children = <PokemonInstance>[];
  bool _loaded = false;

  // The last instance in the ancestor chain is the one whose id == instanceId
  // (i.e. the current slot's own instance).
  PokemonInstance get _currentInstance => widget.chain.last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);

    // Resolve slots for every ancestor in the chain.
    final teamIdsNeeded = <int>{};
    for (final inst in widget.chain) {
      final slots = await instanceRepo.getSlotsForInstance(inst.id);
      _slotCache[inst.id] = slots;
      teamIdsNeeded.addAll(slots.map((s) => s.teamId));
    }

    // Resolve direct children of the current instance.
    final children =
        await instanceRepo.getDirectChildren(_currentInstance.id);
    for (final child in children) {
      final slots = await instanceRepo.getSlotsForInstance(child.id);
      _slotCache[child.id] = slots;
      teamIdsNeeded.addAll(slots.map((s) => s.teamId));
    }
    _children
      ..clear()
      ..addAll(children);

    // Batch-load team names.
    final allTeams = await teamRepo.getAll();
    for (final t in allTeams) {
      if (teamIdsNeeded.contains(t.id)) {
        _teamCache[t.id] = t.name;
      }
    }

    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    final totalRows = widget.chain.length + _children.length;

    // Accumulate aliases across the ancestor chain so each row shows the full
    // nickname history up to that point (oldest first).
    final accumulated = <String>[];
    final accumulatedPerIndex = <int, List<String>>{};
    for (int i = 0; i < widget.chain.length; i++) {
      final raw = widget.chain[i].nicknameAliases;
      if (raw != null && raw.isNotEmpty) {
        try {
          final parsed = (jsonDecode(raw) as List).cast<String>();
          for (final a in parsed) {
            if (!accumulated.contains(a)) accumulated.add(a);
          }
        } catch (_) {}
      }
      accumulatedPerIndex[i] = List.of(accumulated);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ancestor chain (origin → current) ──
        for (int i = 0; i < widget.chain.length; i++)
          _ChainRow(
            instance: widget.chain[i],
            slots: _slotCache[widget.chain[i].id] ?? [],
            teamCache: _teamCache,
            isOrigin: i == 0,
            isCurrent: (_slotCache[widget.chain[i].id] ?? [])
                .any((s) => s.id == widget.currentSlotId),
            isLast: i == totalRows - 1,
            isChild: false,
            accumulatedAliases: accumulatedPerIndex[i] ?? [],
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),

        // ── Direct children ──
        for (int i = 0; i < _children.length; i++)
          _ChainRow(
            instance: _children[i],
            slots: _slotCache[_children[i].id] ?? [],
            teamCache: _teamCache,
            isOrigin: false,
            isCurrent: false,
            isLast: i == _children.length - 1,
            isChild: true,
            accumulatedAliases: const [],
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

// ── Individual row ─────────────────────────────────────────────────────────────

class _ChainRow extends StatelessWidget {
  final PokemonInstance instance;
  final List<TeamSlot> slots;
  final Map<int, String> teamCache;
  final bool isOrigin;
  final bool isCurrent;
  final bool isChild;
  final bool isLast;
  /// All nicknames accumulated from the chain up to and including this row.
  final List<String> accumulatedAliases;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ChainRow({
    required this.instance,
    required this.slots,
    required this.teamCache,
    required this.isOrigin,
    required this.isCurrent,
    required this.isChild,
    required this.isLast,
    required this.accumulatedAliases,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent
        ? colorScheme.primary
        : isChild
            ? colorScheme.secondary
            : colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline spine ──
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: isOrigin
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Content ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    String? badge;
    if (isOrigin && isCurrent) {
      badge = 'Origin · This slot';
    } else if (isOrigin) {
      badge = 'Origin';
    } else if (isCurrent) {
      badge = 'This slot';
    } else if (isChild) {
      badge = 'Child';
    }

    final badgeBackground = isCurrent
        ? colorScheme.primaryContainer
        : isChild
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest;
    final badgeForeground = isCurrent
        ? colorScheme.onPrimaryContainer
        : isChild
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant;

    final lines = <String>[];
    for (final slot in slots) {
      final teamName = teamCache[slot.teamId] ?? 'Unknown team';
      final nick = slot.nickname?.isNotEmpty == true ? slot.nickname! : null;
      lines.add(
        '$teamName · Slot ${slot.slot}'
        '${nick != null ? ' — "$nick"' : ''}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: textTheme.labelSmall?.copyWith(
                color: badgeForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (lines.isNotEmpty)
          for (final line in lines)
            Text(
              line,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            )
        else
          Text(
            'Unlinked instance',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (accumulatedAliases.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Aliases: ${accumulatedAliases.join(', ')}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
