import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';


class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(itemsSearchProvider);
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
    final filteredAsync = ref.watch(filteredItemsProvider);
    final pocket = ref.watch(itemPocketFilterProvider);
    final sort = ref.watch(itemSortProvider);

    // Persist filter/sort state across tab switches
    ref.listen(itemPocketFilterProvider, (_, __) {});
    ref.listen(itemSortProvider, (_, __) {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search items…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(itemsSearchProvider.notifier).state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(itemsSearchProvider.notifier).state = v,
                ),
              ),
              // Sort + category filter chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  children: [
                    // Sort picker chip
                    _SortChip(current: sort),
                    const SizedBox(width: 6),
                    // Pocket filter chips
                    for (final entry in kItemPockets.entries) ...[
                      FilterChip(
                        label: Text(entry.value),
                        selected: pocket == entry.key,
                        onSelected: (_) => ref
                            .read(itemPocketFilterProvider.notifier)
                            .state = pocket == entry.key
                            ? null
                            : entry.key,
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Clear filter
                    if (pocket != null)
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: const Text('Clear'),
                        onPressed: () => ref
                            .read(itemPocketFilterProvider.notifier)
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
        loading: () => const LoadingState(message: 'Loading items…'),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () {
            ref.invalidate(itemsListProvider);
            if (pocket != null) ref.invalidate(itemsByPocketProvider(pocket));
          },
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No items found',
              subtitle: 'Try adjusting your search or filter.',
            );
          }
          return ListView.builder(
            itemCount: names.length,
            itemExtent: 72,
            itemBuilder: (_, i) => _ItemTile(name: names[i]),
          );
        },
      ),
    );
  }
}

// ── Sort picker chip ──────────────────────────────────────────────────────────

class _SortChip extends ConsumerWidget {
  final ItemSort current;
  const _SortChip({required this.current});

  static const _options = [
    (ItemSort.idAscending,  'ID ↑',      'Lowest ID first'),
    (ItemSort.idDescending, 'ID ↓',      'Highest ID first'),
    (ItemSort.nameAZ,       'Name A → Z', 'Alphabetical'),
    (ItemSort.nameZA,       'Name Z → A', 'Reverse alphabetical'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _options
        .firstWhere((o) => o.$1 == current,
            orElse: () => _options.first)
        .$2;

    return FilterChip(
      label: Text(label),
      avatar: const Icon(Icons.sort, size: 16),
      selected: current != ItemSort.idAscending,
      onSelected: (_) => _showPicker(context, ref),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sort by',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          for (final (sort, label, subtitle) in _options)
            ListTile(
              title: Text(label),
              subtitle: Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
              trailing: current == sort
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(itemSortProvider.notifier).state = sort;
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Item tile (lazy detail fetch) ─────────────────────────────────────────────

class _ItemTile extends ConsumerWidget {
  final String name;
  const _ItemTile({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(name));

    return itemAsync.when(
      loading: () => ListTile(
        title: Text(_fmt(name)),
        subtitle: const LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(
        title: Text(_fmt(name)),
        subtitle: const Text('—'),
      ),
      data: (item) => _ItemListItem(item: item),
    );
  }

  static String _fmt(String s) => s
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _ItemListItem extends StatelessWidget {
  final ItemEntry item;
  const _ItemListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        height: 40,
        child: item.spriteUrl != null
            ? CachedNetworkImage(
                imageUrl: item.spriteUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(
                Icons.inventory_2_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
      ),
      title: Text(item.displayName, style: textTheme.bodyLarge),
      subtitle: Row(
        children: [
          if (item.categoryLabel.isNotEmpty)
            _CategoryChip(label: item.categoryLabel),
          if (item.cost != null && item.cost! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '₽${item.cost}',
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/items/${item.name}'),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onTertiaryContainer,
            ),
      ),
    );
  }
}

