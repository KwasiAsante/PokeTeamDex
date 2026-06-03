import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';

/// Displays the full instance chain for [instanceId] as a compact vertical
/// timeline — oldest (origin) at the top, current instance at the bottom.
///
/// Each row shows: team name · slot number · nickname (if set).
/// The origin row is labelled "Origin".
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
  // instance id → list of slots referencing it
  final _slotCache = <int, List<TeamSlot>>{};
  // team id → team name
  final _teamCache = <int, String>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadChainData();
  }

  Future<void> _loadChainData() async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);

    // Resolve slots for each instance in the chain.
    final teamIdsNeeded = <int>{};
    for (final inst in widget.chain) {
      final slots = await instanceRepo.getSlotsForInstance(inst.id);
      _slotCache[inst.id] = slots;
      teamIdsNeeded.addAll(slots.map((s) => s.teamId));
    }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.chain.length; i++)
          _ChainRow(
            instance: widget.chain[i],
            slots: _slotCache[widget.chain[i].id] ?? [],
            teamCache: _teamCache,
            isOrigin: i == 0,
            isCurrent: (_slotCache[widget.chain[i].id] ?? [])
                .any((s) => s.id == widget.currentSlotId),
            isLast: i == widget.chain.length - 1,
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
  final bool isLast;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ChainRow({
    required this.instance,
    required this.slots,
    required this.teamCache,
    required this.isOrigin,
    required this.isCurrent,
    required this.isLast,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor =
        isCurrent ? colorScheme.primary : colorScheme.outlineVariant;

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
                        ? Border.all(
                            color: colorScheme.primary, width: 2)
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
    // Determine label badge
    String? badge;
    if (isOrigin) badge = 'Origin';
    if (isCurrent) badge = 'This slot';

    // Collect appearance lines (one per slot)
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
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: textTheme.labelSmall?.copyWith(
                color: isCurrent
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
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
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            )
        else
          Text(
            'Unlinked instance',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        // Nickname aliases from previous appearances
        if (instance.nicknameAliases != null &&
            instance.nicknameAliases!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Previously: ${instance.nicknameAliases}',
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
