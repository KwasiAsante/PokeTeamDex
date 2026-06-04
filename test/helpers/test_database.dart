import 'package:drift/native.dart';
import 'package:poke_team_dex/database/app_database.dart';

/// Opens a fresh in-memory SQLite database for tests.
/// Each call returns an independent database — close it in tearDown.
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());
