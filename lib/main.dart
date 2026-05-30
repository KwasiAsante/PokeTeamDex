import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/router/app_router.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/shared/theme/app_theme.dart';
import 'package:workmanager/workmanager.dart';

const _syncTaskName = 'poketeamdex.sync';

@pragma('vm:entry-point')
void _workmanagerCallback() {
  Workmanager().executeTask((task, _) async {
    // Background sync is handled by SyncService; here we just return success.
    // A full implementation would init the DB and call SyncService.run().
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('pokeapi_cache');

  // Load stored auth token before first frame
  final token = await loadStoredToken();

  // Register WorkManager background task (Android/iOS only)
  if (!kIsWeb && !Platform.isWindows && Platform.isAndroid && !Platform.isLinux) {
    await Workmanager().initialize(_workmanagerCallback);
    await Workmanager().registerPeriodicTask(
      _syncTaskName,
      _syncTaskName,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  runApp(ProviderScope(child: MyApp(initialToken: token)));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.initialToken});
  final String? initialToken;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    // Seed auth state from persisted token
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authTokenProvider.notifier).state = widget.initialToken ?? '';
    });

    // Auto-sync when connectivity is restored
    if (!kIsWeb) {
      Connectivity().onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online) _triggerSync();
      });
    }
  }

  void _triggerSync() {
    try {
      ref.read(syncServiceProvider).run();
    } catch (_) {
      // Sync is best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild router when auth state changes so redirect logic re-evaluates
    final token = ref.watch(authTokenProvider);
    return MaterialApp.router(
      title: 'PokeTeamDex',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: buildAppRouter(token),
    );
  }
}

