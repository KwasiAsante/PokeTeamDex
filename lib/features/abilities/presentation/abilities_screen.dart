import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';

class AbilitiesScreen extends ConsumerStatefulWidget {
  const AbilitiesScreen({super.key});

  @override
  ConsumerState<AbilitiesScreen> createState() => _AbilitiesScreenState();
}

class _AbilitiesScreenState extends ConsumerState<AbilitiesScreen> {
  final _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(abilitiesSearchProvider);
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
    final filteredAsync = ref.watch(filteredAbilitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abilities'),
        actions: [const SettingsButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search abilities…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(abilitiesSearchProvider.notifier).state = '';
                    },
                  ),
              ],
              onChanged: (v) =>
                  ref.read(abilitiesSearchProvider.notifier).state = v,
            ),
          ),
        ),
      ),
      body: filteredAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(abilitiesListProvider),
        ),
        data: (names) {
          if (names.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No abilities found',
              subtitle: 'Try adjusting your search.',
            );
          }
          return ListView.builder(
            itemCount: names.length,
            itemExtent: 88,
            itemBuilder: (_, i) => _AbilityTile(name: names[i]),
          );
        },
      ),
    );
  }
}

// ── Ability tile (lazy detail fetch) ─────────────────────────────────────────

class _AbilityTile extends ConsumerWidget {
  final String name;
  const _AbilityTile({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityProvider(name));

    return abilityAsync.when(
      loading: () => ListTile(
        title: Text(_fmt(name)),
        subtitle: const LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(
        title: Text(_fmt(name)),
        subtitle: const Text('—'),
      ),
      data: (ability) => _AbilityListItem(ability: ability),
    );
  }

  static String _fmt(String s) => s
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _AbilityListItem extends StatelessWidget {
  final AbilityEntry ability;
  const _AbilityListItem({required this.ability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.auto_awesome, size: 18, color: colorScheme.onPrimaryContainer),
      ),
      title: Row(
        children: [
          Text(ability.displayName, style: textTheme.bodyLarge),
          if (ability.generationLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ability.generationLabel,
                style: textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ],
      ),
      subtitle: ability.shortEffect != null
          ? Text(
              ability.shortEffect!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            )
          : null,
      onTap: () => context.push('/reference/abilities/${ability.name}'),
    );
  }
}

