import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/move_type_chip.dart' show MoveTypeChip, classifyMoveType;

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
          onRetry: () => ref.invalidate(movesListProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No moves found',
              subtitle: 'Try adjusting your search or filter.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isGrid = constraints.maxWidth >= 600;
              if (isGrid) {
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 84,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _MoveTile(entry: entries[i], isGrid: true),
                );
              }
              return ListView.builder(
                itemCount: entries.length,
                itemExtent: 72.0,
                itemBuilder: (_, i) => _MoveTile(entry: entries[i]),
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
    const classes = ['physical', 'special', 'status', 'varies'];
    const icons = {'physical': '⚔', 'special': '✨', 'status': '●', 'varies': '↕'};

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

// ── Move tile ─────────────────────────────────────────────────────────────────

class _MoveTile extends StatelessWidget {
  final BackendMoveEntry entry;
  final bool isGrid;
  const _MoveTile({required this.entry, this.isGrid = false});

  @override
  Widget build(BuildContext context) =>
      isGrid ? _MoveGridCard(entry: entry) : _MoveListItem(entry: entry);
}

class _MoveListItem extends ConsumerWidget {
  final BackendMoveEntry entry;
  const _MoveListItem({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final special = classifyMoveType(entry);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = entry.type.isNotEmpty
        ? (PokemonTypeColors.colors[entry.type] ?? colorScheme.primary)
        : colorScheme.outlineVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: typeColor.withValues(alpha: 0.15),
        child: Text(
          _categoryIcon(entry.damageClass),
          style: textTheme.titleSmall?.copyWith(color: typeColor),
        ),
      ),
      title: Text(entry.displayName, style: textTheme.bodyLarge),
      subtitle: Row(
        children: [
          if (entry.type.isNotEmpty)
            _TypeChip(type: entry.type, color: typeColor),
          if (special != null) ...[
            const SizedBox(width: 4),
            MoveTypeChip(type: special),
          ],
          if (entry.power != null) ...[
            const SizedBox(width: 8),
            Text('Pwr ${entry.power}',
                style: textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          if (entry.accuracy != null) ...[
            const SizedBox(width: 8),
            Text('Acc ${entry.accuracy}%',
                style: textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          if (entry.pp != null) ...[
            const SizedBox(width: 8),
            Text('PP ${entry.pp}',
                style: textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      onTap: entry.name.contains('g-max')
          ? null
          : () => context.push('/moves/${entry.name}'),
    );
  }
}

// ── Move grid card ────────────────────────────────────────────────────────────

class _MoveGridCard extends ConsumerWidget {
  final BackendMoveEntry entry;
  const _MoveGridCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final special = classifyMoveType(entry);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = entry.type.isNotEmpty
        ? (PokemonTypeColors.colors[entry.type] ?? colorScheme.primary)
        : colorScheme.outlineVariant;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.name.contains('g-max')
            ? null
            : () => context.push('/moves/${entry.name}'),
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
                        if (entry.type.isNotEmpty)
                          _TypeChip(type: entry.type, color: typeColor),
                        if (special != null) ...[
                          const SizedBox(width: 4),
                          MoveTypeChip(type: special),
                        ],
                        const Spacer(),
                        Text(
                          _categoryIcon(entry.damageClass),
                          style: textTheme.bodySmall?.copyWith(color: typeColor),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.displayName,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (entry.power != null)
                          Text('Pwr ${entry.power}',
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        if (entry.power != null && entry.accuracy != null)
                          const SizedBox(width: 6),
                        if (entry.accuracy != null)
                          Text('Acc ${entry.accuracy}%',
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                        if (entry.pp != null) ...[
                          const SizedBox(width: 6),
                          Text('PP ${entry.pp}',
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

String _categoryIcon(String damageClass) => switch (damageClass) {
      'physical' => '⚔',
      'special'  => '✨',
      'status'   => '●',
      'varies'   => '↕',
      _          => '—',
    };

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

