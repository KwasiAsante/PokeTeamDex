import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_list_tile.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class PokedexScreen extends ConsumerStatefulWidget {
  const PokedexScreen({super.key});

  @override
  ConsumerState<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends ConsumerState<PokedexScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(filteredPokemonListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex'), actions: [const SettingsButton()]),
      body: Column(
        children: [
          _SearchBar(controller: _searchController),
          _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (data) => data.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'No Pokémon found',
                      subtitle: 'Try adjusting your search or filters.',
                    )
                  : ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (_, i) => PokemonListTile(pokemon: data[i]),
                    ),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(pokemonListProvider),
              ),
              loading: () => const LoadingState(message: 'Loading Pokédex…'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: SearchBar(
        controller: controller,
        hintText: 'Search by name or Pokédex number',
        onChanged: (v) => ref.read(pokemonSearchProvider.notifier).state = v,
        trailing: [
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.clear();
                ref.read(pokemonSearchProvider.notifier).state = '';
              },
            ),
        ],
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pokedexFilterProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          // Sort
          _SortChip(current: filter.sort),
          const SizedBox(width: 6),
          // Generation picker
          _GenerationChip(selected: filter.generation),
          const SizedBox(width: 6),
          // Type picker
          _TypeChip(selected: filter.type),
          // Clear filters
          if (!filter.isDefault) ...[
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.close, size: 16),
              label: const Text('Clear'),
              onPressed: () => ref.read(pokedexFilterProvider.notifier).state =
                  const PokedexFilter(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends ConsumerWidget {
  final PokedexSort current;
  const _SortChip({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(current == PokedexSort.dexNumber ? 'Dex #' : 'Name A–Z'),
      avatar: const Icon(Icons.sort, size: 16),
      selected: current == PokedexSort.name,
      onSelected: (_) {
        ref.read(pokedexFilterProvider.notifier).update((s) => s.copyWith(
              sort: current == PokedexSort.dexNumber
                  ? PokedexSort.name
                  : PokedexSort.dexNumber,
            ));
      },
    );
  }
}

class _GenerationChip extends ConsumerWidget {
  final int? selected;
  const _GenerationChip({required this.selected});

  static const _romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(selected != null ? 'Gen ${_romanNumerals[selected! - 1]}' : 'Generation'),
      avatar: const Icon(Icons.layers, size: 16),
      selected: selected != null,
      onSelected: (_) => _showPicker(context, ref),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _GenerationPicker(
        current: selected,
        onSelected: (gen) {
          ref.read(pokedexFilterProvider.notifier).update(
                (s) => s.copyWith(generation: gen == selected ? null : gen),
              );
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _GenerationPicker extends StatelessWidget {
  final int? current;
  final void Function(int) onSelected;
  const _GenerationPicker({required this.current, required this.onSelected});

  static const _labels = [
    'Gen I — Kanto (1–151)',
    'Gen II — Johto (152–251)',
    'Gen III — Hoenn (252–386)',
    'Gen IV — Sinnoh (387–493)',
    'Gen V — Unova (494–649)',
    'Gen VI — Kalos (650–721)',
    'Gen VII — Alola (722–809)',
    'Gen VIII — Galar (810–905)',
    'Gen IX — Paldea (906–1025)',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Generation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...List.generate(9, (i) {
          final gen = i + 1;
          return ListTile(
            title: Text(_labels[i]),
            trailing: current == gen ? const Icon(Icons.check) : null,
            onTap: () => onSelected(gen),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TypeChip extends ConsumerWidget {
  final String? selected;
  const _TypeChip({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(selected != null
          ? '${selected![0].toUpperCase()}${selected!.substring(1)}'
          : 'Type'),
      avatar: const Icon(Icons.category, size: 16),
      selected: selected != null,
      selectedColor: selected != null
          ? (PokemonTypeColors.colors[selected!] ?? Colors.grey).withValues(alpha: 0.3)
          : null,
      onSelected: (_) => _showPicker(context, ref),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _TypePicker(
        current: selected,
        onSelected: (type) {
          ref.read(pokedexFilterProvider.notifier).update(
                (s) => s.copyWith(type: type == selected ? null : type),
              );
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  final String? current;
  final void Function(String) onSelected;
  const _TypePicker({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final types = PokemonTypeColors.colors.keys.where((t) => t != 'unknown').toList()..sort();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: types.length,
            itemBuilder: (_, i) {
              final type = types[i];
              final color = PokemonTypeColors.colors[type]!;
              final isSelected = current == type;
              return GestureDetector(
                onTap: () => onSelected(type),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${type[0].toUpperCase()}${type.substring(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
