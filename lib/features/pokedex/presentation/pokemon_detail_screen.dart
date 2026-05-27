import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/widgets/stat_bar.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

class PokemonDetailScreen extends ConsumerStatefulWidget {
  final int pokemonId;
  const PokemonDetailScreen({super.key, required this.pokemonId});

  @override
  ConsumerState<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends ConsumerState<PokemonDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _shiny = false;

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Stats'),
    Tab(text: 'Abilities'),
    Tab(text: 'Moves'),
    Tab(text: 'Evolutions'),
    Tab(text: 'Forms'),
    Tab(text: 'Locations'),
    Tab(text: 'Add'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pokemonAsync = ref.watch(pokemonDetailProvider(widget.pokemonId));
    final speciesAsync = ref.watch(pokemonSpeciesProvider(widget.pokemonId));

    return pokemonAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(pokemonDetailProvider(widget.pokemonId)),
        ),
      ),
      data: (pokemon) {
        final primaryType = pokemon.types[1] ?? pokemon.types.values.first;
        final headerColor =
            PokemonTypeColors.colors[primaryType] ?? Theme.of(context).colorScheme.primary;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              _DetailSliverAppBar(
                pokemon: pokemon,
                headerColor: headerColor,
                shiny: _shiny,
                onShinyToggle: () => setState(() => _shiny = !_shiny),
                tabController: _tabController,
                tabs: _tabs,
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(pokemon: pokemon, speciesAsync: speciesAsync),
                _StatsTab(pokemon: pokemon),
                _AbilitiesTab(pokemon: pokemon),
                _ComingSoonTab(label: 'Moves'),
                _ComingSoonTab(label: 'Evolutions'),
                _ComingSoonTab(label: 'Forms'),
                _ComingSoonTab(label: 'Locations'),
                _ComingSoonTab(label: 'Add to Team'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Sliver AppBar ─────────────────────────────────────────────────────────────

class _DetailSliverAppBar extends StatelessWidget {
  final PokemonEntry pokemon;
  final Color headerColor;
  final bool shiny;
  final VoidCallback onShinyToggle;
  final TabController tabController;
  final List<Tab> tabs;

  const _DetailSliverAppBar({
    required this.pokemon,
    required this.headerColor,
    required this.shiny,
    required this.onShinyToggle,
    required this.tabController,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      leading: BackButton(onPressed: () => context.pop()),
      title: Text(
        '${pokemon.displayId()}  ${pokemon.name.toCapitalCase()}',
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        IconButton(
          tooltip: shiny ? 'Show default' : 'Show shiny',
          icon: Icon(
            Icons.auto_awesome,
            color: shiny ? Colors.yellowAccent : Colors.white70,
          ),
          onPressed: onShinyToggle,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: headerColor.withValues(alpha: 0.85),
          child: Center(
            child: PokemonSprite(
              defaultUrl: pokemon.officialArtworkUrl,
              shinyUrl: pokemon.sprites?['other']?['official-artwork']?['front_shiny'] as String?,
              shiny: shiny,
              size: 200,
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: tabController,
        tabs: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final PokemonEntry pokemon;
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;

  const _OverviewTab({required this.pokemon, required this.speciesAsync});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Types
          Row(
            children: [
              ...pokemon.types.values.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TypeBadge(type: t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Physical info
          _InfoGrid(rows: [
            ('Height', pokemon.displayHeight()),
            ('Weight', pokemon.displayWeight()),
            ('Base Exp', pokemon.baseExperience?.toString() ?? '—'),
          ]),
          const SizedBox(height: 16),

          // Species data
          speciesAsync.when(
            loading: () => const LoadingState(message: 'Loading species data…'),
            error: (e, _) => ErrorState(error: e),
            data: (species) => _SpeciesSection(species: species),
          ),
        ],
      ),
    );
  }
}

class _SpeciesSection extends StatelessWidget {
  final PokemonSpeciesEntry species;
  const _SpeciesSection({required this.species});

  @override
  Widget build(BuildContext context) {
    final englishEntries = species.flavorTextEntries
        .where((f) => f.language == 'en')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (species.genus != null) ...[
          Text(species.genus!, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
        ],

        _InfoGrid(rows: [
          ('Generation', species.generationLabel),
          ('Capture Rate', species.captureRate?.toString() ?? '—'),
          ('Base Happiness', species.baseHappiness?.toString() ?? '—'),
          ('Growth Rate', _fmtName(species.growthRate)),
          ('Gender', species.genderDisplay()),
          ('Hatch Steps', species.hatchSteps > 0 ? '~${species.hatchSteps}' : '—'),
          ('Egg Groups', species.eggGroups.map(_fmtName).join(', ')),
        ]),
        const SizedBox(height: 16),

        if (species.isBaby || species.isLegendary || species.isMythical)
          Wrap(
            spacing: 6,
            children: [
              if (species.isBaby) const Chip(label: Text('Baby')),
              if (species.isLegendary) const Chip(label: Text('Legendary')),
              if (species.isMythical) const Chip(label: Text('Mythical')),
            ],
          ),

        if (englishEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Pokédex Entries', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...englishEntries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtName(e.version),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(e.text, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

}

// ── Shared helpers ────────────────────────────────────────────────────────────

String _fmtName(String? raw) {
  if (raw == null) return '—';
  return raw
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows
          .map(
            (r) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 6),
                  child: Text(
                    r.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(r.$2, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final PokemonEntry pokemon;
  const _StatsTab({required this.pokemon});

  // Canonical stat order and short labels
  static const _statMeta = [
    ('hp', 'HP'),
    ('attack', 'Atk'),
    ('defense', 'Def'),
    ('special-attack', 'SpA'),
    ('special-defense', 'SpD'),
    ('speed', 'Spe'),
  ];

  int _base(String statName) {
    for (final s in pokemon.stats) {
      if ((s['stat'] as Map)['name'] == statName) {
        return s['base_stat'] as int;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bases = _statMeta.map((m) => _base(m.$1)).toList();
    final bst = bases.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat bars
          ...List.generate(_statMeta.length, (i) {
            return StatBar(label: _statMeta[i].$2, value: bases[i]);
          }),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 52,
                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(bst.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const Divider(height: 32),

          // Min / Max table
          Text('Stat Ranges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Min: IV 0, EV 0, hindering nature  •  Max: IV 31, EV 252, helpful nature',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _StatRangeTable(bases: bases, statMeta: _statMeta),
        ],
      ),
    );
  }
}

class _StatRangeTable extends StatelessWidget {
  final List<int> bases;
  final List<(String, String)> statMeta;

  const _StatRangeTable({required this.bases, required this.statMeta});

  int _hp(int base, int iv, int ev, int level) =>
      ((2 * base + iv + (ev ~/ 4)) * level ~/ 100) + level + 10;

  int _stat(int base, int iv, int ev, int level, double nature) =>
      (((2 * base + iv + (ev ~/ 4)) * level ~/ 100 + 5) * nature).floor();

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final cellStyle = Theme.of(context).textTheme.bodySmall;

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          children: [
            _cell('', headerStyle, bottom: 6),
            _cell('Min 50', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Max 50', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Min 100', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Max 100', headerStyle, bottom: 6, align: TextAlign.center),
          ],
        ),
        // Rows
        ...List.generate(statMeta.length, (i) {
          final name = statMeta[i].$1;
          final label = statMeta[i].$2;
          final base = bases[i];
          final isHp = name == 'hp';

          final min50 = isHp ? _hp(base, 0, 0, 50) : _stat(base, 0, 0, 50, 0.9);
          final max50 = isHp ? _hp(base, 31, 252, 50) : _stat(base, 31, 252, 50, 1.1);
          final min100 = isHp ? _hp(base, 0, 0, 100) : _stat(base, 0, 0, 100, 0.9);
          final max100 = isHp ? _hp(base, 31, 252, 100) : _stat(base, 31, 252, 100, 1.1);

          return TableRow(
            children: [
              _cell(label, cellStyle?.copyWith(fontWeight: FontWeight.w600), top: 6, bottom: 6),
              _cell(min50.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(max50.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(min100.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(max100.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
            ],
          );
        }),
      ],
    );
  }

  static Widget _cell(
    String text,
    TextStyle? style, {
    double top = 0,
    double bottom = 0,
    TextAlign align = TextAlign.start,
  }) =>
      Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom, right: 8),
        child: Text(text, style: style, textAlign: align),
      );
}

// ── Abilities Tab ─────────────────────────────────────────────────────────────

class _AbilitiesTab extends ConsumerWidget {
  final PokemonEntry pokemon;
  const _AbilitiesTab({required this.pokemon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilities = pokemon.abilities;
    if (abilities.isEmpty) {
      return const EmptyState(icon: Icons.info_outline, title: 'No ability data');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: abilities.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final slot = abilities[i];
        final name = (slot['ability'] as Map)['name'] as String;
        final isHidden = slot['is_hidden'] as bool? ?? false;
        return _AbilityCard(name: name, isHidden: isHidden, ref: ref);
      },
    );
  }
}

class _AbilityCard extends ConsumerWidget {
  final String name;
  final bool isHidden;
  final WidgetRef ref;

  const _AbilityCard({
    required this.name,
    required this.isHidden,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityProvider(name));

    return abilityAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load $name', style: const TextStyle(color: Colors.red)),
      data: (ability) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ability.displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              if (isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Hidden',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                  ),
                ),
              if (ability.generationLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  ability.generationLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
          if (ability.shortEffect != null) ...[
            const SizedBox(height: 4),
            Text(ability.shortEffect!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (ability.longEffect != null && ability.longEffect != ability.shortEffect) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Full description',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    ability.longEffect!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonTab extends StatelessWidget {
  final String label;
  const _ComingSoonTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.construction,
      title: label,
      subtitle: 'Coming in a future PR.',
    );
  }
}
