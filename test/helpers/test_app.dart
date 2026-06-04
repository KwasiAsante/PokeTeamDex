import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/services/connectivity/connectivity_provider.dart';

/// Pumps [screen] wrapped in a minimal ProviderScope + GoRouter + MaterialApp.
///
/// The [db] is injected via [appDatabaseProvider] override.
/// [authToken] controls the [authTokenProvider] initial value (null = logged out).
/// [extraOverrides] can supply additional Riverpod overrides.
Future<void> pumpTestApp(
  WidgetTester tester,
  Widget screen, {
  required AppDatabase db,
  String? authToken,
  List<dynamic> extraOverrides = const [],
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/login', builder: (_, _) => const _Stub('Login')),
      GoRoute(
        path: '/teams/:teamId',
        builder: (_, _) => const _Stub('Team Detail'),
        routes: [
          GoRoute(
            path: 'config/:slot',
            builder: (_, _) => const _Stub('Slot Config'),
          ),
          GoRoute(
            path: 'pick/:slot',
            builder: (_, _) => const _Stub('Slot Picker'),
          ),
        ],
      ),
      GoRoute(
        path: '/pokedex/:id',
        builder: (_, _) => const _Stub('Pokémon Detail'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authTokenProvider.overrideWith((ref) => authToken),
        isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        ...extraOverrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  // Close DB in tearDown (runs after _verifyInvariants, so its cleanup
  // timer is orphaned harmlessly in FakeAsync rather than failing the check).
  addTearDown(db.close);
}

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}
