import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class AbilityDetailScreen extends ConsumerWidget {
  final String abilityName;
  const AbilityDetailScreen({super.key, required this.abilityName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityProvider(abilityName));

    return abilityAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_fmt(abilityName))),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(_fmt(abilityName))),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(abilityProvider(abilityName)),
        ),
      ),
      data: (ability) => _AbilityDetailBody(ability: ability),
    );
  }
}

class _AbilityDetailBody extends StatelessWidget {
  final AbilityEntry ability;
  const _AbilityDetailBody({required this.ability});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(ability.displayName),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _AbilityHeader(ability: ability),

            // ── Effect ──
            if (ability.longEffect != null)
              _Section(
                title: 'Effect',
                child: Text(ability.longEffect!,
                    style: textTheme.bodyMedium),
              )
            else if (ability.shortEffect != null)
              _Section(
                title: 'Effect',
                child: Text(ability.shortEffect!,
                    style: textTheme.bodyMedium),
              ),

            // ── Effect changes ──
            if (ability.effectChanges.isNotEmpty)
              _Section(
                title: 'Effect Changes',
                child: _EffectChangesCard(changes: ability.effectChanges),
              ),

            // ── Flavor text ──
            if (ability.flavorTextEntries.isNotEmpty)
              _FlavorSection(entries: ability.flavorTextEntries),

            // ── Pokémon with this ability ──
            if (ability.pokemon.isNotEmpty)
              _Section(
                title:
                    'Pokémon with this ability (${ability.pokemon.length})',
                child: _PokemonList(pokemon: ability.pokemon),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Effect changes ────────────────────────────────────────────────────────────

class _EffectChangesCard extends StatelessWidget {
  final List<AbilityEffectChange> changes;
  const _EffectChangesCard({required this.changes});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changes.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_vgLabel(c.versionGroupName),
                  style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary)),
              const SizedBox(height: 4),
              Text(c.effect, style: textTheme.bodySmall),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Flavor text ───────────────────────────────────────────────────────────────

class _FlavorSection extends StatefulWidget {
  final List<AbilityFlavorText> entries;
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

// ── Pokémon list ──────────────────────────────────────────────────────────────

class _PokemonList extends StatefulWidget {
  final List<AbilityPokemonRef> pokemon;
  const _PokemonList({required this.pokemon});

  @override
  State<_PokemonList> createState() => _PokemonListState();
}

class _PokemonListState extends State<_PokemonList> {
  static const _pageSize = 30;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final visible = widget.pokemon.take(_shown).toList();
    final remaining = widget.pokemon.length - _shown;

    return Column(
      children: [
        ...visible.map((p) => _PokemonTile(pokemon: p)),
        if (remaining > 0) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() => _shown =
                (_shown + _pageSize).clamp(0, widget.pokemon.length)),
            child: Text('Show more ($remaining remaining)'),
          ),
        ],
      ],
    );
  }
}

class _PokemonTile extends ConsumerWidget {
  final AbilityPokemonRef pokemon;
  const _PokemonTile({required this.pokemon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sprites = ref
        .watch(resolvedPokemonProvider((id: pokemon.pokemonId, gen: null)))
        .asData
        ?.value
        .spriteUrls;
    final iconUrl = sprites?.icon ?? sprites?.gameFront ??
        PokemonDataResolver.genViiiIconFallbackUrl(pokemon.pokemonId);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CachedNetworkImage(
        imageUrl: iconUrl,
        width: 40,
        height: 30,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => Icon(Icons.catching_pokemon,
            size: 28,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
      title: Text(pokemon.displayName),
      subtitle: pokemon.isHidden
          ? Text('Hidden ability',
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.tertiary))
          : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push('/pokedex/${pokemon.pokemonId}'),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AbilityHeader extends StatelessWidget {
  final AbilityEntry ability;
  const _AbilityHeader({required this.ability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ability.displayName,
                  style: textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (ability.generationLabel.isNotEmpty)
                      _Chip(
                        label: ability.generationLabel,
                        color: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                      ),
                    _Chip(
                      label: ability.isMainSeries ? 'Main series' : 'Side game',
                      color: ability.isMainSeries
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      textColor: ability.isMainSeries
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
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

// ── Shared widgets ────────────────────────────────────────────────────────────

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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Chip({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(String s) => s
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

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
