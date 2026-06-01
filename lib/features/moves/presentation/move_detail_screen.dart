import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

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
      data: (move) => _MoveDetailBody(move: move),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _MoveDetailBody extends StatelessWidget {
  final MoveEntry move;
  const _MoveDetailBody({required this.move});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = move.typeName != null
        ? (PokemonTypeColors.colors[move.typeName] ?? colorScheme.primary)
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(move.displayName),
        backgroundColor: typeColor.withValues(alpha: 0.15),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(move: move, typeColor: typeColor),
            _Section(title: 'Stats', child: _StatsCard(move: move)),
            if (move.meta != null && move.meta!.hasNonTrivialData)
              _Section(
                  title: 'Battle Data', child: _MetaCard(meta: move.meta!)),
            if (move.shortEffect != null)
              _Section(
                title: 'Effect',
                child: Text(move.shortEffect!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (move.flavorTextEntries.isNotEmpty)
              _FlavorSection(entries: move.flavorTextEntries),
            if (move.pastValues.isNotEmpty)
              _Section(
                title: 'Past Values',
                child: _PastValuesCard(pastValues: move.pastValues),
              ),
            if (move.contestTypeName != null ||
                (move.contestCombos != null && move.contestCombos!.hasAny))
              _Section(
                  title: 'Contest', child: _ContestCard(move: move)),
            if (move.machines.isNotEmpty)
              _Section(
                title: 'TM / HM / TR',
                child: _MachinesCard(machines: move.machines),
              ),
            if (move.learnedByPokemon.isNotEmpty)
              _Section(
                title: 'Learned by (${move.learnedByPokemon.length})',
                child: _LearnedByGrid(pokemon: move.learnedByPokemon),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final MoveEntry move;
  final Color typeColor;
  const _Header({required this.move, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: typeColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(move.categoryIcon,
                  style:
                      textTheme.headlineSmall?.copyWith(color: typeColor)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(move.displayName,
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (move.typeName != null)
                      TypeBadge(type: move.typeName!),
                    _InfoBadge(
                      label: _categoryLabel(move.damageClass),
                      color: colorScheme.surfaceContainerHighest,
                      textColor: colorScheme.onSurfaceVariant,
                    ),
                    if (move.generationName != null)
                      _InfoBadge(
                        label: _genLabel(move.generationName!),
                        color: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final MoveEntry move;
  const _StatsCard({required this.move});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatRow('Power',
            move.power?.toString() ?? '—'),
        _StatRow('Accuracy',
            move.accuracy != null ? '${move.accuracy}%' : 'Always hits'),
        _StatRow('PP', move.pp?.toString() ?? '—'),
        _StatRow('Priority',
            move.priority == 0 ? '0 (normal)' : '${move.priority > 0 ? '+' : ''}${move.priority}'),
        if (move.targetName != null)
          _StatRow('Target', _targetLabel(move.targetName!)),
        if (move.meta?.categoryName != null)
          _StatRow('Category', _fmt(move.meta!.categoryName!)),
      ],
    );
  }
}

// ── Meta / battle data ────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final MoveMeta meta;
  const _MetaCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (meta.ailmentName != null && meta.ailmentName != 'none') {
      rows.add(_StatRow('Ailment', _fmt(meta.ailmentName!)));
    }
    if (meta.ailmentChance > 0) {
      rows.add(_StatRow('Ailment chance', '${meta.ailmentChance}%'));
    }
    if (meta.flinchChance > 0) {
      rows.add(_StatRow('Flinch chance', '${meta.flinchChance}%'));
    }
    if (meta.critRate > 0) {
      rows.add(_StatRow('Crit stage', '+${meta.critRate}'));
    }
    if (meta.drain != 0) {
      rows.add(_StatRow('Drain', '${meta.drain}%'));
    }
    if (meta.healing != 0) {
      rows.add(_StatRow('Healing', '${meta.healing}%'));
    }
    if (meta.statChance > 0) {
      rows.add(_StatRow('Stat change', '${meta.statChance}%'));
    }
    if (meta.minHits != null && meta.maxHits != null) {
      rows.add(_StatRow('Hits',
          meta.minHits == meta.maxHits
              ? '${meta.minHits}'
              : '${meta.minHits}–${meta.maxHits}'));
    }
    if (meta.minTurns != null && meta.maxTurns != null) {
      rows.add(_StatRow('Duration', '${meta.minTurns}–${meta.maxTurns} turns'));
    }
    return Column(children: rows);
  }
}

// ── Flavor text ───────────────────────────────────────────────────────────────

class _FlavorSection extends StatefulWidget {
  final List<MoveFlavorText> entries;
  const _FlavorSection({required this.entries});

  @override
  State<_FlavorSection> createState() => _FlavorSectionState();
}

class _FlavorSectionState extends State<_FlavorSection> {
  String? _selectedVg;

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) {
      _selectedVg = widget.entries.last.versionGroupName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entries
        .where((e) => e.versionGroupName == _selectedVg)
        .firstOrNull;

    return _Section(
      title: 'Flavor Text',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_vgLabel(e.versionGroupName),
                        style: const TextStyle(fontSize: 11)),
                    selected: _selectedVg == e.versionGroupName,
                    onSelected: (_) =>
                        setState(() => _selectedVg = e.versionGroupName),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                );
              }).toList(),
            ),
          ),
          if (entry != null) ...[
            const SizedBox(height: 10),
            Text(entry.text, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ── Past values ───────────────────────────────────────────────────────────────

class _PastValuesCard extends StatelessWidget {
  final List<MovePastValue> pastValues;
  const _PastValuesCard({required this.pastValues});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: pastValues.map((pv) {
        final parts = <String>[];
        if (pv.power != null) parts.add('Power: ${pv.power}');
        if (pv.accuracy != null) parts.add('Acc: ${pv.accuracy}%');
        if (pv.pp != null) parts.add('PP: ${pv.pp}');
        if (pv.typeName != null) parts.add('Type: ${_fmt(pv.typeName!)}');
        if (pv.effect != null) parts.add(pv.effect!);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(_vgLabel(pv.versionGroupName),
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: Text(
                  parts.isEmpty ? '—' : parts.join('  ·  '),
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Contest ───────────────────────────────────────────────────────────────────

class _ContestCard extends StatelessWidget {
  final MoveEntry move;
  const _ContestCard({required this.move});

  @override
  Widget build(BuildContext context) {
    final combos = move.contestCombos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (move.contestTypeName != null)
          _StatRow('Contest type', _fmt(move.contestTypeName!)),
        if (combos != null) ...[
          if (combos.normalUseBefore.isNotEmpty)
            _StatRow('Use before', combos.normalUseBefore.map(_fmt).join(', ')),
          if (combos.normalUseAfter.isNotEmpty)
            _StatRow('Use after', combos.normalUseAfter.map(_fmt).join(', ')),
          if (combos.superUseBefore.isNotEmpty)
            _StatRow('Super — use before',
                combos.superUseBefore.map(_fmt).join(', ')),
          if (combos.superUseAfter.isNotEmpty)
            _StatRow('Super — use after',
                combos.superUseAfter.map(_fmt).join(', ')),
        ],
      ],
    );
  }
}

// ── Machines ──────────────────────────────────────────────────────────────────

class _MachinesCard extends ConsumerWidget {
  final List<MoveMachineRef> machines;
  const _MachinesCard({required this.machines});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: machines.map((m) => _MachineTile(machine: m)).toList(),
    );
  }
}

class _MachineTile extends ConsumerWidget {
  final MoveMachineRef machine;
  const _MachineTile({required this.machine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineAsync = ref.watch(machineProvider(machine.machineUrl));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(_vgLabel(machine.versionGroupName),
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          machineAsync.when(
            loading: () => const SizedBox(
              width: 80,
              height: 10,
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => Text('—', style: textTheme.bodySmall),
            data: (item) => GestureDetector(
              onTap: () => context.push('/items/${item['name']}'),
              child: Text(
                _fmt(item['name']!).toUpperCase(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Learned by Pokémon ────────────────────────────────────────────────────────

class _LearnedByGrid extends StatefulWidget {
  final List<MovePokemonRef> pokemon;
  const _LearnedByGrid({required this.pokemon});

  @override
  State<_LearnedByGrid> createState() => _LearnedByGridState();
}

class _LearnedByGridState extends State<_LearnedByGrid> {
  static const _pageSize = 30;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final visible = widget.pokemon.take(_shown).toList();
    final remaining = widget.pokemon.length - _shown;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          itemBuilder: (_, i) => _PokemonListTile(pokemon: visible[i]),
        ),
        if (remaining > 0) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() =>
                _shown = (_shown + _pageSize).clamp(0, widget.pokemon.length)),
            child: Text('Show more ($remaining remaining)'),
          ),
        ],
      ],
    );
  }
}

class _PokemonListTile extends StatelessWidget {
  final MovePokemonRef pokemon;
  const _PokemonListTile({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/versions/generation-viii/icons/${pokemon.id}.png';
    final fallbackUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${pokemon.id}.png';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      leading: CachedNetworkImage(
        imageUrl: iconUrl,
        width: 40,
        height: 30,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => CachedNetworkImage(
          imageUrl: fallbackUrl,
          width: 40,
          height: 30,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => Icon(
            Icons.catching_pokemon,
            size: 28,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      title: Text(pokemon.displayName),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push('/pokedex/${pokemon.id}'),
    );
  }
}

// ── Shared layout widgets ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _InfoBadge(
      {required this.label,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Display helpers ───────────────────────────────────────────────────────────

String _fmt(String s) => s
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

String _categoryLabel(String? cat) => cat == null ? '—' : _fmt(cat);

String _genLabel(String gen) {
  const m = {
    'generation-i': 'Gen I', 'generation-ii': 'Gen II',
    'generation-iii': 'Gen III', 'generation-iv': 'Gen IV',
    'generation-v': 'Gen V', 'generation-vi': 'Gen VI',
    'generation-vii': 'Gen VII', 'generation-viii': 'Gen VIII',
    'generation-ix': 'Gen IX',
  };
  return m[gen] ?? _fmt(gen);
}

String _targetLabel(String t) {
  const m = {
    'selected-pokemon': 'Selected Pokémon',
    'specific-move': 'Specific move',
    'ally': 'Ally',
    'users-field': "User's field",
    'user-or-ally': 'User or ally',
    'opponents-field': "Opponent's field",
    'user': 'User',
    'random-opponent': 'Random opponent',
    'all-other-pokemon': 'All others',
    'all-opponents': 'All opponents',
    'entire-field': 'Entire field',
    'user-and-allies': 'User and allies',
    'all-pokemon': 'All Pokémon',
    'all-allies': 'All allies',
    'fainting-pokemon': 'Fainting Pokémon',
  };
  return m[t] ?? _fmt(t);
}

String _vgLabel(String vg) {
  const m = {
    'red-blue': 'Red/Blue', 'yellow': 'Yellow',
    'gold-silver': 'Gold/Silver', 'crystal': 'Crystal',
    'ruby-sapphire': 'Ruby/Sapphire', 'emerald': 'Emerald',
    'firered-leafgreen': 'FR/LG',
    'diamond-pearl': 'Diamond/Pearl', 'platinum': 'Platinum',
    'heartgold-soulsilver': 'HG/SS',
    'black-white': 'Black/White', 'black-2-white-2': 'B2/W2',
    'x-y': 'X/Y', 'omega-ruby-alpha-sapphire': 'OR/AS',
    'sun-moon': 'Sun/Moon', 'ultra-sun-ultra-moon': 'US/UM',
    'sword-shield': 'Sword/Shield',
    'brilliant-diamond-and-shining-pearl': 'BD/SP',
    'legends-arceus': 'Legends: Arceus',
    'scarlet-violet': 'Scarlet/Violet',
  };
  return m[vg] ?? _fmt(vg);
}
