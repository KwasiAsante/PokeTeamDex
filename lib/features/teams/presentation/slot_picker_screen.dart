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
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';

// Local search provider scoped to this screen (avoids polluting the Pokédex tab)
final _pickerSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _pickerFilterProvider =
    StateProvider.autoDispose<PokedexFilter>((ref) => const PokedexFilter());

final _filteredPickerListProvider =
    Provider.autoDispose<AsyncValue<List<PokemonListEntry>>>((ref) {
  final listAsync = ref.watch(pokemonListProvider);
  final search = ref.watch(_pickerSearchProvider).trim().toLowerCase();
  final filter = ref.watch(_pickerFilterProvider);

  return listAsync.whenData((items) {
    var filtered = items;

    if (filter.generation != null) {
      final range = generationRanges[filter.generation!]!;
      filtered = filtered
          .where((p) => p.id >= range.$1 && p.id <= range.$2)
          .toList();
    }

    if (search.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.name.contains(search) ||
              p.id.toString().contains(search) ||
              p.displayId().contains(search))
          .toList();
    }

    return filtered;
  });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(_filteredPickerListProvider);
    final filter = ref.watch(_pickerFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pick for Slot ${widget.slotNumber}'),
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
      body: filteredAsync.when(
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
              teamId: widget.teamId,
              slotNumber: widget.slotNumber,
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
            selected: currentFilter.generation == null,
            onSelected: (_) => ref
                .read(_pickerFilterProvider.notifier)
                .state = const PokedexFilter(),
          ),
          const SizedBox(width: 6),
          for (int gen = 1; gen <= 9; gen++) ...[
            FilterChip(
              label: Text('Gen $gen'),
              selected: currentFilter.generation == gen,
              onSelected: (_) => ref
                  .read(_pickerFilterProvider.notifier)
                  .state = PokedexFilter(generation: gen),
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
  final int teamId;
  final int slotNumber;

  const _PickerTile({
    required this.entry,
    required this.teamId,
    required this.slotNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: NetworkImage(entry.imageUrl),
      ),
      title: Text(
        entry.name.toCapitalCase(),
        style: textTheme.bodyLarge,
      ),
      trailing: Text(
        entry.displayId(),
        style: textTheme.bodySmall
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      onTap: () => _addToSlot(context, ref),
    );
  }

  Future<void> _addToSlot(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(teamSlotRepositoryProvider);
    final syncQueue = ref.read(syncQueueRepositoryProvider);

    // Remove any existing Pokémon in this slot first
    await repo.deleteSlot(teamId, slotNumber);

    // Insert the new slot
    await repo.insert(
      TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: Value(slotNumber),
        pokemonId: Value(entry.id),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await syncQueue.enqueue(PendingSyncOpsCompanion(
      operation: const Value('upsert'),
      entityType: const Value('team_slot'),
      entityId: Value(teamId),
      payload: Value(jsonEncode({
        'team_local_id': teamId,
        'slot': slotNumber,
        'pokemon_id': entry.id,
        'nickname': null,
      })),
      createdAt: Value(DateTime.now()),
    ));

    if (context.mounted) context.pop();
  }
}
