import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';

/// Bottom sheet that lists every other team slot that is a valid evolution-aware
/// link target for [originSlot], following the rules of issue #102:
/// - Only forward-reachable species in the origin's evolution chain are shown.
/// - Regional variants are treated as separate lines.
///
/// Returns the selected [TeamSlot] via [onPick]; the caller is responsible for
/// creating / chaining the instance records.
class InstancePickerSheet extends ConsumerWidget {
  final TeamSlot originSlot;

  /// true  → current slot is the ORIGIN; show forward-evolution (child) candidates.
  /// false → current slot is the CHILD;  show backward-evolution (origin) candidates.
  final bool forwardDirection;

  final void Function(TeamSlot slot) onPick;

  const InstancePickerSheet({
    super.key,
    required this.originSlot,
    required this.forwardDirection,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      originPokemonId: originSlot.pokemonId,
      currentSlotId: originSlot.id,
      originFormName: originSlot.formName,
      forwardDirection: forwardDirection,
    );
    final slotsAsync = ref.watch(linkableSlotsProvider(params));
    final teamsAsync = ref.watch(allTeamsProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollCtrl) => Column(
        children: [
          // ── Handle ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Link to another Pokémon',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: slotsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (slots) {

                if (slots.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No other slots have this Pokémon or its evolutions.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Build team-name lookup from the teams stream.
                final teamMap = <int, String>{
                  for (final t in teamsAsync.asData?.value ?? <Team>[])
                    t.id: t.name,
                };

                // Group slots by team id (preserving team sort order).
                final grouped = <int, List<TeamSlot>>{};
                for (final s in slots) {
                  grouped.putIfAbsent(s.teamId, () => []).add(s);
                }

                return ListView(
                  controller: scrollCtrl,
                  children: [
                    for (final entry in grouped.entries) ...[
                      _TeamHeader(
                        teamName:
                            teamMap[entry.key] ?? 'Team ${entry.key}',
                      ),
                      for (final slot in entry.value)
                        _SlotTile(
                          slot: slot,
                          onTap: () => onPick(slot),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  final String teamName;
  const _TeamHeader({required this.teamName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        teamName,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final TeamSlot slot;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final label = slot.nickname?.isNotEmpty == true
        ? slot.nickname!
        : 'Pokémon #${slot.pokemonId}';
    final hasInstance = slot.instanceId != null;

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: PokemonSprite(
          defaultUrl: pokemonHomeUrl(slot.pokemonId),
          shinyUrl: slot.isShiny ? pokemonHomeShinyUrl(slot.pokemonId) : null,
          shiny: slot.isShiny,
          size: 40,
        ),
      ),
      title: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Slot ${slot.slot}'
        '${slot.level != null ? ' · Lv ${slot.level}' : ''}'
        '${slot.gender != null ? ' · ${slot.gender!.toCapitalCase()}' : ''}',
        style:
            textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: hasInstance
          ? Tooltip(
              message: 'Already tracked',
              child: Icon(Icons.link_rounded,
                  size: 18, color: colorScheme.primary),
            )
          : null,
      onTap: onTap,
    );
  }
}
