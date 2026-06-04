import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/services/format/format_providers.dart' show allFormatsProvider, formatServiceProvider;
import 'package:poke_team_dex/shared/widgets/move_type_chip.dart';
import 'package:poke_team_dex/shared/widgets/skeleton_box.dart';

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
    final typeFilter  = ref.watch(movesTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moves'),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
        bottom: PreferredSize(
          // Search (60) + damage class row (44) + type row (44)
          preferredSize: const Size.fromHeight(148),
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
                        tooltip: 'Clear search',
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
              _TypeFilter(selected: typeFilter),
            ],
          ),
        ),
      ),
      body: filteredAsync.when(
        loading: () => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return SkeletonGridView(count: 12, mainAxisExtent: 84);
            }
            return const SkeletonListView(count: 12, itemExtent: 72);
          },
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () {
            ref.invalidate(movesListProvider);
            if (typeFilter != null) {
              ref.invalidate(movesByTypeProvider(typeFilter));
            }
          },
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No moves found',
              subtitle: 'Try adjusting your search or filter.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              // Damage class filter is applied lazily after fetch, so grid
              // mode would leave empty cells — fall back to list when active.
              final isGrid = constraints.maxWidth >= 600 && damageClass == null;
              if (isGrid) {
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 84,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: names.length,
                  itemBuilder: (_, i) => _MoveTile(name: names[i], isGrid: true),
                );
              }
              return ListView.builder(
                itemCount: names.length,
                itemExtent: (damageClass == null && typeFilter == null) ? 72.0 : null,
                itemBuilder: (_, i) => _MoveTile(name: names[i]),
              );
            },
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

// ── Type filter chips ─────────────────────────────────────────────────────────

class _TypeFilter extends ConsumerWidget {
  final String? selected;
  const _TypeFilter({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = PokemonTypeColors.colors.keys
        .where((t) => t != 'unknown')
        .toList()
      ..sort();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final type in types) ...[
            FilterChip(
              label: Text(
                  '${type[0].toUpperCase()}${type.substring(1)}'),
              selected: selected == type,
              selectedColor: (PokemonTypeColors.colors[type] ??
                      Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.3),
              onSelected: (_) =>
                  ref.read(movesTypeFilterProvider.notifier).state =
                      selected == type ? null : type,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ── Move tile (lazy detail fetch) ─────────────────────────────────────────────

class _MoveTile extends ConsumerWidget {
  final String name;
  final bool isGrid;
  const _MoveTile({required this.name, this.isGrid = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveProvider(name));
    final damageClass = ref.watch(movesDamageClassFilterProvider);

    return moveAsync.when(
      loading: () => isGrid
          ? _MoveGridCardSkeleton(name: _fmt(name))
          : ListTile(
              title: Text(_fmt(name)),
              subtitle: const SkeletonBox(width: 140),
            ),
      error: (_, _) => isGrid
          ? Card(margin: EdgeInsets.zero, child: Center(child: Text(_fmt(name))))
          : ListTile(title: Text(_fmt(name)), subtitle: const Text('—')),
      data: (move) {
        // Client-side damage class filter (applied after lazy fetch)
        if (damageClass != null && move.damageClass != damageClass) {
          return const SizedBox.shrink();
        }
        return isGrid ? _MoveGridCard(move: move) : _MoveListItem(move: move);
      },
    );
  }

  static String _fmt(String s) => s
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _MoveListItem extends ConsumerWidget {
  final MoveEntry move;
  const _MoveListItem({required this.move});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(allFormatsProvider); // ensures service is initialized; triggers rebuild when ready
    final special = classifyMoveType(ref.read(formatServiceProvider), move.name);
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
          if (special != null) ...[
            const SizedBox(width: 4),
            MoveTypeChip(type: special),
          ],
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
      onTap: () => context.push('/moves/${move.name}'),
    );
  }
}

// ── Move grid card ────────────────────────────────────────────────────────────

class _MoveGridCardSkeleton extends StatelessWidget {
  final String name;
  const _MoveGridCardSkeleton({required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SkeletonBox(width: 60, height: 18),
            const SizedBox(height: 6),
            Text(name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            const SkeletonBox(width: 80, height: 12),
          ],
        ),
      ),
    );
  }
}

class _MoveGridCard extends ConsumerWidget {
  final MoveEntry move;
  const _MoveGridCard({required this.move});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(allFormatsProvider); // ensures service is initialized; triggers rebuild when ready
    final special = classifyMoveType(ref.read(formatServiceProvider), move.name);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = move.typeName != null
        ? (PokemonTypeColors.colors[move.typeName] ?? colorScheme.primary)
        : colorScheme.outlineVariant;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/moves/${move.name}'),
        child: Row(
          children: [
            Container(width: 4, color: typeColor),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (move.typeName != null)
                          _TypeChip(type: move.typeName!, color: typeColor),
                        if (special != null) ...[
                          const SizedBox(width: 4),
                          MoveTypeChip(type: special),
                        ],
                        const Spacer(),
                        Text(
                          move.categoryIcon,
                          style:
                              textTheme.bodySmall?.copyWith(color: typeColor),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      move.displayName,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (move.power != null)
                          Text('Pwr ${move.power}',
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        if (move.power != null && move.accuracy != null)
                          const SizedBox(width: 6),
                        if (move.accuracy != null)
                          Text('Acc ${move.accuracy}%',
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        if (move.pp != null) ...[
                          const SizedBox(width: 6),
                          Text('PP ${move.pp}',
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

