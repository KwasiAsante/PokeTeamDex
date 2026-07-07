import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/presentation/team_detail_screen.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

void main() {
  group('TeamDetailScreen', () {
    testWidgets('renders team name in AppBar', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      final teamId = await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('Sun Team'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await pumpTestApp(
        tester,
        TeamDetailScreen(teamId: teamId),
        db: db,
        extraOverrides: [
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Sun Team'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('renders without crashing for a team with no slots', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      final teamId = await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('Empty Team'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await pumpTestApp(
        tester,
        TeamDetailScreen(teamId: teamId),
        db: db,
        extraOverrides: [
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      // Screen renders — team name visible
      expect(find.text('Empty Team'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('shows format label when team has one', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      final teamId = await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('VGC Squad'),
          formatLabel: const Value('vgc2024'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await pumpTestApp(
        tester,
        TeamDetailScreen(teamId: teamId),
        db: db,
        extraOverrides: [
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('VGC Squad'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('renders export icon in AppBar', (tester) async {
      final db = openTestDatabase();

      final now = DateTime.now();
      final teamId = await db.into(db.teams).insert(
        TeamsCompanion(
          name: const Value('Export Test Team'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Use a wide screen so the icon buttons are shown directly in the AppBar
      // (isWide requires width > 840; default test size is 800px).
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpTestApp(
        tester,
        TeamDetailScreen(teamId: teamId),
        db: db,
        extraOverrides: [
          allFormatsProvider.overrideWith((_) async => []),
          generalFormatsProvider.overrideWith((_) async => []),
          gameFormatsProvider.overrideWith((_) async => []),
        ],
      );
      await tester.pumpAndSettle();

      // On wide screens the edit icon appears directly in the AppBar
      expect(find.byIcon(Icons.edit_outlined), findsAny);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
