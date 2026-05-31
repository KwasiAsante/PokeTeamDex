import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class MovesScreen extends ConsumerStatefulWidget {
  const MovesScreen({super.key});

  @override
  ConsumerState<MovesScreen> createState() => _MovesScreenState();
}

class _MovesScreenState extends ConsumerState<MovesScreen> {
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    // Restore persisted search text so the controller matches the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(movesSearchProvider);
      if (saved.isNotEmpty) _searchController.text = saved;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredMovesProvider);
    final damageClass = ref.watch(movesDamageClassFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moves'),
        actions: [const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search moves…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(movesSearchProvider.notifier).state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(movesSearchProvider.notifier).state = v,
                ),
              ),
              _DamageClassFilter(selected: damageClass),
            ],
          ),
        ),
      ),
      body: filteredAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(movesListProvider),
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No moves found',
              subtitle: 'Try adjusting your search.',
            );
          }
          return ListView.builder(
            itemCount: names.length,
            itemExtent: 72,
            itemBuilder: (_, i) => _MoveTile(name: names[i]),
          );
        },
      ),
    );
  }
}

// ── Damage class filter chips ─────────────────────────────────────────────────

class _DamageClassFilter extends ConsumerWidget {
  final String? selected;
  const _DamageClassFilter({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const classes = ['physical', 'special', 'status'];
    const icons = {'physical': '⚔', 'special': '✨', 'status': '●'};

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final c in classes) ...[
            FilterChip(
              label: Text('${icons[c]} ${_label(c)}'),
              selected: selected == c,
              onSelected: (on) {
                ref.read(movesDamageClassFilterProvider.notifier).state =
                    on ? c : null;
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  static String _label(String c) =>
      '${c[0].toUpperCase()}${c.substring(1)}';
}

// ── Move tile (lazy detail fetch) ─────────────────────────────────────────────

class _MoveTile extends ConsumerWidget {
  final String name;
  const _MoveTile({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveProvider(name));
    final damageClass = ref.watch(movesDamageClassFilterProvider);

    return moveAsync.when(
      loading: () => ListTile(
        title: Text(_fmt(name)),
        subtitle: const LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(
        title: Text(_fmt(name)),
        subtitle: const Text('—'),
      ),
      data: (move) {
        // Client-side damage class filter (applied after lazy fetch)
        if (damageClass != null && move.damageClass != damageClass) {
          return const SizedBox.shrink();
        }
        return _MoveListItem(move: move);
      },
    );
  }

  static String _fmt(String s) => s
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _MoveListItem extends StatelessWidget {
  final MoveEntry move;
  const _MoveListItem({required this.move});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = move.typeName != null
        ? (PokemonTypeColors.colors[move.typeName] ?? colorScheme.primary)
        : colorScheme.outlineVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: typeColor.withValues(alpha: 0.15),
        child: Text(
          move.categoryIcon,
          style: textTheme.titleSmall?.copyWith(color: typeColor),
        ),
      ),
      title: Text(move.displayName, style: textTheme.bodyLarge),
      subtitle: Row(
        children: [
          if (move.typeName != null)
            _TypeChip(type: move.typeName!, color: typeColor),
          if (move.power != null) ...[
            const SizedBox(width: 8),
            Text(
              'Pwr ${move.power}',
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (move.accuracy != null) ...[
            const SizedBox(width: 8),
            Text(
              'Acc ${move.accuracy}%',
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (move.pp != null) ...[
            const SizedBox(width: 8),
            Text(
              'PP ${move.pp}',
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      onTap: () => _showMoveDetail(context, move),
    );
  }

  void _showMoveDetail(BuildContext context, MoveEntry move) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MoveDetailSheet(move: move),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeChip({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${type[0].toUpperCase()}${type.substring(1)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ── Move detail bottom sheet ──────────────────────────────────────────────────

class _MoveDetailSheet extends StatelessWidget {
  final MoveEntry move;
  const _MoveDetailSheet({required this.move});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = move.typeName != null
        ? (PokemonTypeColors.colors[move.typeName] ?? colorScheme.primary)
        : colorScheme.primary;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            move.displayName,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (move.typeName != null)
                _TypeChip(type: move.typeName!, color: typeColor),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${move.categoryIcon} ${move.damageClass ?? '—'}',
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StatRow(label: 'Power', value: move.power?.toString() ?? '—'),
          _StatRow(label: 'Accuracy', value: move.accuracy != null ? '${move.accuracy}%' : '—'),
          _StatRow(label: 'PP', value: move.pp?.toString() ?? '—'),
          const Divider(height: 28),
          if (move.shortEffect != null) ...[
            Text('Effect', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(move.shortEffect!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
