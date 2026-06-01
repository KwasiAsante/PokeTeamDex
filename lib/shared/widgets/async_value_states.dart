import 'package:flutter/material.dart';
import 'package:poke_team_dex/shared/widgets/skeleton_box.dart';

// ── Skeleton list / grid ──────────────────────────────────────────────────────

enum SkeletonLeading { none, circle, square }

/// A shimmer tile shaped like a standard [ListTile], used while list data loads.
class _SkeletonTile extends StatelessWidget {
  static const _titleW  = [160.0, 140.0, 180.0];
  static const _sub1W   = [100.0, 80.0, 120.0];
  static const _sub2W   = [70.0, 90.0, 60.0];

  final SkeletonLeading leading;
  final double leadingSize;
  final int subtitleLines;
  final double height;
  final int variantIndex;

  const _SkeletonTile({
    required this.leading,
    required this.leadingSize,
    required this.subtitleLines,
    required this.height,
    required this.variantIndex,
  });

  @override
  Widget build(BuildContext context) {
    final v = variantIndex % 3;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != SkeletonLeading.none) ...[
              SkeletonBox(
                width: leadingSize,
                height: leadingSize,
                borderRadius:
                    leading == SkeletonLeading.circle ? leadingSize / 2 : 6,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: _titleW[v], height: 14),
                  const SizedBox(height: 6),
                  SkeletonBox(width: _sub1W[v], height: 12),
                  if (subtitleLines > 1) ...[
                    const SizedBox(height: 4),
                    SkeletonBox(width: _sub2W[v], height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shimmer card shaped like a reference-browser grid card.
class _SkeletonGridCard extends StatelessWidget {
  static const _titleW = [120.0, 100.0, 140.0];
  static const _subW   = [70.0, 55.0, 85.0];

  final int variantIndex;
  const _SkeletonGridCard({required this.variantIndex});

  @override
  Widget build(BuildContext context) {
    final v = variantIndex % 3;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonBox(width: _subW[v], height: 18),
            const SizedBox(height: 6),
            SkeletonBox(width: _titleW[v], height: 14),
            const SizedBox(height: 4),
            SkeletonBox(width: _subW[v], height: 12),
          ],
        ),
      ),
    );
  }
}

/// A non-scrollable skeleton list that replaces [LoadingState] on list screens.
class SkeletonListView extends StatelessWidget {
  final int count;
  final double itemExtent;
  final SkeletonLeading leading;
  final double leadingSize;
  final int subtitleLines;

  const SkeletonListView({
    super.key,
    this.count = 10,
    this.itemExtent = 72,
    this.leading = SkeletonLeading.circle,
    this.leadingSize = 40,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemExtent: itemExtent,
      itemBuilder: (_, i) => _SkeletonTile(
        leading: leading,
        leadingSize: leadingSize,
        subtitleLines: subtitleLines,
        height: itemExtent,
        variantIndex: i,
      ),
    );
  }
}

/// A non-scrollable skeleton grid that replaces [LoadingState] on grid screens.
/// Supply [mainAxisExtent] for fixed-height cells (reference browsers) or
/// [childAspectRatio] for aspect-ratio cells (Pokédex).
class SkeletonGridView extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double? mainAxisExtent;
  final double childAspectRatio;

  const SkeletonGridView({
    super.key,
    this.count = 10,
    this.crossAxisCount = 2,
    this.mainAxisExtent,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: mainAxisExtent,
        childAspectRatio:
            mainAxisExtent == null ? childAspectRatio : 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (_, i) => _SkeletonGridCard(variantIndex: i),
    );
  }
}

/// Full-screen loading indicator with an optional [message].
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Full-screen error display with an optional [onRetry] callback.
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen empty state with an [icon], [title], and optional [subtitle].
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
