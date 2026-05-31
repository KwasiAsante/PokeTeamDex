import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/abilities/presentation/abilities_screen.dart';
import 'package:poke_team_dex/features/auth/presentation/login_screen.dart';
import 'package:poke_team_dex/features/auth/presentation/register_screen.dart';
import 'package:poke_team_dex/features/items/presentation/item_detail_screen.dart';
import 'package:poke_team_dex/features/items/presentation/items_screen.dart';
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

GoRouter buildAppRouter(String? initialToken) {
  return GoRouter(
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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/sync-monitor', builder: (_, __) => const SyncMonitorScreen()),

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

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.catching_pokemon_outlined),
            activeIcon: Icon(Icons.catching_pokemon),
            label: 'Pokédex',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_martial_arts_outlined),
            activeIcon: Icon(Icons.sports_martial_arts),
            label: 'Moves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Reference',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'My Teams',
          ),
        ],
      ),
    );
  }
}
