import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/locations/providers/locations_provider.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(locationSearchProvider);
      if (saved.isNotEmpty) _searchController.text = saved;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredLocationsProvider);
    final regionFilter = ref.watch(locationRegionFilterProvider);
    final regionsAsync = ref.watch(regionLocationsProvider);
    final regions = regionsAsync.asData?.value.keys.toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search locations…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(locationSearchProvider.notifier).state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(locationSearchProvider.notifier).state = v,
                ),
              ),
              // Region filter chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: regionFilter == null,
                      onSelected: (_) => ref
                          .read(locationRegionFilterProvider.notifier)
                          .state = null,
                    ),
                    for (final r in regions) ...[
                      const SizedBox(width: 6),
                      FilterChip(
                        label: Text(_regionLabel(r)),
                        selected: regionFilter == r,
                        onSelected: (_) => ref
                            .read(locationRegionFilterProvider.notifier)
                            .state = regionFilter == r ? null : r,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: filteredAsync.when(
        loading: () => const SkeletonListView(
          count: 14,
          itemExtent: 56,
          leading: SkeletonLeading.circle,
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(regionLocationsProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.place_outlined,
              title: 'No locations found',
              subtitle: 'Try adjusting your search or region filter.',
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            itemExtent: 56,
            itemBuilder: (_, i) {
              final (region, loc) = entries[i];
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_locationLabel(loc)),
                subtitle: Text(_regionLabel(region),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/reference/locations/$loc'),
              );
            },
          );
        },
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
