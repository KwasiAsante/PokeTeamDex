import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemName;
  const ItemDetailScreen({super.key, required this.itemName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(itemName));

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_fmt(itemName))),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(_fmt(itemName))),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(itemProvider(itemName)),
        ),
      ),
      data: (item) => _ItemDetailContent(item: item),
    );
  }
}

class _ItemDetailContent extends StatelessWidget {
  final ItemEntry item;
  const _ItemDetailContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayName),
        actions: [const SettingsButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              color: colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sprite
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: item.spriteUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.spriteUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (item.categoryLabel.isNotEmpty)
                          _Chip(label: item.categoryLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Details ──
            if (item.cost != null && item.cost! > 0) ...[
              _Section(
                title: 'Price',
                child: Text('₽${item.cost}', style: textTheme.bodyMedium),
              ),
            ],

            // ── Effect ──
            if (item.shortEffect != null)
              _Section(
                title: 'Effect',
                child: Text(item.shortEffect!, style: textTheme.bodyMedium),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(String s) => s
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
