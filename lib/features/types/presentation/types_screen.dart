import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/types/providers/types_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class TypesScreen extends StatelessWidget {
  const TypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Types'), actions: [const SettingsButton()]),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
        ),
        itemCount: kAllTypes.length,
        itemBuilder: (_, i) => _TypeCard(typeName: kAllTypes[i]),
      ),
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
    final label = '${typeName[0].toUpperCase()}${typeName.substring(1)}';

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

// ── Type detail bottom sheet ──────────────────────────────────────────────────

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            loading: () => const Center(child: CircularProgressIndicator()),
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
        Text(
          'Attacking',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _EffectivenessRow(
          label: '2× damage to',
          types: type.doubleDamageTo,
          badge: '2×',
          badgeColor: Colors.red,
        ),
        _EffectivenessRow(
          label: '½× damage to',
          types: type.halfDamageTo,
          badge: '½×',
          badgeColor: Colors.orange,
        ),
        _EffectivenessRow(
          label: 'No effect on',
          types: type.noDamageTo,
          badge: '0×',
          badgeColor: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          'Defending',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _EffectivenessRow(
          label: 'Weak to (2×)',
          types: type.doubleDamageFrom,
          badge: '2×',
          badgeColor: Colors.red,
        ),
        _EffectivenessRow(
          label: 'Resists (½×)',
          types: type.halfDamageFrom,
          badge: '½×',
          badgeColor: Colors.green,
        ),
        _EffectivenessRow(
          label: 'Immune to (0×)',
          types: type.noDamageFrom,
          badge: '0×',
          badgeColor: Colors.grey,
        ),
      ],
    );
  }
}

class _EffectivenessRow extends StatelessWidget {
  final String label;
  final List<String> types;
  final String badge;
  final Color badgeColor;

  const _EffectivenessRow({
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
                child: Text(
                  badge,
                  style: textTheme.labelSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: types.map((t) => _TypePill(typeName: t)).toList(),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String typeName;
  const _TypePill({required this.typeName});

  @override
  Widget build(BuildContext context) {
    final color = PokemonTypeColors.colors[typeName] ??
        Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${typeName[0].toUpperCase()}${typeName.substring(1)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
