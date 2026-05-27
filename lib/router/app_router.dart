import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokedex_placeholder_screen.dart';
import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/pokedex',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNavBar(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pokedex',
              builder: (context, state) => const PokedexPlaceholderScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      PokemonDetailPlaceholderScreen(goRouterState: state),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/moves',
              builder: (context, state) => const MovesPlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/items',
              builder: (context, state) => const ItemsPlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reference',
              builder: (context, state) => const ReferencePlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/teams',
              builder: (context, state) => const TeamsPlaceholderScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class MovesPlaceholderScreen extends StatelessWidget {
  const MovesPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ItemsPlaceholderScreen extends StatelessWidget {
  const ItemsPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ReferencePlaceholderScreen extends StatelessWidget {
  const ReferencePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class TeamsPlaceholderScreen extends StatelessWidget {
  const TeamsPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Pokedex'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Moves'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Items'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Reference',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'My Teams',
          ),
        ],
      ),
    );
  }
}
