import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/presentation/teams_screen.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

void main() {
  group('TeamsScreen', () {
    testWidgets('shows "My Teams" title with empty state', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.text('My Teams'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows FAB to create a team', (tester) async {
      final db = openTestDatabase();

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows folder name when a folder exists in the database', (tester) async {
      final db = openTestDatabase();

      await db.into(db.teamFolders).insert(
        TeamFoldersCompanion(
          name: const Value('Competitive'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.text('Competitive'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows team name when a team exists in the database', (tester) async {
      final db = openTestDatabase();

      await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('Rain Team'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.text('Rain Team'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows multiple teams', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      await db.into(db.teams).insert(
        TeamsCompanion(name: const Value('Team Alpha'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.teams).insert(
        TeamsCompanion(name: const Value('Team Beta'), createdAt: Value(now), updatedAt: Value(now)),
      );

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.text('Team Alpha'), findsOneWidget);
      expect(find.text('Team Beta'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows team under its folder', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      final folderId = await db.into(db.teamFolders).insert(
        TeamFoldersCompanion(
          name: const Value('VGC'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('Trick Room'),
          folderId: Value(folderId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      expect(find.text('VGC'), findsOneWidget);
      expect(find.text('Trick Room'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows offline indicator when not connected', (tester) async {
      final db = openTestDatabase();

      // isOnlineProvider is overridden with Stream.value(false) in pumpTestApp
      await pumpTestApp(tester, const TeamsScreen(), db: db);
      await tester.pumpAndSettle();

      // Offline banner / indicator should be present
      expect(find.byIcon(Icons.cloud_off_outlined), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
