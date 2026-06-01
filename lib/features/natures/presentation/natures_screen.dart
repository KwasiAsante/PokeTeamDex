import 'package:flutter/material.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

// ── Nature data ───────────────────────────────────────────────────────────────

class _Nature {
  final String name;
  final String? increased; // null = neutral
  final String? decreased;

  const _Nature(this.name, {this.increased, this.decreased});

  bool get isNeutral => increased == null;
}

const _natures = [
  // Neutral
  _Nature('Hardy'),
  _Nature('Docile'),
  _Nature('Serious'),
  _Nature('Bashful'),
  _Nature('Quirky'),
  // Attack up
  _Nature('Lonely', increased: 'Attack', decreased: 'Defense'),
  _Nature('Brave', increased: 'Attack', decreased: 'Speed'),
  _Nature('Adamant', increased: 'Attack', decreased: 'Sp. Atk'),
  _Nature('Naughty', increased: 'Attack', decreased: 'Sp. Def'),
  // Defense up
  _Nature('Bold', increased: 'Defense', decreased: 'Attack'),
  _Nature('Relaxed', increased: 'Defense', decreased: 'Speed'),
  _Nature('Impish', increased: 'Defense', decreased: 'Sp. Atk'),
  _Nature('Lax', increased: 'Defense', decreased: 'Sp. Def'),
  // Speed up
  _Nature('Timid', increased: 'Speed', decreased: 'Attack'),
  _Nature('Hasty', increased: 'Speed', decreased: 'Defense'),
  _Nature('Jolly', increased: 'Speed', decreased: 'Sp. Atk'),
  _Nature('Naive', increased: 'Speed', decreased: 'Sp. Def'),
  // Sp. Atk up
  _Nature('Modest', increased: 'Sp. Atk', decreased: 'Attack'),
  _Nature('Mild', increased: 'Sp. Atk', decreased: 'Defense'),
  _Nature('Quiet', increased: 'Sp. Atk', decreased: 'Speed'),
  _Nature('Rash', increased: 'Sp. Atk', decreased: 'Sp. Def'),
  // Sp. Def up
  _Nature('Calm', increased: 'Sp. Def', decreased: 'Attack'),
  _Nature('Gentle', increased: 'Sp. Def', decreased: 'Defense'),
  _Nature('Sassy', increased: 'Sp. Def', decreased: 'Speed'),
  _Nature('Careful', increased: 'Sp. Def', decreased: 'Sp. Atk'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class NaturesScreen extends StatelessWidget {
  const NaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final headerStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Natures'), actions: [const ConnectivityStatusButton(), const SettingsButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'Each non-neutral nature boosts one stat by +10% and reduces another by −10%.',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            Table(
              border: TableBorder.all(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    _HeaderCell('Nature', style: headerStyle),
                    _HeaderCell('+10%', style: headerStyle),
                    _HeaderCell('−10%', style: headerStyle),
                  ],
                ),
                // Nature rows
                for (final n in _natures)
                  TableRow(
                    children: [
                      _Cell(
                        n.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _StatCell(n.increased, increased: true),
                      _StatCell(n.decreased, increased: false),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _HeaderCell(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, style: style),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _Cell(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, style: style ?? Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String? stat;
  final bool increased;
  const _StatCell(this.stat, {required this.increased});

  @override
  Widget build(BuildContext context) {
    if (stat == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final color = increased ? Colors.red.shade700 : Colors.blue.shade700;
    final prefix = increased ? '+' : '−';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Text(
            prefix,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              stat!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
