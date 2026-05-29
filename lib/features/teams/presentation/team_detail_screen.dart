import 'package:change_case/change_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

// ── Provider for a single team's slots ───────────────────────────────────────

final teamSlotsProvider =
    StreamProvider.autoDispose.family<List<TeamSlot>, int>((ref, teamId) {
  return ref.watch(teamSlotRepositoryProvider).watchByTeam(teamId);
});

final teamByIdProvider =
    StreamProvider.autoDispose.family<Team?, int>((ref, teamId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.teams)..where((t) => t.id.equals(teamId)))
      .watchSingleOrNull();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class TeamDetailScreen extends ConsumerWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final slotsAsync = ref.watch(teamSlotsProvider(teamId));

    return teamAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(error: e)),
      data: (team) {
        if (team == null) {
          // Team was deleted — pop back
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.canPop()) context.pop();
          });
          return const Scaffold(body: LoadingState());
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(team.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
                onPressed: () => _renameTeam(context, ref, team),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete team',
                onPressed: () => _deleteTeam(context, ref, team),
              ),
              const SettingsButton(),
            ],
          ),
          body: slotsAsync.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(error: e),
            data: (slots) => _SlotGrid(teamId: teamId, slots: slots),
          ),
        );
      },
    );
  }

  Future<void> _renameTeam(
      BuildContext context, WidgetRef ref, Team team) async {
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await renameTeam(ref, team.id, name);
    }
  }

  Future<void> _deleteTeam(
      BuildContext context, WidgetRef ref, Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Delete "${team.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteTeam(ref, team.id);
      if (context.mounted) context.pop();
    }
  }
}

// ── 6-slot grid ───────────────────────────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  final int teamId;
  final List<TeamSlot> slots;

  const _SlotGrid({required this.teamId, required this.slots});

  @override
  Widget build(BuildContext context) {
    final slotMap = {for (final s in slots) s.slot: s};

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 6,
      itemBuilder: (_, i) {
        final slotNumber = i + 1;
        final slot = slotMap[slotNumber];
        return slot != null
            ? _FilledSlotCard(slot: slot, teamId: teamId)
            : _EmptySlotCard(teamId: teamId, slotNumber: slotNumber);
      },
    );
  }
}

// ── Filled slot card ──────────────────────────────────────────────────────────

class _FilledSlotCard extends ConsumerWidget {
  final TeamSlot slot;
  final int teamId;

  const _FilledSlotCard({required this.slot, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemonAsync = ref.watch(pokemonDetailProvider(slot.pokemonId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return pokemonAsync.when(
      loading: () => Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('Slot ${slot.slot}', style: textTheme.labelSmall),
            ],
          ),
        ),
      ),
      error: (e, _) => Card(
        child: Center(
          child: Text('Error', style: textTheme.bodySmall),
        ),
      ),
      data: (pokemon) {
        final primaryType = pokemon.types[1] ?? pokemon.types.values.first;
        final typeColor =
            PokemonTypeColors.colors[primaryType] ?? colorScheme.primary;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/pokedex/${slot.pokemonId}'),
            onLongPress: () => _showSlotMenu(context, ref),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    typeColor.withValues(alpha: 0.15),
                    typeColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PokemonSprite(
                    defaultUrl: 'https://raw.githubusercontent.com/PokeAPI/'
                        'sprites/master/sprites/pokemon/${slot.pokemonId}.png',
                    size: 72,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.nickname?.isNotEmpty == true
                        ? slot.nickname!
                        : pokemon.name.toCapitalCase(),
                    style: textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pokemon.types.values
                        .map((t) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: TypeBadge(type: t),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Slot ${slot.slot}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSlotMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit nickname'),
              onTap: () => Navigator.pop(ctx, 'nickname'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace Pokémon'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove from team'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == 'nickname') {
      final controller = TextEditingController(text: slot.nickname ?? '');
      final nickname = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit Nickname'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nickname (optional)'),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Save')),
          ],
        ),
      );
      if (nickname != null) {
        await ref.read(teamSlotRepositoryProvider).update(
              TeamSlotsCompanion(
                id: Value(slot.id),
                teamId: Value(slot.teamId),
                slot: Value(slot.slot),
                pokemonId: Value(slot.pokemonId),
                nickname: Value(nickname.isEmpty ? null : nickname),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    } else if (action == 'replace') {
      context.push('/teams/$teamId/pick/${slot.slot}');
    } else if (action == 'remove') {
      await ref
          .read(teamSlotRepositoryProvider)
          .deleteSlot(slot.teamId, slot.slot);
    }
  }
}

// ── Empty slot card ───────────────────────────────────────────────────────────

class _EmptySlotCard extends StatelessWidget {
  final int teamId;
  final int slotNumber;

  const _EmptySlotCard({required this.teamId, required this.slotNumber});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: () => context.push('/teams/$teamId/pick/$slotNumber'),
        borderRadius: BorderRadius.circular(12),
        child: DottedBorder(
          color: colorScheme.outlineVariant,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 36,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 6),
              Text(
                'Slot $slotNumber',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Tap to add',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dotted border helper ──────────────────────────────────────────────────────

class DottedBorder extends StatelessWidget {
  final Color color;
  final Widget child;

  const DottedBorder({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: color),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox.expand(child: Center(child: child)),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 12.0;
    final rect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(radius));
    final path = Path()..addRRect(rect);
    final metricsIt = path.computeMetrics().iterator;

    while (metricsIt.moveNext()) {
      final metric = metricsIt.current;
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
              distance, (distance + dashWidth).clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter old) => old.color != color;
}
