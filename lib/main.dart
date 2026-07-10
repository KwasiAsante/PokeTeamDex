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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:poke_team_dex/services/firebase/fcm_service.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/update/update_provider.dart';
import 'package:poke_team_dex/services/tray/tray_service.dart';
import 'package:poke_team_dex/shared/theme/app_theme.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart'
    show kBackendFallbackBoxName, clearBackendFallbackCacheIfStale;
import 'package:poke_team_dex/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poke_team_dex/shared/widgets/shutdown_dialog.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

const _syncTaskName = 'poketeamdex.sync';
const _kPendingUpdateKey = 'pending_update_check';

// Top-level handler for FCM messages received while app is killed or in background.
// Runs in a separate isolate — no Riverpod access. Stores a flag for the next resume.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  if (message.data['type'] == 'app_update') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPendingUpdateKey, true);
  }
}

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
  await dotenv.load(fileName: '.env');

  // Capture Flutter framework errors (widget build failures, etc.)
  FlutterError.onError = (details) {
    AppLogger().e(
      'Flutter error: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Capture uncaught async errors (dart:async zone errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger().e('Unhandled error', error: error, stackTrace: stack);
    return false;
  };

  AppLogger().i('App starting');

  // window_manager must be initialised before runApp on desktop.
  if (TrayService.isSupported) {
    await windowManager.ensureInitialized();
  }

  await FcmService.init();

  // Register background FCM handler (must be top-level, called before runApp).
  if (FcmService.isSupported) {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  await Hive.initFlutter();
  await Hive.openBox('pokeapi_cache');
  await Hive.openBox(kBackendFallbackBoxName);
  await clearBackendFallbackCacheIfStale();

  await PokemonDataRegistry.initialize();

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
  StreamSubscription<bool>? _minimizeToTraySub;
  final _navigatorKey = GlobalKey<NavigatorState>();

  // The router must be built exactly once. Rebuilding it (e.g. inside
  // build() whenever authTokenProvider changes) recreates the GoRouter,
  // which re-applies initialLocation and causes a second, visible
  // navigation to /pokedex right after startup. Login/logout still update
  // the redirect logic live via _tokenNotifier + refreshListenable.
  late final _tokenNotifier = ValueNotifier<String?>(widget.initialToken);
  late final _router =
      buildAppRouter(_tokenNotifier, navigatorKey: _navigatorKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Seed auth state from persisted token
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(authTokenProvider.notifier).state = widget.initialToken ?? '';

      // Wire the API URL and stored auth token into the singleton logger.
      final configRepo = ref.read(appConfigRepositoryProvider);
      final apiUrl = await configRepo.getApiBaseUrl();
      AppLogger.configure(apiUrl);
      configRepo.watchApiBaseUrl().listen(AppLogger.configure);
      AppLogger.configureToken(widget.initialToken);

      // Initialize system tray after the first frame so the window is ready.
      if (TrayService.isSupported) {
        _trayService = TrayService(
          onSyncNow: _triggerSync,
          onQuit: _handleQuit,
        );
        await _trayService!.init();

        // Apply the persisted setting, then watch for future changes.
        final configRepo = ref.read(appConfigRepositoryProvider);
        final initiallyEnabled = await configRepo.getMinimizeToTray();
        if (initiallyEnabled) await _trayService!.enable();

        _minimizeToTraySub = configRepo.watchMinimizeToTray().listen((enabled) {
          if (enabled) {
            _trayService?.enable();
          } else {
            _trayService?.disable();
          }
        });
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

    if (FcmService.isSupported) {
      // Foreground: app is open when message arrives.
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['type'] == 'app_update') {
          ref.invalidate(updateCheckProvider);
        }
      });

      // Backgrounded app: user taps the notification.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (message.data['type'] == 'app_update') {
          ref.invalidate(updateCheckProvider);
        }
      });

      // Killed app: user taps the notification that launched the app.
      // didChangeAppLifecycleState does not fire on initial launch, so the
      // SharedPreferences flag check in that callback is never reached here.
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message?.data['type'] == 'app_update') {
          ref.invalidate(updateCheckProvider);
        }
      });
    }
  }

  @override
  void dispose() {
    _minimizeToTraySub?.cancel();
    _periodicSync?.cancel();
    _trayService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _tokenNotifier.dispose();
    super.dispose();
  }

  // Called when app is foregrounded (lock-screen unlock, tab switch, notification tap, etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger().d('Lifecycle: ${state.name}');
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
      // If a background FCM message flagged a pending update, check now.
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool(_kPendingUpdateKey) == true) {
          prefs.remove(_kPendingUpdateKey);
          ref.invalidate(updateCheckProvider);
        }
      });
    }
  }

  void _triggerSync() {
    try {
      final token = ref.read(authTokenProvider);
      ref.read(syncServiceProvider).run(token: token);
    } catch (_) {
      // Sync is best-effort
    }
  }

  Future<void> _handleQuit() async {
    await windowManager.show();
    await windowManager.focus();
    final ctx = _navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const ShutdownDialog(),
      );
      // Give the dialog one frame to render before destroying.
      await Future.delayed(const Duration(milliseconds: 400));
    }
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // Forward auth state into the router's refreshListenable instead of
    // watching it here — watching would rebuild this widget and recreate
    // the GoRouter on every token change (see _router above).
    ref.listen<String?>(authTokenProvider, (_, next) {
      _tokenNotifier.value = next;
    });
    final seedValue = ref.watch(seedColorProvider).when(
          data: (v) => v,
          loading: () => kDefaultSeedColor,
          error: (_, _) => kDefaultSeedColor,
        );
    final themeMode = ref.watch(themeModeProvider).when(
          data: (v) => v,
          loading: () => ThemeMode.system,
          error: (_, _) => ThemeMode.system,
        );
    final seed = Color(seedValue);
    return MaterialApp.router(
      title: 'PokeTeamDex',
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: themeMode,
      routerConfig: _router,
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

