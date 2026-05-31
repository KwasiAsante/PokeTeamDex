import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class MoveDetailScreen extends ConsumerWidget {
  final String moveName;
  const MoveDetailScreen({super.key, required this.moveName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveProvider(moveName));

    return moveAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_fmt(moveName))),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(_fmt(moveName))),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(moveProvider(moveName)),
        ),
      ),
      data: (move) => _MoveDetailContent(move: move),
    );
  }
}

class _MoveDetailContent extends StatelessWidget {
  final MoveEntry move;
  const _MoveDetailContent({required this.move});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = move.typeName != null
        ? (PokemonTypeColors.colors[move.typeName] ?? colorScheme.primary)
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(move.displayName),
        actions: [const SettingsButton()],
        backgroundColor: typeColor.withValues(alpha: 0.15),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coloured header ──
            Container(
              width: double.infinity,
              color: typeColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  // Category icon circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        move.categoryIcon,
                        style: textTheme.headlineSmall
                            ?.copyWith(color: typeColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          move.displayName,
                          style: textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (move.typeName != null)
                              _Chip(
                                label: move.typeName!.toUpperCase(),
                                color: typeColor,
                                textColor: Colors.white,
                              ),
                            _Chip(
                              label: _categoryLabel(move.damageClass),
                              color: colorScheme.surfaceContainerHighest,
                              textColor: colorScheme.onSurfaceVariant,
                              border: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Stats',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _StatCard(
              children: [
                _StatRow(
                  label: 'Power',
                  value: move.power?.toString() ?? '—',
                ),
                _StatRow(
                  label: 'Accuracy',
                  value: move.accuracy != null
                      ? '${move.accuracy}%'
                      : '—',
                ),
                _StatRow(
                  label: 'PP',
                  value: move.pp?.toString() ?? '—',
                ),
                _StatRow(
                  label: 'Category',
                  value: _categoryLabel(move.damageClass),
                ),
                if (move.typeName != null)
                  _StatRow(
                    label: 'Type',
                    value: move.typeName![0].toUpperCase() +
                        move.typeName!.substring(1),
                  ),
              ],
            ),

            // ── Effect ──
            if (move.shortEffect != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Effect',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              _StatCard(
                children: [
                  Text(
                    move.shortEffect!,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String? cat) {
    if (cat == null) return '—';
    return cat[0].toUpperCase() + cat.substring(1);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool border;
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: border ? Colors.transparent : color,
        border: border ? Border.all(color: color) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: border ? color : textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<Widget> children;
  const _StatCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
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

String _fmt(String s) => s
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
