import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/skeleton_box.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemName;
  const ItemDetailScreen({super.key, required this.itemName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(itemName));

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_fmt(itemName))),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(_fmt(itemName))),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(itemProvider(itemName)),
        ),
      ),
      data: (item) => _ItemDetailBody(item: item),
    );
  }
}

class _ItemDetailBody extends StatelessWidget {
  final ItemEntry item;
  const _ItemDetailBody({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayName),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(item: item),
            if ((item.cost != null && item.cost! > 0) ||
                item.flingPower != null ||
                item.flingEffectName != null)
              _Section(
                title: 'Details',
                child: _DetailsCard(item: item),
              ),
            if (item.attributes.isNotEmpty)
              _Section(
                title: 'Attributes',
                child: _AttributesCard(attributes: item.attributes),
              ),
            if (item.longEffect != null)
              _Section(
                title: 'Effect',
                child: Text(item.longEffect!,
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else if (item.shortEffect != null)
              _Section(
                title: 'Effect',
                child: Text(item.shortEffect!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (item.flavorTextEntries.isNotEmpty)
              _FlavorSection(entries: item.flavorTextEntries),
            if (item.hasBabyTrigger)
              _Section(
                title: 'Baby Trigger',
                child: Text(
                  'Holding this item allows a Pokémon in the Day Care to '
                  'produce a baby Pokémon egg.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (item.machines.isNotEmpty)
              _Section(
                title: 'Move Taught',
                child: _MachinesCard(machines: item.machines),
              ),
            if (item.heldByPokemon.isNotEmpty)
              _Section(
                title: 'Held by Pokémon (${item.heldByPokemon.length})',
                child: _HeldByList(heldBy: item.heldByPokemon),
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
  final ItemEntry item;
  const _Header({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.spriteUrl != null
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CachedNetworkImage(
                      imageUrl: item.spriteUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Icon(Icons.inventory_2_outlined,
                    size: 40, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName,
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (item.categoryLabel.isNotEmpty)
                  _Chip(label: item.categoryLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Details card ──────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final ItemEntry item;
  const _DetailsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (item.cost != null && item.cost! > 0)
          _StatRow('Buy price', '₽${item.cost}'),
        if (item.flingPower != null)
          _StatRow('Fling power', '${item.flingPower}'),
        if (item.flingEffectName != null)
          _StatRow('Fling effect', _fmt(item.flingEffectName!)),
      ],
    );
  }
}

// ── Attributes ────────────────────────────────────────────────────────────────

class _AttributesCard extends StatelessWidget {
  final List<String> attributes;
  const _AttributesCard({required this.attributes});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attributes.map((a) => _Chip(label: _fmt(a))).toList(),
    );
  }
}

// ── Flavor text ───────────────────────────────────────────────────────────────

class _FlavorSection extends StatefulWidget {
  final List<ItemFlavorText> entries;
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

// ── Machines (move taught) ────────────────────────────────────────────────────

class _MachinesCard extends ConsumerWidget {
  final List<ItemMachineRef> machines;
  const _MachinesCard({required this.machines});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: machines.map((m) => _MachineTile(machine: m)).toList(),
    );
  }
}

class _MachineTile extends ConsumerWidget {
  final ItemMachineRef machine;
  const _MachineTile({required this.machine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For items, the machine tells us the MOVE this TM teaches
    // We use a move-specific machine provider
    final moveNameAsync = ref.watch(_moveMachineProvider(machine.machineUrl));
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
          moveNameAsync.when(
            loading: () => const SkeletonBox(width: 80, height: 12),
            error: (_, _) => Text('—', style: textTheme.bodySmall),
            data: (moveName) => GestureDetector(
              onTap: moveName != null
                  ? () => context.push('/moves/$moveName')
                  : null,
              child: Text(
                moveName != null ? _fmt(moveName) : '—',
                style: textTheme.bodySmall?.copyWith(
                  color: moveName != null ? colorScheme.primary : null,
                  fontWeight: moveName != null ? FontWeight.bold : null,
                  decoration: moveName != null
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fetches the MOVE name that a machine (TM/HM) teaches.
final _moveMachineProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, url) async {
  try {
    return await ref.read(pokeApiRepositoryProvider).fetchMachineMove(url);
  } catch (_) {
    return null;
  }
});

// ── Held by Pokémon ───────────────────────────────────────────────────────────

class _HeldByList extends StatefulWidget {
  final List<ItemHeldByPokemon> heldBy;
  const _HeldByList({required this.heldBy});

  @override
  State<_HeldByList> createState() => _HeldByListState();
}

class _HeldByListState extends State<_HeldByList> {
  static const _pageSize = 30;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final visible = widget.heldBy.take(_shown).toList();
    final remaining = widget.heldBy.length - _shown;

    return Column(
      children: [
        ...visible.map((h) => _HeldByTile(heldBy: h)),
        if (remaining > 0) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() =>
                _shown = (_shown + _pageSize).clamp(0, widget.heldBy.length)),
            child: Text('Show more ($remaining remaining)'),
          ),
        ],
      ],
    );
  }
}

class _HeldByTile extends StatefulWidget {
  final ItemHeldByPokemon heldBy;
  const _HeldByTile({required this.heldBy});

  @override
  State<_HeldByTile> createState() => _HeldByTileState();
}

class _HeldByTileState extends State<_HeldByTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final iconUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/versions/generation-viii/icons/'
        '${widget.heldBy.pokemonId}.png';
    final fallbackUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/${widget.heldBy.pokemonId}.png';

    final maxRarity = widget.heldBy.versionDetails.isEmpty
        ? 0
        : widget.heldBy.versionDetails
            .map((v) => v.rarity)
            .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CachedNetworkImage(
            imageUrl: iconUrl,
            width: 40,
            height: 30,
            fit: BoxFit.contain,
            errorWidget: (_, _, _) => CachedNetworkImage(
              imageUrl: fallbackUrl,
              width: 40,
              height: 30,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => Icon(Icons.catching_pokemon,
                  size: 28,
                  color: colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4)),
            ),
          ),
          title: Text(widget.heldBy.displayName),
          subtitle: maxRarity > 0
              ? Text('$maxRarity% chance',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.heldBy.versionDetails.length > 1)
                IconButton(
                  icon: Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                  visualDensity: VisualDensity.compact,
                ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          onTap: () =>
              context.push('/pokedex/${widget.heldBy.pokemonId}'),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.heldBy.versionDetails.map((vd) {
                return Text(
                  '${_fmt(vd.versionName)}: ${vd.rarity}%',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                );
              }).toList(),
            ),
          ),
      ],
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold)),
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
