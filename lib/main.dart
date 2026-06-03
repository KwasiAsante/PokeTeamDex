import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/database/repositories/meta_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/pokemon_instance_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';
import 'package:poke_team_dex/router/app_router.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_service.dart';
import 'package:poke_team_dex/services/tray/tray_service.dart';
import 'package:poke_team_dex/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

const _syncTaskName = 'poketeamdex.sync';

@pragma('vm:entry-point')
void _workmanagerCallback() {
  Workmanager().executeTask((task, _) async {
    try {
      await Hive.initFlutter();
      await Hive.openBox('pokeapi_cache');

      final db = AppDatabase();
      final configRepo  = AppConfigRepository(db);
      final metaRepo    = MetaRepository(db);
      final syncQueue   = SyncQueueRepository(db);
      final folderRepo  = TeamFolderRepository(db);
      final teamRepo    = TeamRepository(db);
      final slotRepo        = TeamSlotRepository(db, syncQueue);
      final instanceRepo    = PokemonInstanceRepository(db, syncQueue);

      final apiBaseUrl = await configRepo.getApiBaseUrl();
      final prefs      = await SharedPreferences.getInstance();
      final token      = prefs.getString('auth_token');

      // Skip if not authenticated
      if (token == null || token.isEmpty) {
        await db.close();
        return true;
      }

      final dio = Dio(BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ));

      final api      = TeamSyncApi(dio);
      final notifier = SyncStateNotifier();

      await SyncService(
        syncQueue:    syncQueue,
        folderRepo:   folderRepo,
        teamRepo:     teamRepo,
        slotRepo:     slotRepo,
        instanceRepo: instanceRepo,
        metaRepo:     metaRepo,
        api:          api,
        db:           db,
        notifier:     notifier,
      ).run();

      await db.close();
      return true;
    } catch (_) {
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // window_manager must be initialised before runApp on desktop.
  if (TrayService.isSupported) {
    await windowManager.ensureInitialized();
  }

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

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  Timer? _periodicSync;
  TrayService? _trayService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Seed auth state from persisted token
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(authTokenProvider.notifier).state = widget.initialToken ?? '';

      // Initialize system tray after the first frame so the window is ready.
      if (TrayService.isSupported) {
        _trayService = TrayService(onSyncNow: _triggerSync);
        await _trayService!.init();
      }
    });

    // Periodic in-process sync (covers app minimized / backgrounded).
    // WorkManager handles the truly-closed case on Android/iOS; this timer
    // runs while the app process is alive on every platform including desktop.
    _periodicSync = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _triggerSync(),
    );

    // Auto-sync when connectivity is restored
    if (!kIsWeb) {
      Connectivity().onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online) _triggerSync();
      });
    }
  }

  @override
  void dispose() {
    _periodicSync?.cancel();
    _trayService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Sync when the app is foregrounded (covers lock-screen unlock, tab switch, etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _triggerSync();
  }

  void _triggerSync() {
    try {
      final token = ref.read(authTokenProvider);
      ref.read(syncServiceProvider).run(token: token);
    } catch (_) {
      // Sync is best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild router when auth state changes so redirect logic re-evaluates
    final token = ref.watch(authTokenProvider);
    final seedValue = ref.watch(seedColorProvider).when(
          data: (v) => v,
          loading: () => kDefaultSeedColor,
          error: (_, __) => kDefaultSeedColor,
        );
    final themeMode = ref.watch(themeModeProvider).when(
          data: (v) => v,
          loading: () => ThemeMode.system,
          error: (_, __) => ThemeMode.system,
        );
    final seed = Color(seedValue);
    return MaterialApp.router(
      title: 'PokeTeamDex',
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: themeMode,
      routerConfig: buildAppRouter(token),
      // Cap text scaling at 1.3× to prevent overflow in fixed-height
      // list tiles and grid cells throughout the app.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.8,
        maxScaleFactor: 1.3,
        child: child!,
      ),
    );
  }
}

