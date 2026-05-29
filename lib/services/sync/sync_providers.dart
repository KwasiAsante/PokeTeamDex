import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';
import 'package:poke_team_dex/services/sync/sync_service.dart';
import 'package:poke_team_dex/services/sync/sync_status.dart';

// ── Sync state ────────────────────────────────────────────────────────────────

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  void setSyncing() => state = state.copyWith(status: SyncStatus.syncing);

  void setSuccess() => state = state.copyWith(
        status: SyncStatus.success,
        lastSyncAt: DateTime.now(),
        errorMessage: null,
      );

  void setError(String message) => state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: message,
      );

  void setIdle() => state = state.copyWith(status: SyncStatus.idle);
}

// ── Sync service (wired to notifier) ─────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncQueue: ref.read(syncQueueRepositoryProvider),
    folderRepo: ref.read(teamFolderRepositoryProvider),
    teamRepo: ref.read(teamRepositoryProvider),
    slotRepo: ref.read(teamSlotRepositoryProvider),
    metaRepo: ref.read(metaRepositoryProvider),
    api: ref.read(teamSyncApiProvider),
    db: ref.read(appDatabaseProvider),
    notifier: ref.read(syncStateProvider.notifier),
  );
});

// ── Pending ops count ─────────────────────────────────────────────────────────

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueRepositoryProvider).watchPendingCount();
});

// ── Pending ops list ──────────────────────────────────────────────────────────

final pendingSyncOpsProvider = FutureProvider((ref) {
  return ref.watch(syncQueueRepositoryProvider).getPending();
});

// ── Backend health ────────────────────────────────────────────────────────────

enum HealthStatus { checking, healthy, unreachable }

final backendHealthProvider =
    FutureProvider.autoDispose<HealthStatus>((ref) async {
  try {
    final dio = ref.read(apiClientProvider).dio;
    final res = await dio.get<Map<String, dynamic>>(
      '/health',
      options: Options(receiveTimeout: const Duration(seconds: 5)),
    );
    return res.statusCode == 200
        ? HealthStatus.healthy
        : HealthStatus.unreachable;
  } catch (_) {
    return HealthStatus.unreachable;
  }
});

// ── PokéAPI health ────────────────────────────────────────────────────────────

final pokeApiHealthProvider =
    FutureProvider.autoDispose<HealthStatus>((ref) async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://pokeapi.co',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final res = await dio.get<dynamic>('/api/v2/pokemon/1');
    return res.statusCode == 200
        ? HealthStatus.healthy
        : HealthStatus.unreachable;
  } catch (_) {
    return HealthStatus.unreachable;
  }
});
