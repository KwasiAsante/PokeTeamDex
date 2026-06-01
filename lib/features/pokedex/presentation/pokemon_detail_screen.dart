import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
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
                _MovesTab(pokemon: pokemon),
                _EvolutionsTab(speciesAsync: speciesAsync),
                _FormsTab(speciesAsync: speciesAsync),
                _LocationsTab(pokemonId: widget.pokemonId),
                _AddToTeamTab(pokemon: pokemon),
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
        const SettingsButton(),
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
          // Stat bars — staggered fill animation
          ...List.generate(_statMeta.length, (i) {
            return StatBar(
              label: _statMeta[i].$2,
              value: bases[i],
              delay: Duration(milliseconds: i * 70),
            );
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

// ── Moves Tab ────────────────────────────────────────────────────────────────

/// Groups the raw moves list from PokemonEntry by learn method, with optional
/// version-group filter. Move details are fetched lazily per row.
class _MovesTab extends ConsumerStatefulWidget {
  final PokemonEntry pokemon;
  const _MovesTab({required this.pokemon});

  @override
  ConsumerState<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends ConsumerState<_MovesTab> {
  String? _selectedVersion;

  static const _methodOrder = ['level-up', 'machine', 'egg', 'tutor'];
  static const _methodLabels = {
    'level-up': 'Level Up',
    'machine': 'TM / HM',
    'egg': 'Egg Moves',
    'tutor': 'Move Tutor',
  };

  /// All unique version-group names found in the moves list.
  List<String> get _versions {
    final seen = <String>{};
    for (final m in widget.pokemon.moves) {
      for (final vgd in (m['version_group_details'] as List)) {
        seen.add((vgd as Map)['version_group']['name'] as String);
      }
    }
    final sorted = seen.toList()..sort();
    return sorted;
  }

  /// Moves grouped by learn method for the selected version group.
  Map<String, List<_MoveRow>> _grouped(String? version) {
    final groups = <String, List<_MoveRow>>{};
    for (final m in widget.pokemon.moves) {
      final moveName = (m['move'] as Map)['name'] as String;
      for (final vgd in (m['version_group_details'] as List)) {
        final vg = (vgd as Map)['version_group']['name'] as String;
        if (version != null && vg != version) continue;
        final method = vgd['move_learn_method']['name'] as String;
        final level = vgd['level_learned_at'] as int? ?? 0;
        groups.putIfAbsent(method, () => []);
        // Avoid duplicates within same method
        if (!groups[method]!.any((r) => r.moveName == moveName)) {
          groups[method]!.add(_MoveRow(moveName: moveName, level: level));
        }
      }
    }
    // Sort level-up by level
    groups['level-up']?.sort((a, b) => a.level.compareTo(b.level));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    _selectedVersion ??= versions.isNotEmpty ? versions.last : null;
    final grouped = _grouped(_selectedVersion);

    return Column(
      children: [
        // Version filter
        if (versions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: versions.map((v) {
                final label = v.split('-').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _selectedVersion == v,
                    onSelected: (_) => setState(() => _selectedVersion = v),
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: grouped.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No moves found',
                  subtitle: 'Try selecting a different game version.',
                )
              : ListView(
                  children: _methodOrder
                      .where((m) => grouped.containsKey(m))
                      .map((method) {
                    final rows = grouped[method]!;
                    return _MoveGroup(
                      label: _methodLabels[method] ?? method,
                      rows: rows,
                      showLevel: method == 'level-up',
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _MoveRow {
  final String moveName;
  final int level;
  const _MoveRow({required this.moveName, required this.level});
}

class _MoveGroup extends StatelessWidget {
  final String label;
  final List<_MoveRow> rows;
  final bool showLevel;

  const _MoveGroup({
    required this.label,
    required this.rows,
    required this.showLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '$label (${rows.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              if (showLevel) const SizedBox(width: 36, child: Text('Lv', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const Expanded(child: Text('Move', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 52, child: Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 24, child: Text('Cat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              const SizedBox(width: 32, child: Text('Pwr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              const SizedBox(width: 32, child: Text('Acc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1, indent: 16),
        ...rows.map((r) => _MoveTile(row: r, showLevel: showLevel)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MoveTile extends ConsumerWidget {
  final _MoveRow row;
  final bool showLevel;
  const _MoveTile({required this.row, required this.showLevel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveProvider(row.moveName));
    final typeColor = moveAsync.whenOrNull(
          data: (m) => PokemonTypeColors.colors[m.typeName] ?? Colors.grey,
        ) ??
        Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          if (showLevel)
            SizedBox(
              width: 36,
              child: Text(
                row.level == 0 ? '—' : '${row.level}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: Text(
              row.moveName
                  .split('-')
                  .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
                  .join(' '),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: moveAsync.whenOrNull(
                  data: (m) => m.typeName != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${m.typeName![0].toUpperCase()}${m.typeName!.substring(1)}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
          ),
          SizedBox(
            width: 24,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.categoryIcon) ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.power?.toString() ?? '—') ?? '…',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.accuracy != null ? '${m.accuracy}%' : '—') ?? '…',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
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

// ── Evolutions Tab ────────────────────────────────────────────────────────────

class _EvolutionsTab extends ConsumerWidget {
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;
  const _EvolutionsTab({required this.speciesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return speciesAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (species) {
        final chainId = species.evolutionChainId;
        if (chainId == null) {
          return const EmptyState(
            icon: Icons.device_unknown,
            title: 'No evolution data',
          );
        }
        final chainAsync = ref.watch(evolutionChainProvider(chainId));
        return chainAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e),
          data: (root) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _EvolutionTree(node: root),
          ),
        );
      },
    );
  }
}

/// Recursively renders the evolution chain.
/// Linear chains stay vertical; branching chains (e.g. Eevee) spread
/// horizontally in a Wrap so they don't all stack into a single tall column.
class _EvolutionTree extends StatelessWidget {
  final EvolutionNode node;
  const _EvolutionTree({required this.node});

  @override
  Widget build(BuildContext context) {
    if (node.evolvesTo.isEmpty) {
      return _EvolutionNodeCard(node: node);
    }

    if (node.evolvesTo.length == 1) {
      // Linear chain — vertical layout
      final child = node.evolvesTo.first;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EvolutionNodeCard(node: node),
          const SizedBox(height: 6),
          _EvolutionArrow(details: child.details),
          const SizedBox(height: 6),
          _EvolutionTree(node: child),
        ],
      );
    }

    // Branching — show branches side-by-side in a Wrap
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionNodeCard(node: node),
        const SizedBox(height: 6),
        const Icon(
          Icons.call_split_rounded,
          size: 22,
          color: Colors.grey,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: node.evolvesTo.map((child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ConditionChip(details: child.details),
                const SizedBox(height: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                _EvolutionTree(node: child),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Arrow + condition chip between two evolution stages.
class _EvolutionArrow extends StatelessWidget {
  final List<EvolutionDetail> details;
  const _EvolutionArrow({required this.details});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConditionChip(details: details),
        if (details.isNotEmpty) const SizedBox(height: 4),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 28,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }
}

class _EvolutionNodeCard extends StatelessWidget {
  final EvolutionNode node;
  const _EvolutionNodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('/pokedex/${node.speciesId}'),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: node.spriteUrl,
              width: 72,
              height: 72,
              placeholder: (_, __) => const SizedBox(
                width: 72,
                height: 72,
                child: Icon(Icons.catching_pokemon, color: Colors.grey),
              ),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined),
            ),
            const SizedBox(height: 4),
            Text(
              node.displayName,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '#${node.speciesId.toString().padLeft(3, '0')}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final List<EvolutionDetail> details;
  const _ConditionChip({required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    final label = details.map((d) => d.conditionLabel).join(' / ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

// ── Forms & Variants Tab ──────────────────────────────────────────────────────

class _FormsTab extends ConsumerWidget {
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;
  const _FormsTab({required this.speciesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return speciesAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (species) {
        final nonDefault = species.varieties.where((v) => !v.isDefault).toList();
        if (nonDefault.isEmpty) {
          return const EmptyState(
            icon: Icons.style_outlined,
            title: 'No alternate forms',
            subtitle: 'This Pokémon has no regional forms, Mega Evolutions, or other variants.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: nonDefault.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (_, i) => _FormCard(variety: nonDefault[i]),
        );
      },
    );
  }
}

class _FormCard extends ConsumerWidget {
  final PokemonVariety variety;
  const _FormCard({required this.variety});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemonAsync = ref.watch(pokemonByNameProvider(variety.name));

    return pokemonAsync.when(
      loading: () => ListTile(
        leading: const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(variety.displayName),
      ),
      error: (e, _) => ListTile(
        title: Text(variety.displayName),
        subtitle: const Text('Failed to load form data'),
      ),
      data: (pokemon) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PokemonSprite(
                  defaultUrl: pokemon.officialArtworkUrl ??
                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                  size: 80,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variety.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: pokemon.types.values
                            .map((t) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TypeBadge(type: t),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pokemon.stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...pokemon.stats.indexed.map((entry) {
                final i = entry.$1;
                final s = entry.$2;
                final statName = (s['stat'] as Map)['name'] as String;
                final value = s['base_stat'] as int;
                final label = _shortStatLabel(statName);
                return StatBar(
                  label: label,
                  value: value,
                  delay: Duration(milliseconds: i * 70),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  static String _shortStatLabel(String name) {
    const map = {
      'hp': 'HP',
      'attack': 'Atk',
      'defense': 'Def',
      'special-attack': 'SpA',
      'special-defense': 'SpD',
      'speed': 'Spe',
    };
    return map[name] ?? name;
  }
}

// ── Locations Tab ─────────────────────────────────────────────────────────────

class _LocationsTab extends ConsumerStatefulWidget {
  final int pokemonId;
  const _LocationsTab({required this.pokemonId});

  @override
  ConsumerState<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends ConsumerState<_LocationsTab> {
  String? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final encountersAsync = ref.watch(pokemonEncountersProvider(widget.pokemonId));

    return encountersAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (encounters) {
        if (encounters.isEmpty) {
          return const EmptyState(
            icon: Icons.map_outlined,
            title: 'No location data',
            subtitle: 'This Pokémon is not encountered in the wild.',
          );
        }

        // Collect all versions from encounter data
        final versions = encounters
            .expand((e) => e.versionDetails.map((v) => v.version))
            .toSet()
            .toList()
          ..sort();

        _selectedVersion ??= versions.first;

        // Filter encounters for the selected version
        final filtered = encounters
            .map((e) {
              final vd = e.versionDetails
                  .where((v) => v.version == _selectedVersion)
                  .toList();
              return vd.isEmpty ? null : (entry: e, vd: vd.first);
            })
            .whereType<({EncounterEntry entry, VersionEncounter vd})>()
            .toList();

        return Column(
          children: [
            _VersionFilterBar(
              versions: versions,
              selected: _selectedVersion!,
              onSelected: (v) => setState(() => _selectedVersion = v),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.map_outlined,
                      title: 'Not available',
                      subtitle: 'This Pokémon is not encountered in this version.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return _LocationTile(
                          entry: item.entry,
                          versionEncounter: item.vd,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VersionFilterBar extends StatelessWidget {
  final List<String> versions;
  final String selected;
  final ValueChanged<String> onSelected;

  const _VersionFilterBar({
    required this.versions,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: versions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final v = versions[i];
          final isSelected = v == selected;
          return FilterChip(
            label: Text(_versionLabel(v)),
            selected: isSelected,
            onSelected: (_) => onSelected(v),
          );
        },
      ),
    );
  }

  static String _versionLabel(String v) {
    return v
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

class _LocationTile extends StatelessWidget {
  final EncounterEntry entry;
  final VersionEncounter versionEncounter;

  const _LocationTile({
    required this.entry,
    required this.versionEncounter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.displayName,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${versionEncounter.maxChance}%',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                ),
              ],
            ),
            if (versionEncounter.methods.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: versionEncounter.methods.map((m) {
                  return Chip(
                    label: Text(
                      '${m.methodLabel} · ${m.levelRange} · ${m.chance}%',
                      style: textTheme.labelSmall,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add to Team Tab ───────────────────────────────────────────────────────────

class _AddToTeamTab extends StatefulWidget {
  final PokemonEntry pokemon;
  const _AddToTeamTab({required this.pokemon});

  @override
  State<_AddToTeamTab> createState() => _AddToTeamTabState();
}

class _AddToTeamTabState extends State<_AddToTeamTab> {
  int? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pokemon = widget.pokemon;
    final primaryType = pokemon.types[1] ?? pokemon.types.values.first;
    final typeColor = PokemonTypeColors.colors[primaryType] ?? colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pokémon summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PokemonSprite(
                    defaultUrl: pokemon.officialArtworkUrl ??
                        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                    size: 80,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pokemon.name.toCapitalCase(),
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '#${pokemon.displayId()}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: pokemon.types.values
                              .map((t) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: TypeBadge(type: t),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Select a team slot',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 6-slot grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: 6,
            itemBuilder: (_, i) {
              final slot = i + 1;
              final isSelected = _selectedSlot == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? typeColor : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? typeColor.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.catching_pokemon,
                        size: 28,
                        color: isSelected
                            ? typeColor
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slot $slot',
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? typeColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: _selectedSlot == null
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Team Builder coming soon — ${pokemon.name.toCapitalCase()} queued for slot $_selectedSlot!',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
            label: Text(
              _selectedSlot == null
                  ? 'Select a slot first'
                  : 'Add to Slot $_selectedSlot',
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Full Team Builder with folder management and sync is coming in a future update.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

