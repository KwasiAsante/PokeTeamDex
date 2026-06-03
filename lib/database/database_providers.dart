import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/database/repositories/favorites_repository.dart';
import 'package:poke_team_dex/database/repositories/pokemon_instance_repository.dart';
import 'package:poke_team_dex/database/repositories/meta_repository.dart';
import 'package:poke_team_dex/database/repositories/sync_queue_repository.dart';
import 'package:poke_team_dex/database/repositories/team_folder_repository.dart';
import 'package:poke_team_dex/database/repositories/team_repository.dart';
import 'package:poke_team_dex/database/repositories/team_slot_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final teamFolderRepositoryProvider = Provider<TeamFolderRepository>((ref) {
  return TeamFolderRepository(ref.read(appDatabaseProvider));
});

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.read(appDatabaseProvider));
});

final teamSlotRepositoryProvider = Provider<TeamSlotRepository>((ref) {
  return TeamSlotRepository(
    ref.read(appDatabaseProvider),
    ref.read(syncQueueRepositoryProvider),
  );
});

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(ref.read(appDatabaseProvider));
});

final metaRepositoryProvider = Provider<MetaRepository>((ref) {
  return MetaRepository(ref.read(appDatabaseProvider));
});

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(ref.read(appDatabaseProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.read(appDatabaseProvider));
});

final pokemonInstanceRepositoryProvider =
    Provider<PokemonInstanceRepository>((ref) {
  return PokemonInstanceRepository(
    ref.read(appDatabaseProvider),
    ref.read(syncQueueRepositoryProvider),
  );
});

final apiBaseUrlProvider = StreamProvider<String>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchApiBaseUrl();
});

final useFormatSpritesProvider = StreamProvider<bool>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchUseFormatSprites();
});

final seedColorProvider = StreamProvider<int>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchSeedColor();
});

final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchThemeMode();
});

final psDirectoryProvider = StreamProvider<String?>((ref) {
  return ref.watch(appConfigRepositoryProvider).watchPsDirectory();
});
