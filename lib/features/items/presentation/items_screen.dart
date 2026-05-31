import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        actions: [const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
        ),
      ),
      body: filteredAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(itemsListProvider),
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No items found',
              subtitle: 'Try adjusting your search.',
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

