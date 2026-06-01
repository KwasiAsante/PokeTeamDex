import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/types/providers/types_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class TypesScreen extends StatelessWidget {
  const TypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Types'),
          actions: [const SettingsButton()],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: 'Chart'),
              Tab(icon: Icon(Icons.category), text: 'Types'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ChartTab(),
            _TypesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Chart tab — full 18×18 effectiveness matrix ───────────────────────────────

class _ChartTab extends ConsumerWidget {
  const _ChartTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allTypesProvider);

    return allAsync.when(
      loading: () => const LoadingState(message: 'Loading type data…'),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(allTypesProvider),
      ),
      data: (types) => _TypeMatrix(types: types),
    );
  }
}

class _TypeMatrix extends StatelessWidget {
  final Map<String, TypeEntry> types;
  const _TypeMatrix({required this.types});

  // Pre-compute effectiveness for all attacker/defender pairs.
  double _eff(String attacker, String defender) {
    final entry = types[attacker];
    if (entry == null) return 1.0;
    if (entry.doubleDamageTo.contains(defender)) return 2.0;
    if (entry.halfDamageTo.contains(defender)) return 0.5;
    if (entry.noDamageTo.contains(defender)) return 0.0;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const cellSize = 36.0;
    const rowHeaderWidth = 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _LegendChip(color: _cellBg(2.0, colorScheme), label: '2×  Super effective'),
              _LegendChip(color: _cellBg(0.5, colorScheme), label: '½×  Not very effective'),
              _LegendChip(color: _cellBg(0.0, colorScheme), label: '0×  No effect'),
              _LegendChip(color: _cellBg(1.0, colorScheme), label: '1×  Normal'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Text(
            'Row = Attacking type   ·   Column = Defending type',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const Divider(height: 1),
        // Scrollable matrix
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Column headers (defending type) ──
                  Row(
                    children: [
                      SizedBox(width: rowHeaderWidth), // spacer
                      for (final def in kAllTypes)
                        SizedBox(
                          width: cellSize,
                          height: 72,
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: _TypeLabel(
                                typeName: def,
                                abbrev: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // ── Data rows ──
                  for (final atk in kAllTypes)
                    Row(
                      children: [
                        // Row header (attacking type)
                        SizedBox(
                          width: rowHeaderWidth,
                          height: cellSize,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _TypeLabel(
                              typeName: atk,
                              abbrev: false,
                            ),
                          ),
                        ),
                        // Cells
                        for (final def in kAllTypes)
                          _Cell(
                            effectiveness: _eff(atk, def),
                            size: cellSize,
                            colorScheme: colorScheme,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _cellBg(double eff, ColorScheme cs) => switch (eff) {
        2.0 => const Color(0xFFB71C1C), // deep red
        0.5 => const Color(0xFF1B5E20), // deep green
        0.0 => cs.surfaceContainerHighest,
        _   => cs.surface,
      };
}

// ── Matrix cell ───────────────────────────────────────────────────────────────

class _Cell extends StatelessWidget {
  final double effectiveness;
  final double size;
  final ColorScheme colorScheme;

  const _Cell({
    required this.effectiveness,
    required this.size,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (effectiveness) {
      2.0 => const Color(0xFFB71C1C),
      0.5 => const Color(0xFF1B5E20),
      0.0 => colorScheme.surfaceContainerHighest,
      _   => colorScheme.surface,
    };
    final fg = switch (effectiveness) {
      2.0 => Colors.white,
      0.5 => Colors.white,
      0.0 => colorScheme.onSurfaceVariant,
      _   => colorScheme.onSurface.withValues(alpha: 0.2),
    };
    final label = switch (effectiveness) {
      2.0 => '2×',
      0.5 => '½×',
      0.0 => '0×',
      _   => '1',
    };
    final bold = effectiveness != 1.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Type label (row header or column header) ──────────────────────────────────

class _TypeLabel extends StatelessWidget {
  final String typeName;
  final bool abbrev; // true = 3-char abbreviation, false = full name

  const _TypeLabel({required this.typeName, required this.abbrev});

  static const _abbrevs = <String, String>{
    'normal': 'Nor', 'fire': 'Fir', 'water': 'Wat', 'electric': 'Ele',
    'grass': 'Grs', 'ice': 'Ice', 'fighting': 'Fig', 'poison': 'Poi',
    'ground': 'Gnd', 'flying': 'Fly', 'psychic': 'Psy', 'bug': 'Bug',
    'rock': 'Rok', 'ghost': 'Gho', 'dragon': 'Dra', 'dark': 'Drk',
    'steel': 'Stl', 'fairy': 'Fai',
  };

  @override
  Widget build(BuildContext context) {
    final color =
        PokemonTypeColors.colors[typeName] ?? Theme.of(context).colorScheme.primary;
    final text = abbrev
        ? (_abbrevs[typeName] ?? typeName.substring(0, 3))
        : '${typeName[0].toUpperCase()}${typeName.substring(1)}';

    return Container(
      padding: abbrev
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Legend chip ───────────────────────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ── Types tab — existing type grid ────────────────────────────────────────────

class _TypesTab extends StatelessWidget {
  const _TypesTab();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: kAllTypes.length,
      itemBuilder: (_, i) => _TypeCard(typeName: kAllTypes[i]),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String typeName;
  const _TypeCard({required this.typeName});

  @override
  Widget build(BuildContext context) {
    final color =
        PokemonTypeColors.colors[typeName] ?? Theme.of(context).colorScheme.primary;
    final label =
        '${typeName[0].toUpperCase()}${typeName.substring(1)}';

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TypeDetailSheet(typeName: typeName),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

// ── Type detail bottom sheet (unchanged) ──────────────────────────────────────

class _TypeDetailSheet extends ConsumerWidget {
  final String typeName;
  const _TypeDetailSheet({required this.typeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeAsync = ref.watch(typeProvider(typeName));
    final color =
        PokemonTypeColors.colors[typeName] ?? Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${typeName[0].toUpperCase()}${typeName.substring(1)}',
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          typeAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (type) => _TypeRelations(type: type),
          ),
        ],
      ),
    );
  }
}

class _TypeRelations extends StatelessWidget {
  final TypeEntry type;
  const _TypeRelations({required this.type});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attacking',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _EffRow(label: '2× damage to', types: type.doubleDamageTo,
            badge: '2×', badgeColor: Colors.red),
        _EffRow(label: '½× damage to', types: type.halfDamageTo,
            badge: '½×', badgeColor: Colors.orange),
        _EffRow(label: 'No effect on', types: type.noDamageTo,
            badge: '0×', badgeColor: Colors.grey),
        const SizedBox(height: 16),
        Text('Defending',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _EffRow(label: 'Weak to (2×)', types: type.doubleDamageFrom,
            badge: '2×', badgeColor: Colors.red),
        _EffRow(label: 'Resists (½×)', types: type.halfDamageFrom,
            badge: '½×', badgeColor: Colors.green),
        _EffRow(label: 'Immune to (0×)', types: type.noDamageFrom,
            badge: '0×', badgeColor: Colors.grey),
      ],
    );
  }
}

class _EffRow extends StatelessWidget {
  final String label;
  final List<String> types;
  final String badge;
  final Color badgeColor;
  const _EffRow({
    required this.label,
    required this.types,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badge,
                    style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Text(label, style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: types.map((t) => _TypePill(t)).toList(),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String typeName;
  const _TypePill(this.typeName);

  @override
  Widget build(BuildContext context) {
    final color = PokemonTypeColors.colors[typeName] ??
        Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${typeName[0].toUpperCase()}${typeName.substring(1)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
