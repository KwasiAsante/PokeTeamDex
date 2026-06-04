import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/meta_repository.dart';
import 'package:poke_team_dex/database/repositories/pokemon_instance_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';
import 'package:poke_team_dex/services/api/team_sync_api.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:poke_team_dex/services/sync/sync_service.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockSyncQueue extends Mock implements SyncQueueRepository {}
class MockFolderRepo extends Mock implements TeamFolderRepository {}
class MockTeamRepo extends Mock implements TeamRepository {}
class MockSlotRepo extends Mock implements TeamSlotRepository {}
class MockInstanceRepo extends Mock implements PokemonInstanceRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}
class MockTeamSyncApi extends Mock implements TeamSyncApi {}
class MockAppDatabase extends Mock implements AppDatabase {}

/// Simple spy that records which state-transition methods were called.
class _FakeNotifier implements SyncNotifier {
  final calls = <String>[];
  @override void setSyncing() => calls.add('syncing');
  @override void setSuccess() => calls.add('success');
  @override void setError(String message) => calls.add('error:$message');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Empty pull response — no remote entities to merge.
const _emptyPull = <String, dynamic>{
  'folders': [],
  'teams': [],
  'slots': [],
  'instances': [],
};

SyncService _makeService({
  required MockSyncQueue syncQueue,
  required MockTeamSyncApi api,
  required MockMetaRepo metaRepo,
  required _FakeNotifier notifier,
}) =>
    SyncService(
      syncQueue: syncQueue,
      folderRepo: MockFolderRepo(),
      teamRepo: MockTeamRepo(),
      slotRepo: MockSlotRepo(),
      instanceRepo: MockInstanceRepo(),
      metaRepo: metaRepo,
      api: api,
      db: MockAppDatabase(),
      notifier: notifier,
    );

void main() {
  late MockSyncQueue syncQueue;
  late MockTeamSyncApi api;
  late MockMetaRepo metaRepo;
  late _FakeNotifier notifier;

  setUp(() {
    syncQueue = MockSyncQueue();
    api = MockTeamSyncApi();
    metaRepo = MockMetaRepo();
    notifier = _FakeNotifier();
  });

  group('SyncService.run', () {
    test('no-ops when token is null', () async {
      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );
      await svc.run(token: null);
      expect(notifier.calls, isEmpty);
    });

    test('no-ops when token is empty string', () async {
      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );
      await svc.run(token: '');
      expect(notifier.calls, isEmpty);
    });

    test('no-ops when already running (second call skipped)', () async {
      // Return a pending op on first call, then hang on pushBatch so the
      // service stays "running". We check that a concurrent second call
      // returns immediately without touching the notifier a second time.
      when(() => syncQueue.getPending()).thenAnswer((_) async => []);
      when(() => metaRepo.get(any())).thenAnswer((_) async => null);
      when(() => api.pullSince(any())).thenAnswer((_) async => _emptyPull);

      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );

      final first = svc.run(token: 'tok');
      final second = svc.run(token: 'tok'); // should be a no-op
      await Future.wait([first, second]);

      // setSyncing should only have been called once.
      expect(notifier.calls.where((c) => c == 'syncing'), hasLength(1));
    });

    test('setSuccess when push queue empty and pull succeeds', () async {
      when(() => syncQueue.getPending()).thenAnswer((_) async => []);
      when(() => metaRepo.get(any())).thenAnswer((_) async => null);
      when(() => metaRepo.set(any(), any())).thenAnswer((_) async {});
      when(() => api.pullSince(any())).thenAnswer((_) async => _emptyPull);

      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );
      await svc.run(token: 'tok');

      expect(notifier.calls, ['syncing', 'success']);
    });

    test('setError(retry message) when push fails with DioException but pull succeeds', () async {
      // Return one active op so drain tries to push.
      final op = PendingSyncOp(
        id: 1,
        operation: 'create',
        entityType: 'team_folder',
        entityId: 1,
        payload: '{"name":"Foo"}',
        attempts: 0,
        createdAt: DateTime(2024),
      );
      when(() => syncQueue.getPending()).thenAnswer((_) async => [op]);
      when(() => syncQueue.markAttempted(any(), any())).thenAnswer((_) async {});

      // pushBatch throws a DioException.
      when(() => api.pushBatch(any())).thenThrow(
        DioException(requestOptions: RequestOptions()),
      );

      when(() => metaRepo.get(any())).thenAnswer((_) async => null);
      when(() => metaRepo.set(any(), any())).thenAnswer((_) async {});
      when(() => api.pullSince(any())).thenAnswer((_) async => _emptyPull);

      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );
      await svc.run(token: 'tok');

      expect(notifier.calls.first, 'syncing');
      expect(
        notifier.calls.last,
        startsWith('error:Some changes failed to sync'),
      );
    });

    test('setError with pull exception message when pull throws', () async {
      when(() => syncQueue.getPending()).thenAnswer((_) async => []);
      when(() => metaRepo.get(any())).thenAnswer((_) async => null);
      when(() => api.pullSince(any()))
          .thenThrow(Exception('network timeout'));

      final svc = _makeService(
        syncQueue: syncQueue, api: api, metaRepo: metaRepo, notifier: notifier,
      );
      await svc.run(token: 'tok');

      expect(notifier.calls.first, 'syncing');
      expect(notifier.calls.last, contains('error:'));
      expect(notifier.calls.last, contains('network timeout'));
    });
  });
}
