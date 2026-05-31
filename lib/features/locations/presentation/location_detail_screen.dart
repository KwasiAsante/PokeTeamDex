import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/locations/providers/locations_provider.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  final String locationName;
  const LocationDetailScreen({super.key, required this.locationName});

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState
    extends ConsumerState<LocationDetailScreen> {
  String? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final locationAsync =
        ref.watch(locationDetailProvider(widget.locationName));

    return locationAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(_locationLabel(widget.locationName))),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(_locationLabel(widget.locationName))),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(
              locationDetailProvider(widget.locationName)),
        ),
      ),
      data: (location) {
        final regionName = (location['region'] as Map?)?['name'] as String?;
        final areas = (location['areas'] as List)
            .map((a) => a['name'] as String)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(_locationLabel(widget.locationName)),
            actions: [const SettingsButton()],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Region badge
              if (regionName != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.public, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _regionLabel(regionName),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              // Areas with encounters
              Expanded(
                child: areas.isEmpty
                    ? const EmptyState(
                        icon: Icons.place_outlined,
                        title: 'No areas found',
                        subtitle: 'This location has no encounter data.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: areas.length,
                        itemBuilder: (_, i) => _AreaTile(
                          areaName: areas[i],
                          selectedVersion: _selectedVersion,
                          onVersionSelected: (v) =>
                              setState(() => _selectedVersion = v),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Location area tile ────────────────────────────────────────────────────────

class _AreaTile extends ConsumerStatefulWidget {
  final String areaName;
  final String? selectedVersion;
  final ValueChanged<String?> onVersionSelected;

  const _AreaTile({
    required this.areaName,
    required this.selectedVersion,
    required this.onVersionSelected,
  });

  @override
  ConsumerState<_AreaTile> createState() => _AreaTileState();
}

class _AreaTileState extends ConsumerState<_AreaTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final areaAsync = ref.watch(locationAreaProvider(widget.areaName));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Area header
        ListTile(
          leading: Icon(Icons.terrain_outlined,
              color: colorScheme.primary, size: 20),
          title: Text(
            _locationLabel(widget.areaName),
            style:
                textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          areaAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Error loading area: $e',
                  style: TextStyle(color: colorScheme.error)),
            ),
            data: (area) {
              final encounters =
                  area['pokemon_encounters'] as List? ?? [];
              if (encounters.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                  child: Text('No encounter data available.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                );
              }

              // Collect all available game versions
              final allVersions = <String>{};
              for (final e in encounters) {
                for (final vd
                    in (e['version_details'] as List? ?? [])) {
                  allVersions
                      .add((vd['version'] as Map)['name'] as String);
                }
              }
              final versions = allVersions.toList()..sort();

              // Default to first version if nothing selected
              final activeVersion = widget.selectedVersion != null &&
                      versions.contains(widget.selectedVersion)
                  ? widget.selectedVersion!
                  : versions.isNotEmpty
                      ? versions.first
                      : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version filter chips
                  if (versions.length > 1)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        children: [
                          for (final v in versions) ...[
                            FilterChip(
                              label: Text(_versionLabel(v),
                                  style:
                                      const TextStyle(fontSize: 11)),
                              selected: v == activeVersion,
                              onSelected: (_) =>
                                  widget.onVersionSelected(v),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  // Encounters for selected version
                  if (activeVersion != null)
                    ..._buildEncounterRows(
                        context, encounters, activeVersion),
                ],
              );
            },
          ),
        const Divider(height: 1),
      ],
    );
  }

  List<Widget> _buildEncounterRows(
    BuildContext context,
    List encounters,
    String version,
  ) {
    final rows = <_EncounterRow>[];

    for (final enc in encounters) {
      final pokemonName =
          (enc['pokemon'] as Map)['name'] as String;
      final versionDetails = enc['version_details'] as List? ?? [];

      for (final vd in versionDetails) {
        if ((vd['version'] as Map)['name'] != version) continue;
        for (final detail
            in (vd['encounter_details'] as List? ?? [])) {
          rows.add(_EncounterRow(
            pokemonName: pokemonName,
            method: (detail['method'] as Map)['name'] as String,
            minLevel: detail['min_level'] as int,
            maxLevel: detail['max_level'] as int,
            chance: detail['chance'] as int,
          ));
        }
      }
    }

    // Deduplicate and sort by chance desc
    rows.sort((a, b) => b.chance.compareTo(a.chance));
    final seen = <String>{};
    final unique = rows
        .where((r) =>
            seen.add('${r.pokemonName}:${r.method}'))
        .toList();

    if (unique.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 12),
          child: Text(
              'No encounters in ${_versionLabel(version)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  )),
        ),
      ];
    }

    return [
      // Header row
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 16, 2),
        child: Row(
          children: [
            const SizedBox(width: 60),
            Expanded(
              child: Text('Pokémon',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      )),
            ),
            SizedBox(
              width: 80,
              child: Text('Method',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      )),
            ),
            SizedBox(
              width: 48,
              child: Text('Lv.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      )),
            ),
            SizedBox(
              width: 36,
              child: Text('%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      )),
            ),
          ],
        ),
      ),
      for (final row in unique)
        _EncounterListTile(row: row),
      const SizedBox(height: 8),
    ];
  }
}

// ── Encounter row data class ──────────────────────────────────────────────────

class _EncounterRow {
  final String pokemonName;
  final String method;
  final int minLevel;
  final int maxLevel;
  final int chance;

  const _EncounterRow({
    required this.pokemonName,
    required this.method,
    required this.minLevel,
    required this.maxLevel,
    required this.chance,
  });
}

class _EncounterListTile extends StatelessWidget {
  final _EncounterRow row;
  const _EncounterListTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Derive national dex ID from name for sprite
    // We can't easily get the ID without an API call, so use the raw name URL
    final spriteUrl =
        'https://play.pokemonshowdown.com/sprites/gen5/${row.pokemonName}.png';

    final levelStr = row.minLevel == row.maxLevel
        ? '${row.minLevel}'
        : '${row.minLevel}–${row.maxLevel}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          // Sprite
          CachedNetworkImage(
            imageUrl: spriteUrl,
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const Icon(Icons.catching_pokemon,
                size: 40),
          ),
          const SizedBox(width: 4),
          // Name
          Expanded(
            child: Text(
              _locationLabel(row.pokemonName),
              style: textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Method badge
          SizedBox(
            width: 80,
            child: Text(
              _methodLabel(row.method),
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Level
          SizedBox(
            width: 48,
            child: Text(
              levelStr,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ),
          // Chance
          SizedBox(
            width: 36,
            child: Text(
              '${row.chance}%',
              textAlign: TextAlign.right,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Display helpers ───────────────────────────────────────────────────────────

String _locationLabel(String name) =>
    name.split('-').map((w) => w.toCapitalCase()).join(' ');

String _regionLabel(String name) {
  const overrides = {
    'hisui': 'Hisui',
    'paldea': 'Paldea',
    'galar': 'Galar',
    'alola': 'Alola',
    'kalos': 'Kalos',
    'unova': 'Unova',
    'sinnoh': 'Sinnoh',
    'hoenn': 'Hoenn',
    'johto': 'Johto',
    'kanto': 'Kanto',
  };
  return overrides[name] ?? name.toCapitalCase();
}

String _versionLabel(String name) =>
    name.split('-').map((w) => w.toCapitalCase()).join(' ');

String _methodLabel(String method) {
  const labels = {
    'walk': 'Walking',
    'surf': 'Surfing',
    'old-rod': 'Old Rod',
    'good-rod': 'Good Rod',
    'super-rod': 'Super Rod',
    'rock-smash': 'Rock Smash',
    'headbutt': 'Headbutt',
    'gift': 'Gift',
    'only-one': 'Fixed',
    'pokeflute': 'Poké Flute',
  };
  return labels[method] ?? _locationLabel(method);
}
