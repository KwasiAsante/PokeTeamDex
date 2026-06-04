// Integration tests: sync conflict resolution using a real in-memory database
// and repositories, with only the network API mocked.
//
// Tests verify the last-write-wins merge logic in SyncService._mergeFolders()
// and SyncService._mergeTeams().

import 'package:drift/drift.dart' show Value;
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
import '../helpers/test_database.dart';

class MockTeamSyncApi extends Mock implements TeamSyncApi {}

class _FakeNotifier implements SyncNotifier {
  final calls = <String>[];
  @override void setSyncing() => calls.add('syncing');
  @override void setSuccess() => calls.add('success');
  @override void setError(String m) => calls.add('error:$m');
}

/// Minimal pull response with no remote data.
Map<String, dynamic> _emptyPull() => {
  'folders': <dynamic>[],
  'teams': <dynamic>[],
  'slots': <dynamic>[],
  'instances': <dynamic>[],
};

String _iso(DateTime dt) => dt.toUtc().toIso8601String();

void main() {
  late MockTeamSyncApi mockApi;
  late _FakeNotifier notifier;

  setUp(() {
    mockApi = MockTeamSyncApi();
    notifier = _FakeNotifier();
    // Default: push batch not called (no pending ops in any test).
    // Default: pull returns empty unless overridden per test.
    when(() => mockApi.pullSince(any())).thenAnswer((_) async => _emptyPull());
  });

  /// Builds a fully wired SyncService backed by [db].
  SyncService makeService(dynamic db) {
    final syncQueue = SyncQueueRepository(db);
    return SyncService(
      syncQueue: syncQueue,
      folderRepo: TeamFolderRepository(db),
      teamRepo: TeamRepository(db),
      slotRepo: TeamSlotRepository(db, syncQueue),
      instanceRepo: PokemonInstanceRepository(db, SyncQueueRepository(db)),
      metaRepo: MetaRepository(db),
      api: mockApi,
      db: db,
      notifier: notifier,
    );
  }

  // ── Folder conflict resolution ──────────────────────────────────────────────

  group('Folder — last-write-wins', () {
    test('remote newer: local folder name is overwritten by remote', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final localTime = DateTime.utc(2024, 1, 1);
      final remoteTime = DateTime.utc(2024, 6, 1); // newer

      // Insert local folder with an older timestamp
      await db.into(db.teamFolders).insert(TeamFoldersCompanion(
        name: const Value('Old Name'),
        remoteId: const Value('1'),
        createdAt: Value(localTime),
        updatedAt: Value(localTime),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': [
          {
            'id': 1,
            'name': 'Remote New Name',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
          }
        ],
        'teams': <dynamic>[],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final repo = TeamFolderRepository(db);
      final folder = (await repo.getAll()).single;
      expect(folder.name, 'Remote New Name');
    });

    test('remote older: local folder name is preserved', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final localTime = DateTime.utc(2024, 6, 1);  // newer
      final remoteTime = DateTime.utc(2024, 1, 1);  // older

      await db.into(db.teamFolders).insert(TeamFoldersCompanion(
        name: const Value('Local Winner'),
        remoteId: const Value('2'),
        createdAt: Value(localTime),
        updatedAt: Value(localTime),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': [
          {
            'id': 2,
            'name': 'Remote Loser',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
          }
        ],
        'teams': <dynamic>[],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final repo = TeamFolderRepository(db);
      final folder = (await repo.getAll()).single;
      expect(folder.name, 'Local Winner');
    });

    test('remote deleted: local folder is hard-deleted', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final now = DateTime.utc(2024, 1, 1);

      await db.into(db.teamFolders).insert(TeamFoldersCompanion(
        name: const Value('About To Vanish'),
        remoteId: const Value('3'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': [
          {
            'id': 3,
            'name': 'About To Vanish',
            'updated_at': _iso(now),
            'is_deleted': true, // server signals deletion
          }
        ],
        'teams': <dynamic>[],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final repo = TeamFolderRepository(db);
      expect(await repo.getAll(), isEmpty);
    });

    test('new remote folder not in local DB is inserted', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final remoteTime = DateTime.utc(2024, 3, 15);

      // DB starts empty — no local folder exists
      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': [
          {
            'id': 99,
            'name': 'Brand New Folder',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
          }
        ],
        'teams': <dynamic>[],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final repo = TeamFolderRepository(db);
      final folders = await repo.getAll();
      expect(folders, hasLength(1));
      expect(folders.single.name, 'Brand New Folder');
      expect(folders.single.remoteId, '99');
    });
  });

  // ── Team conflict resolution ────────────────────────────────────────────────

  group('Team — last-write-wins', () {
    test('remote newer: local team name is overwritten', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final localTime = DateTime.utc(2024, 1, 1);
      final remoteTime = DateTime.utc(2024, 9, 1);

      await db.into(db.teams).insert(TeamsCompanion(
        name: const Value('Local Team Name'),
        remoteId: const Value('1'),
        createdAt: Value(localTime),
        updatedAt: Value(localTime),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': <dynamic>[],
        'teams': [
          {
            'id': 1,
            'name': 'Remote Team Name',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
            'folder_id': null,
          }
        ],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final team = (await TeamRepository(db).getAll()).single;
      expect(team.name, 'Remote Team Name');
    });

    test('remote older: local team name is preserved', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final localTime = DateTime.utc(2024, 9, 1);
      final remoteTime = DateTime.utc(2024, 1, 1);

      await db.into(db.teams).insert(TeamsCompanion(
        name: const Value('Local Wins'),
        remoteId: const Value('2'),
        createdAt: Value(localTime),
        updatedAt: Value(localTime),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': <dynamic>[],
        'teams': [
          {
            'id': 2,
            'name': 'Remote Loses',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
            'folder_id': null,
          }
        ],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final team = (await TeamRepository(db).getAll()).single;
      expect(team.name, 'Local Wins');
    });

    test('remote deleted: local team and its slots are hard-deleted', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final now = DateTime.utc(2024, 1, 1);
      final syncQueue = SyncQueueRepository(db);

      // Insert team
      final teamId = await db.into(db.teams).insert(TeamsCompanion(
        name: const Value('Doomed Team'),
        remoteId: const Value('3'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      // Insert a slot for that team
      await db.into(db.teamSlots).insert(TeamSlotsCompanion(
        teamId: Value(teamId),
        slot: const Value(1),
        pokemonId: const Value(25),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': <dynamic>[],
        'teams': [
          {
            'id': 3,
            'name': 'Doomed Team',
            'updated_at': _iso(now),
            'is_deleted': true,
            'folder_id': null,
          }
        ],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final teamRepo = TeamRepository(db);
      final slotRepo = TeamSlotRepository(db, syncQueue);

      expect(await teamRepo.getAll(), isEmpty);
      expect(await slotRepo.getByTeam(teamId), isEmpty);
    });

    test('new remote team is inserted locally', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final remoteTime = DateTime.utc(2024, 5, 10);

      when(() => mockApi.pullSince(any())).thenAnswer((_) async => {
        'folders': <dynamic>[],
        'teams': [
          {
            'id': 77,
            'name': 'Pulled From Server',
            'updated_at': _iso(remoteTime),
            'is_deleted': false,
            'folder_id': null,
          }
        ],
        'slots': <dynamic>[],
        'instances': <dynamic>[],
      });

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final teams = await TeamRepository(db).getAll();
      expect(teams, hasLength(1));
      expect(teams.single.name, 'Pulled From Server');
      expect(teams.single.remoteId, '77');
    });
  });

  // ── Service-level behaviour ─────────────────────────────────────────────────

  group('SyncService — state notifications', () {
    test('setSuccess called when sync completes with no errors', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      expect(notifier.calls, ['syncing', 'success']);
    });

    test('last_pull_at is persisted after a successful pull', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final svc = makeService(db);
      await svc.run(token: 'test-token');

      final stored = await MetaRepository(db).get('last_pull_at');
      expect(stored, isNotNull);
      // Should be a valid ISO-8601 date string
      expect(() => DateTime.parse(stored!), returnsNormally);
    });
  });
}
