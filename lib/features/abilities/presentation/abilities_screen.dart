import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';

class AbilitiesScreen extends ConsumerStatefulWidget {
  const AbilitiesScreen({super.key});

  @override
  ConsumerState<AbilitiesScreen> createState() => _AbilitiesScreenState();
}

class _AbilitiesScreenState extends ConsumerState<AbilitiesScreen> {
  final _searchController = SearchController();

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
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _AbilityDetailSheet(ability: ability),
      ),
    );
  }
}

// ── Ability detail bottom sheet ───────────────────────────────────────────────

class _AbilityDetailSheet extends StatefulWidget {
  final AbilityEntry ability;
  const _AbilityDetailSheet({required this.ability});

  @override
  State<_AbilityDetailSheet> createState() => _AbilityDetailSheetState();
}

class _AbilityDetailSheetState extends State<_AbilityDetailSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ability = widget.ability;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  ability.displayName,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (ability.generationLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ability.generationLabel,
                    style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (ability.shortEffect != null) ...[
            Text(
              'Effect',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(ability.shortEffect!, style: textTheme.bodyMedium),
          ],
          if (ability.longEffect != null &&
              ability.longEffect != ability.shortEffect) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Hide details' : 'Show full details',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(ability.longEffect!, style: textTheme.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}
