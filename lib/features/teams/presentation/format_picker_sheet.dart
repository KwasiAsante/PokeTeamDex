import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';

/// Bottom sheet for picking a [GameFormat].
/// Returns the selected format via [Navigator.pop], or null to clear.
///
/// Usage: show via showModalBottomSheet with isScrollControlled: true.
/// Returns the selected GameFormat, a _ClearFormat sentinel (use
/// [isFormatCleared] to detect), or null if dismissed.
class FormatPickerSheet extends ConsumerWidget {
  /// The format id currently assigned to the team (may be null).
  final String? current;

  const FormatPickerSheet({super.key, this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatsAsync = ref.watch(allFormatsProvider);
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Text('Select Format', style: textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Clear option ──
          ListTile(
            dense: true,
            leading: const Icon(Icons.block_outlined, size: 18),
            title: const Text('No format'),
            selected: current == null,
            trailing: current == null ? const Icon(Icons.check, size: 16) : null,
            onTap: () => Navigator.pop(context, _kClearSentinel),
          ),
          const Divider(height: 1),

          // ── Format list ──
          Expanded(
            child: formatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (formats) {
                final general =
                    formats.where((f) => f.type == FormatType.general).toList();
                final byGame =
                    formats.where((f) => f.type == FormatType.game).toList();

                // Group game formats by generation
                final gameByGen = <int, List<GameFormat>>{};
                for (final f in byGame) {
                  gameByGen.putIfAbsent(f.gen, () => []).add(f);
                }

                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // ── General section ──
                    _SectionHeader('General'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: general.map((f) {
                          final selected = current == f.id;
                          return ChoiceChip(
                            label: Text(f.short),
                            selected: selected,
                            onSelected: (_) => Navigator.pop(context, f),
                            tooltip: f.name,
                          );
                        }).toList(),
                      ),
                    ),

                    // ── By Game section ──
                    _SectionHeader('By Game'),
                    for (final gen in gameByGen.keys.toList()..sort())
                      _GenGroup(
                        gen: gen,
                        formats: gameByGen[gen]!,
                        current: current,
                      ),
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

/// Sentinel value returned when the user taps "No format".
/// Callers check for this to distinguish "dismissed" from "cleared".
const _kClearSentinel = _ClearFormat();

class _ClearFormat extends GameFormat {
  const _ClearFormat()
      : super(id: '', name: '', short: '', type: FormatType.general, gen: 0);
}

/// Returns true when the value from [showModalBottomSheet] means "clear format".
bool isFormatCleared(GameFormat? result) => result is _ClearFormat;

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _GenGroup extends StatelessWidget {
  final int gen;
  final List<GameFormat> formats;
  final String? current;

  const _GenGroup({
    required this.gen,
    required this.formats,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Text(
            'Gen $gen',
            style: textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        for (final f in formats)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(f.name, style: textTheme.bodyMedium),
            selected: current == f.id,
            trailing: current == f.id
                ? const Icon(Icons.check, size: 16)
                : null,
            onTap: () => Navigator.pop(context, f),
          ),
      ],
    );
  }
}
