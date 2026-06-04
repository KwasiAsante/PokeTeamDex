import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_grid_card.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_list_tile.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

// How many Pokémon to render per page.
const _kPageSize = 50;

class PokedexScreen extends ConsumerStatefulWidget {
  const PokedexScreen({super.key});

  @override
  ConsumerState<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends ConsumerState<PokedexScreen> {
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  /// How many items are currently visible in the list.
  int _visibleCount = _kPageSize;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Trigger 300px before the very bottom so the next page appears
    // before the user runs out of content.
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      setState(() => _visibleCount += _kPageSize);
    }
  }

  /// Reset to the first page and scroll to top — called when search/filter changes.
  void _resetPage() {
    setState(() => _visibleCount = _kPageSize);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset pagination whenever the search query or filter state changes.
    ref.listen(pokemonSearchProvider, (_, _) => _resetPage());
    ref.listen(pokedexFilterProvider, (_, _) => _resetPage());

    final listAsync = ref.watch(filteredPokemonListProvider);

    // Adaptive layout
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final viewMode = ref.watch(pokedexViewProvider);

    // Compact screens always use list; larger screens respect the toggle.
    final useGrid = !isCompact && viewMode == PokedexViewMode.grid;

    // Image tier — same breakpoints for both list and grid.
    final PokedexImageType? listImageType = isCompact
        ? null // compact → icon sprites
        : width >= 840
            ? PokedexImageType.artwork
            : PokedexImageType.sprite;

    final crossAxisCount = width >= 840 ? 3 : 2;
    final gridImageType =
        width >= 840 ? PokedexImageType.artwork : PokedexImageType.sprite;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokédex'),
        actions: [
          // View toggle — hidden on compact (always list there)
          if (!isCompact)
            IconButton(
              icon: Icon(
                viewMode == PokedexViewMode.grid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
              ),
              tooltip: viewMode == PokedexViewMode.grid
                  ? 'Switch to list'
                  : 'Switch to grid',
              onPressed: () => ref
                  .read(pokedexViewProvider.notifier)
                  .state = viewMode == PokedexViewMode.grid
                  ? PokedexViewMode.list
                  : PokedexViewMode.grid,
            ),
          const ConnectivityStatusButton(),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchController),
          _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (data) {
                if (data.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No Pokémon found',
                    subtitle: 'Try adjusting your search or filters.',
                  );
                }

                // Slice to the current page.
                final visible = data.length <= _visibleCount
                    ? data
                    : data.sublist(0, _visibleCount);
                final hasMore = data.length > visible.length;

                return Column(
                  children: [
                    // Results count
                    if (data.length < 1025)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '${data.length} Pokémon',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: !useGrid
                          // ── List mode (default or compact) ──
                          ? ListView.builder(
                              controller: _scrollController,
                              // No fixed itemExtent — tile height varies by
                              // image tier (icon < sprite < artwork).
                              itemCount: visible.length + (hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == visible.length) {
                                  return const _LoadMoreFooter();
                                }
                                return PokemonListTile(
                                  pokemon: visible[i],
                                  imageType: listImageType,
                                );
                              },
                            )
                          // ── Grid mode ──
                          : GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio:
                                    gridImageType == PokedexImageType.artwork
                                        ? 0.62
                                        : 0.75,
                              ),
                              itemCount: visible.length + (hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == visible.length) {
                                  return const _LoadMoreFooter();
                                }
                                return PokemonGridCard(
                                  pokemon: visible[i],
                                  imageType: gridImageType,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(pokemonListProvider),
              ),
              loading: () => useGrid
                  ? SkeletonGridView(
                      count: 12,
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: gridImageType ==
                              PokedexImageType.artwork
                          ? 0.62
                          : 0.75,
                    )
                  : SkeletonListView(
                      count: 12,
                      itemExtent: 72,
                      leading: SkeletonLeading.square,
                      leadingSize: 48,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Load-more footer ──────────────────────────────────────────────────────────

/// Shown at the bottom of the list while more pages remain.
/// Displays a spinner and triggers the parent's scroll listener
/// simply by being in the layout — the scroll listener fires when
/// this item is near-visible.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading more…',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

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
              tooltip: 'Clear search',
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

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pokedexFilterProvider);
    final showFavs = ref.watch(showFavoritesOnlyProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          FilterChip(
            avatar: Icon(
              showFavs ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 16,
              color: showFavs ? Colors.amber : null,
            ),
            label: const Text('Favorites'),
            selected: showFavs,
            onSelected: (v) =>
                ref.read(showFavoritesOnlyProvider.notifier).state = v,
          ),
          const SizedBox(width: 6),
          _SortChip(current: filter.sort),
          const SizedBox(width: 6),
          _GenerationChip(selected: filter.generation),
          // Game chip only visible when a generation is selected
          if (filter.generation != null) ...[
            const SizedBox(width: 6),
            _GameChip(
              generation: filter.generation!,
              selected: filter.game,
            ),
          ],
          const SizedBox(width: 6),
          _TypeChip(selected: filter.type),
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

  static const _romanNumerals = [
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(selected != null
          ? 'Gen ${_romanNumerals[selected! - 1]}'
          : 'Generation'),
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
                (s) => s.copyWith(
                  generation: gen == selected ? null : gen,
                  // Clear game filter when generation changes
                  game: null,
                ),
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
          child: Text('Select Generation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
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
          ),
        ),
      ],
    );
  }
}

// ── Game filter chip ─────────────────────────────────────────────────────────

class _GameChip extends ConsumerWidget {
  final int generation;
  final String? selected;
  const _GameChip({required this.generation, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch allFormatsProvider to trigger initialization; rebuilds when ready.
    final formatsAsync = ref.watch(allFormatsProvider);
    final games = (formatsAsync.asData?.value ?? [])
        .where((f) => f.type == FormatType.game && f.gen == generation)
        .toList();

    // Show a placeholder chip while formats are loading so the bar width
    // doesn't jump once data arrives.
    if (formatsAsync.isLoading) {
      return const FilterChip(
        label: Text('Game'),
        avatar: Icon(Icons.videogame_asset_outlined, size: 16),
        onSelected: null,
      );
    }

    if (games.isEmpty) return const SizedBox.shrink();

    final selectedGame = games.where((g) => g.id == selected).firstOrNull;

    return FilterChip(
      label: Text(selectedGame?.short ?? 'Game'),
      avatar: const Icon(Icons.videogame_asset_outlined, size: 16),
      selected: selected != null,
      onSelected: (_) => _showPicker(context, ref, games),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, List<GameFormat> games) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _GamePicker(
        games: games,
        current: selected,
        onSelected: (gameId) {
          ref.read(pokedexFilterProvider.notifier).update(
                (s) => s.copyWith(game: gameId == selected ? null : gameId),
              );
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _GamePicker extends StatelessWidget {
  final List<GameFormat> games;
  final String? current;
  final void Function(String) onSelected;
  const _GamePicker({
    required this.games,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Game',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              ...games.map((g) => ListTile(
                    title: Text(g.name),
                    trailing: current == g.id ? const Icon(Icons.check) : null,
                    onTap: () => onSelected(g.id),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Type filter chip ──────────────────────────────────────────────────────────

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
          ? (PokemonTypeColors.colors[selected!] ?? Colors.grey)
              .withValues(alpha: 0.3)
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
    final types =
        PokemonTypeColors.colors.keys.where((t) => t != 'unknown').toList()
          ..sort();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
