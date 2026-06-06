import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/shared/widgets/update_banner.dart';
import 'package:poke_team_dex/features/abilities/presentation/abilities_screen.dart';
import 'package:poke_team_dex/features/abilities/presentation/ability_detail_screen.dart';
import 'package:poke_team_dex/features/auth/presentation/login_screen.dart';
import 'package:poke_team_dex/features/auth/presentation/register_screen.dart';
import 'package:poke_team_dex/features/items/presentation/item_detail_screen.dart';
import 'package:poke_team_dex/features/items/presentation/items_screen.dart';
import 'package:poke_team_dex/features/moves/presentation/move_detail_screen.dart';
import 'package:poke_team_dex/features/moves/presentation/moves_screen.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokedex_screen.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_screen.dart';
import 'package:poke_team_dex/features/natures/presentation/natures_screen.dart';
import 'package:poke_team_dex/features/reference/presentation/reference_hub_screen.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_config_screen.dart';
import 'package:poke_team_dex/features/locations/presentation/location_detail_screen.dart';
import 'package:poke_team_dex/features/locations/presentation/locations_screen.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_picker_screen.dart';
import 'package:poke_team_dex/features/teams/presentation/team_detail_screen.dart';
import 'package:poke_team_dex/features/teams/presentation/teams_screen.dart';
import 'package:poke_team_dex/features/settings/presentation/settings_screen.dart';
import 'package:poke_team_dex/features/settings/presentation/sync_monitor_screen.dart';
import 'package:poke_team_dex/features/types/presentation/types_screen.dart';

GoRouter buildAppRouter(
  String? initialToken, {
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/pokedex',
    redirect: (context, state) {
      // Teams are local-first and always accessible without auth.
      // Auth is only required to sync — the sync button handles that check.
      // The only redirect we keep: don't send already-logged-in users back
      // to the auth screens.
      final loggedIn = initialToken != null && initialToken.isNotEmpty;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (loggedIn && goingToAuth) return '/pokedex';
      return null;
    },
    routes: [
      // ── Auth ───────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/sync-monitor', builder: (_, _) => const SyncMonitorScreen()),

      // ── Main shell ─────────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pokedex',
                builder: (context, state) => const PokedexScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PokemonDetailScreen(
                      pokemonId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/moves',
                builder: (context, state) => const MovesScreen(),
                routes: [
                  GoRoute(
                    path: ':name',
                    builder: (context, state) => MoveDetailScreen(
                      moveName: state.pathParameters['name']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/items',
                builder: (context, state) => const ItemsScreen(),
                routes: [
                  GoRoute(
                    path: ':name',
                    builder: (context, state) => ItemDetailScreen(
                      itemName: state.pathParameters['name']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reference',
                builder: (context, state) => const ReferenceHubScreen(),
                routes: [
                  GoRoute(
                    path: 'locations',
                    builder: (context, state) => const LocationsScreen(),
                    routes: [
                      GoRoute(
                        path: ':location',
                        builder: (context, state) => LocationDetailScreen(
                          locationName:
                              state.pathParameters['location']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'abilities',
                    builder: (context, state) => const AbilitiesScreen(),
                    routes: [
                      GoRoute(
                        path: ':name',
                        builder: (context, state) => AbilityDetailScreen(
                          abilityName: state.pathParameters['name']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'types',
                    builder: (context, state) => const TypesScreen(),
                  ),
                  GoRoute(
                    path: 'natures',
                    builder: (context, state) => const NaturesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teams',
                builder: (context, state) => const TeamsScreen(),
                routes: [
                  GoRoute(
                    path: ':teamId',
                    builder: (context, state) => TeamDetailScreen(
                      teamId: int.parse(state.pathParameters['teamId']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'pick/:slot',
                        builder: (context, state) => SlotPickerScreen(
                          teamId:
                              int.parse(state.pathParameters['teamId']!),
                          slotNumber:
                              int.parse(state.pathParameters['slot']!),
                        ),
                      ),
                      GoRoute(
                        path: 'config/:slot',
                        builder: (context, state) => SlotConfigScreen(
                          key: ValueKey(
                            '${state.pathParameters['teamId']}-'
                            '${state.pathParameters['slot']}',
                          ),
                          teamId:
                              int.parse(state.pathParameters['teamId']!),
                          slotNumber:
                              int.parse(state.pathParameters['slot']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// Keep a top-level reference so existing code that imports `appRouter` still works.
// main.dart will call buildAppRouter(token) and use that instance instead.
final appRouter = buildAppRouter(null);

// ── Navigation destinations shared across all layout variants ─────────────────

typedef _NavDest = ({
  IconData icon,
  IconData activeIcon,
  String label,
});

const List<_NavDest> _destinations = [
  (icon: Icons.catching_pokemon_outlined, activeIcon: Icons.catching_pokemon,         label: 'Pokédex'),
  (icon: Icons.sports_martial_arts_outlined, activeIcon: Icons.sports_martial_arts,   label: 'Moves'),
  (icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2,                   label: 'Items'),
  (icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book,                       label: 'Reference'),
  (icon: Icons.groups_outlined, activeIcon: Icons.groups,                             label: 'My Teams'),
];

// Breakpoints from PRD §Responsive Breakpoints
const double _kMedium   = 600;
const double _kExpanded = 840;

// ── Adaptive shell ────────────────────────────────────────────────────────────

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final index = navigationShell.currentIndex;
    final shell = UpdateBanner(child: navigationShell);

    if (width >= _kExpanded) return _ExpandedLayout(shell: shell, currentIndex: index, onTap: _go);
    if (width >= _kMedium)   return _MediumLayout(shell: shell,   currentIndex: index, onTap: _go);
    return                          _CompactLayout(shell: shell,   currentIndex: index, onTap: _go);
  }
}

// ── Compact (< 600dp) — bottom navigation bar ─────────────────────────────────

class _CompactLayout extends StatelessWidget {
  final Widget shell;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _CompactLayout({required this.shell, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: [
          for (final d in _destinations)
            BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

// ── Medium (600–840dp) — navigation rail ──────────────────────────────────────

class _MediumLayout extends StatelessWidget {
  final Widget shell;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _MediumLayout({required this.shell, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            backgroundColor: colorScheme.surface,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

// ── Expanded (> 840dp) — permanent navigation drawer ─────────────────────────

class _ExpandedLayout extends StatefulWidget {
  final Widget shell;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _ExpandedLayout({required this.shell, required this.currentIndex, required this.onTap});

  @override
  State<_ExpandedLayout> createState() => _ExpandedLayoutState();
}

class _ExpandedLayoutState extends State<_ExpandedLayout> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar — full drawer or collapsed icon rail ─────────────────
          ClipRect(
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _collapsed ? 72 : 260,
            child: _collapsed
                // ── Collapsed: icon-only rail + expand button ─────────────
                ? Column(
                    children: [
                      // Expand toggle at top
                      SizedBox(
                        height: 56,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.menu_open),
                            tooltip: 'Expand navigation',
                            onPressed: () =>
                                setState(() => _collapsed = false),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _CollapsedRail(
                          selectedIndex: widget.currentIndex,
                          onTap: widget.onTap,
                        ),
                      ),
                    ],
                  )
                // ── Expanded: full NavigationDrawer ───────────────────────
                : NavigationDrawer(
                    selectedIndex: widget.currentIndex,
                    onDestinationSelected: widget.onTap,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                        child: Row(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 12),
                              child: Text(
                                'PokeTeamDex',
                                style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            // Collapse toggle
                            IconButton(
                              icon: const Icon(Icons.menu_open),
                              tooltip: 'Collapse navigation',
                              onPressed: () =>
                                  setState(() => _collapsed = true),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      for (final d in _destinations)
                        NavigationDrawerDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.activeIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
          ), // AnimatedContainer
          ), // ClipRect
          VerticalDivider(
              thickness: 1, width: 1,
              color: colorScheme.outlineVariant),
          Expanded(child: widget.shell),
        ],
      ),
    );
  }
}

// ── Collapsed rail ─────────────────────────────────────────────────────────
// Custom icon-only rail so Tooltip widgets own the pointer events directly.
// NavigationRail absorbs MouseRegion hover internally, preventing inner
// Tooltips from ever firing on desktop.

class _CollapsedRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _CollapsedRail({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: _destinations.length,
      itemBuilder: (_, i) {
        final d = _destinations[i];
        final selected = i == selectedIndex;
        return Tooltip(
          message: d.label,
          preferBelow: false,
          waitDuration: Duration.zero,
          child: InkWell(
            onTap: () => onTap(i),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: selected
                  ? BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    )
                  : null,
              child: Icon(
                selected ? d.activeIcon : d.icon,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
