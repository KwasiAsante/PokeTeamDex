import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
///     [Grandchild 1]
///   [Child 2]  (if the current instance branches into multiple children)
///
/// The full descendant tree is shown below the current slot — not just
/// direct children — mirroring the full ancestor chain shown above it.
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
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: _ChainList(
              chain: chain,
              currentSlotId: currentSlotId,
            ),
          ),
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
  /// Every descendant of the current instance (children, grandchildren, …),
  /// depth-first pre-order, paired with depth relative to the current
  /// instance (1 = direct child, 2 = grandchild, …).
  final _descendants = <(PokemonInstance instance, int depth)>[];
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

    // Resolve the full descendant tree of the current instance — not just
    // direct children, but their children too (and so on), mirroring the
    // full ancestor chain shown above.
    final descendants =
        await instanceRepo.getDescendantTree(_currentInstance.id);
    for (final (child, _) in descendants) {
      final slots = await instanceRepo.getSlotsForInstance(child.id);
      _slotCache[child.id] = slots;
      teamIdsNeeded.addAll(slots.map((s) => s.teamId));
    }
    _descendants
      ..clear()
      ..addAll(descendants);

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

    final totalRows = widget.chain.length + _descendants.length;

    // Accumulate aliases across the ancestor chain so each row shows the full
    // nickname history up to that point (oldest first).
    final accumulated = <String>[];
    final accumulatedPerIndex = <int, List<String>>{};
    for (int i = 0; i < widget.chain.length; i++) {
      final inst = widget.chain[i];

      // Include current active nicknames from all slots referencing this instance
      // (skip the slot currently being configured — its name is shown elsewhere).
      for (final slot in (_slotCache[inst.id] ?? [])) {
        if (slot.id != widget.currentSlotId) {
          final nick = slot.nickname;
          if (nick != null && nick.isNotEmpty && !accumulated.contains(nick)) {
            accumulated.add(nick);
          }
        }
      }

      // Include superseded nicknames stored in the instance's alias history.
      // Skip for the current instance — its nicknameAliases are the current
      // slot's own rename history, not names inherited from prior appearances.
      final isCurrentInstance = inst.id == _currentInstance.id;
      if (!isCurrentInstance) {
        final raw = inst.nicknameAliases;
        if (raw != null && raw.isNotEmpty) {
          try {
            final parsed = (jsonDecode(raw) as List).cast<String>();
            for (final a in parsed) {
              if (!accumulated.contains(a)) accumulated.add(a);
            }
          } catch (_) {}
        }
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

        // ── Descendants (children, grandchildren, …) ──
        for (int i = 0; i < _descendants.length; i++)
          _ChainRow(
            instance: _descendants[i].$1,
            slots: _slotCache[_descendants[i].$1.id] ?? [],
            teamCache: _teamCache,
            isOrigin: false,
            isCurrent: false,
            isLast: i == _descendants.length - 1,
            isChild: true,
            depth: _descendants[i].$2,
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
  /// Depth of a descendant row relative to the current instance
  /// (1 = direct child, 2 = grandchild, …). Unused for non-descendant rows.
  final int depth;
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
    this.depth = 0,
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
              child: _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    String? badge;
    if (isOrigin && isCurrent) {
      badge = 'Origin · This slot';
    } else if (isOrigin) {
      badge = 'Origin';
    } else if (isCurrent) {
      badge = 'This slot';
    } else if (isChild) {
      badge = switch (depth) {
        1 => 'Child',
        2 => 'Grandchild',
        _ => 'Descendant',
      };
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

    final content = Column(
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
        if (slots.isNotEmpty)
          for (final slot in slots)
            _SlotLine(
              slot: slot,
              teamName: teamCache[slot.teamId] ?? 'Unknown team',
              tappable: !isCurrent,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onTap: !isCurrent
                  ? () => context.go('/teams/${slot.teamId}/config/${slot.slot}')
                  : null,
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

    // Indent deeper descendants (grandchildren, …) so the branching of the
    // evolution tree below the current instance reads as a hierarchy rather
    // than a flat list — direct children (depth 1) stay flush with ancestors.
    if (depth <= 1) return content;
    return Padding(
      padding: EdgeInsets.only(left: (depth - 1) * 16.0),
      child: content,
    );
  }
}

// ── Slot line ──────────────────────────────────────────────────────────────────

class _SlotLine extends StatelessWidget {
  final TeamSlot slot;
  final String teamName;
  final bool tappable;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SlotLine({
    required this.slot,
    required this.teamName,
    required this.tappable,
    required this.colorScheme,
    required this.textTheme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nick = slot.nickname?.isNotEmpty == true ? slot.nickname! : null;
    final label = '$teamName · Slot ${slot.slot}'
        '${nick != null ? ' — "$nick"' : ''}';

    final text = Text(
      label,
      style: textTheme.bodySmall?.copyWith(
        color: tappable ? colorScheme.primary : colorScheme.onSurface,
        decoration: tappable ? TextDecoration.underline : null,
        decorationColor: tappable ? colorScheme.primary : null,
      ),
    );

    if (!tappable) return text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            text,
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
