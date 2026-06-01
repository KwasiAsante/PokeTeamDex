import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/skeleton_box.dart';

class AbilitiesScreen extends ConsumerStatefulWidget {
  const AbilitiesScreen({super.key});

  @override
  ConsumerState<AbilitiesScreen> createState() => _AbilitiesScreenState();
}

class _AbilitiesScreenState extends ConsumerState<AbilitiesScreen> {
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(abilitiesSearchProvider);
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
    final filteredAsync = ref.watch(filteredAbilitiesProvider);
    final gen  = ref.watch(abilityGenerationFilterProvider);
    final sort = ref.watch(abilitySortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abilities'),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search abilities…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(abilitiesSearchProvider.notifier)
                              .state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(abilitiesSearchProvider.notifier).state = v,
                ),
              ),
              // Sort + generation filter chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  children: [
                    // Sort toggle
                    FilterChip(
                      label: Text(sort == AbilitySort.nameAZ
                          ? 'A → Z'
                          : 'Z → A'),
                      avatar: const Icon(Icons.sort, size: 16),
                      selected: sort == AbilitySort.nameZA,
                      onSelected: (_) => ref
                          .read(abilitySortProvider.notifier)
                          .state = sort == AbilitySort.nameAZ
                          ? AbilitySort.nameZA
                          : AbilitySort.nameAZ,
                    ),
                    const SizedBox(width: 6),
                    // Generation filter chips
                    for (final entry in kAbilityGenerations.entries) ...[
                      FilterChip(
                        label: Text(entry.value),
                        selected: gen == entry.key,
                        onSelected: (_) => ref
                            .read(abilityGenerationFilterProvider.notifier)
                            .state =
                            gen == entry.key ? null : entry.key,
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Clear filter
                    if (gen != null)
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: const Text('Clear'),
                        onPressed: () => ref
                            .read(
                                abilityGenerationFilterProvider.notifier)
                            .state = null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: filteredAsync.when(
        loading: () => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return SkeletonGridView(count: 12, mainAxisExtent: 96);
            }
            return const SkeletonListView(
              count: 12,
              itemExtent: 88,
              subtitleLines: 2,
            );
          },
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () {
            ref.invalidate(abilitiesListProvider);
            if (gen != null) {
              ref.invalidate(abilitiesByGenerationProvider(gen));
            }
          },
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No abilities found',
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
                    mainAxisExtent: 96,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: names.length,
                  itemBuilder: (_, i) => _AbilityTile(name: names[i], isGrid: true),
                );
              }
              return ListView.builder(
                itemCount: names.length,
                itemExtent: 88,
                itemBuilder: (_, i) => _AbilityTile(name: names[i]),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Ability tile (lazy detail fetch) ─────────────────────────────────────────

class _AbilityTile extends ConsumerWidget {
  final String name;
  final bool isGrid;
  const _AbilityTile({required this.name, this.isGrid = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityProvider(name));

    return abilityAsync.when(
      loading: () => isGrid
          ? _AbilityGridCardSkeleton(name: _fmt(name))
          : ListTile(
              title: Text(_fmt(name)),
              subtitle: const SkeletonBox(width: 200),
            ),
      error: (_, __) => isGrid
          ? Card(margin: EdgeInsets.zero, child: Center(child: Text(_fmt(name))))
          : ListTile(title: Text(_fmt(name)), subtitle: const Text('—')),
      data: (ability) =>
          isGrid ? _AbilityGridCard(ability: ability) : _AbilityListItem(ability: ability),
    );
  }

  static String _fmt(String s) => s
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _AbilityListItem extends StatelessWidget {
  final AbilityEntry ability;
  const _AbilityListItem({required this.ability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.auto_awesome, size: 18, color: colorScheme.onPrimaryContainer),
      ),
      title: Row(
        children: [
          Text(ability.displayName, style: textTheme.bodyLarge),
          if (ability.generationLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ability.generationLabel,
                style: textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ],
      ),
      subtitle: ability.shortEffect != null
          ? Text(
              ability.shortEffect!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            )
          : null,
      onTap: () => context.push('/reference/abilities/${ability.name}'),
    );
  }
}

// ── Ability grid card ─────────────────────────────────────────────────────────

class _AbilityGridCardSkeleton extends StatelessWidget {
  final String name;
  const _AbilityGridCardSkeleton({required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: 4),
            const SkeletonBox(width: 160, height: 12),
          ],
        ),
      ),
    );
  }
}

class _AbilityGridCard extends StatelessWidget {
  final AbilityEntry ability;
  const _AbilityGridCard({required this.ability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reference/abilities/${ability.name}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      ability.displayName,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ability.generationLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ability.generationLabel,
                        style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ],
              ),
              if (ability.shortEffect != null) ...[
                const SizedBox(height: 4),
                Text(
                  ability.shortEffect!,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

