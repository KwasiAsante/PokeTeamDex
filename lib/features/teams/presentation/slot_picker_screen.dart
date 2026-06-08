import 'dart:convert';

import 'package:change_case/change_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

// Local providers scoped to this screen (avoid polluting the Pokédex tab).
final _pickerSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _pickerFilterProvider =
    StateProvider.autoDispose<PokedexFilter>((ref) => const PokedexFilter());

/// Regional dex for the selected game — null when no game filter is active.
/// Mirrors the logic in filteredPokemonListProvider._gamePokedexProvider.
final _pickerGameDexProvider =
    FutureProvider.autoDispose<Map<String, int>?>((ref) async {
  final filter = ref.watch(_pickerFilterProvider);
  final gameId = filter.game;
  if (gameId == null) return null;

  final pokedexNames = kGameToPokedexNames[gameId];
  if (pokedexNames == null || pokedexNames.isEmpty) return null;

  final repo = ref.read(pokeApiRepositoryProvider);
  final merged = <String, int>{};
  for (final dexName in pokedexNames) {
    final dex = await repo.fetchRegionalPokedex(dexName);
    final offset = merged.isEmpty
        ? 0
        : merged.values.fold(0, (m, v) => v > m ? v : m);
    for (final entry in dex.entries) {
      if (!merged.containsKey(entry.key)) {
        merged[entry.key] = offset + entry.value;
      }
    }
  }
  return merged;
});

final _filteredPickerListProvider =
    Provider.autoDispose<AsyncValue<List<PokemonListEntry>>>((ref) {
  final listAsync    = ref.watch(pokemonListProvider);
  final gameDexAsync = ref.watch(_pickerGameDexProvider);
  final search       = ref.watch(_pickerSearchProvider).trim().toLowerCase();
  final filter       = ref.watch(_pickerFilterProvider);

  // Propagate loading from any async source.
  if (listAsync is AsyncLoading || gameDexAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (listAsync    is AsyncError) return AsyncValue.error(listAsync.error!,    listAsync.stackTrace!);
  if (gameDexAsync is AsyncError) return AsyncValue.error(gameDexAsync.error!, gameDexAsync.stackTrace!);

  var items = listAsync.requireValue;

  // Generation filter — skip when a game is active (game's regional dex
  // already defines which Pokémon appear, and may span multiple generations).
  if (filter.generation != null && filter.game == null) {
    final range = generationRanges[filter.generation!]!;
    items = items.where((p) => p.id >= range.$1 && p.id <= range.$2).toList();
  }

  // Game filter — restrict to Pokémon in the regional dex.
  final gameDex = gameDexAsync.requireValue;
  if (gameDex != null) {
    items = items.where((p) => gameDex.containsKey(p.name)).toList();
  }

  // Search.
  if (search.isNotEmpty) {
    items = items
        .where((p) =>
            p.name.contains(search) ||
            p.id.toString().contains(search) ||
            p.displayId().contains(search))
        .toList();
  }

  return AsyncValue.data(items);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SlotPickerScreen extends ConsumerStatefulWidget {
  final int teamId;
  final int slotNumber;

  const SlotPickerScreen({
    super.key,
    required this.teamId,
    required this.slotNumber,
  });

  @override
  ConsumerState<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends ConsumerState<SlotPickerScreen> {
  final _searchController = SearchController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-seed the filter from the team's format after the first frame so that
    // the provider container is ready and the team stream has been subscribed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadFormatFilter());
  }

  void _preloadFormatFilter() {
    final team = ref.read(teamByIdProvider(widget.teamId)).asData?.value;
    if (team == null || team.formatLabel == null) return;

    final format =
        ref.read(formatServiceProvider).formatById(team.formatLabel!);
    if (format == null) return;

    final isGameFormat = format.type == FormatType.game;
    ref.read(_pickerFilterProvider.notifier).state = PokedexFilter(
      generation: format.gen,
      game: isGameFormat ? format.id : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectPokemon(PokemonListEntry entry) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(teamSlotRepositoryProvider);
      final syncQueue = ref.read(syncQueueRepositoryProvider);

      await repo.deleteSlot(widget.teamId, widget.slotNumber);

      await repo.insert(
        TeamSlotsCompanion(
          teamId: Value(widget.teamId),
          slot: Value(widget.slotNumber),
          pokemonId: Value(entry.id),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await syncQueue.enqueue(PendingSyncOpsCompanion(
        operation: const Value('upsert'),
        entityType: const Value('team_slot'),
        entityId: Value(widget.teamId),
        payload: Value(jsonEncode({
          'team_local_id': widget.teamId,
          'slot': widget.slotNumber,
          'pokemon_id': entry.id,
        })),
        createdAt: Value(DateTime.now()),
      ));

      if (mounted) {
        context.replace(
          '/teams/${widget.teamId}/config/${widget.slotNumber}',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to add Pokémon: $e', isError: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(_filteredPickerListProvider);
    final filter = ref.watch(_pickerFilterProvider);

    // Resolve format name for the subtitle (if any).
    final team = ref.watch(teamByIdProvider(widget.teamId)).asData?.value;
    final format = (team?.formatLabel != null)
        ? ref.watch(formatServiceProvider).formatById(team!.formatLabel!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: format != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pick for Slot ${widget.slotNumber}'),
                  Text(
                    'Filtered for ${format.name}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : Text('Pick for Slot ${widget.slotNumber}'),
        actions: [const ConnectivityStatusButton(), const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search Pokémon…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(_pickerSearchProvider.notifier).state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(_pickerSearchProvider.notifier).state = v,
                ),
              ),
              _GenFilterBar(currentFilter: filter),
            ],
          ),
        ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : filteredAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No Pokémon found',
                    subtitle: 'Try adjusting your search or filter.',
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemExtent: 64,
                  itemBuilder: (_, i) => _PickerTile(
                    entry: entries[i],
                    onTap: () => _selectPokemon(entries[i]),
                  ),
                );
              },
            ),
    );
  }
}

// ── Generation filter bar ─────────────────────────────────────────────────────

class _GenFilterBar extends ConsumerWidget {
  final PokedexFilter currentFilter;
  const _GenFilterBar({required this.currentFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          FilterChip(
            label: const Text('All'),
            selected: currentFilter.generation == null && currentFilter.game == null,
            onSelected: (_) => ref
                .read(_pickerFilterProvider.notifier)
                .state = const PokedexFilter(),
          ),
          const SizedBox(width: 6),
          for (int gen = 1; gen <= 9; gen++) ...[
            FilterChip(
              label: Text('Gen $gen'),
              selected: currentFilter.generation == gen && currentFilter.game == null,
              onSelected: (_) => ref
                  .read(_pickerFilterProvider.notifier)
                  .state = PokedexFilter(generation: gen),
            ),
            const SizedBox(width: 6),
          ],
          // Game chip — shown when a game-specific filter is active.
          if (currentFilter.game != null) ...[
            FilterChip(
              avatar: const Icon(Icons.videogame_asset_outlined, size: 14),
              label: Text(currentFilter.game!.toUpperCase()),
              selected: true,
              onSelected: (_) => ref
                  .read(_pickerFilterProvider.notifier)
                  .state = PokedexFilter(generation: currentFilter.generation),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ── Picker tile ───────────────────────────────────────────────────────────────

class _PickerTile extends ConsumerWidget {
  final PokemonListEntry entry;
  final VoidCallback onTap;

  const _PickerTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final detailAsync = ref.watch(pokemonDetailProvider(entry.id));
    final displayName = detailAsync.asData?.value.displaySpeciesName ??
        entry.name.toCapitalCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: NetworkImage(entry.imageUrl),
      ),
      title: Text(
        displayName,
        style: textTheme.bodyLarge,
      ),
      trailing: Text(
        entry.displayId(),
        style: textTheme.bodySmall
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }
}
