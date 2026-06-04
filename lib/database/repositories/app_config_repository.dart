import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:poke_team_dex/database/app_database.dart';

const _kApiBaseUrl = 'api_base_url';
const _kUseFormatSprites = 'use_format_sprites';
const _kSeedColor = 'seed_color';
const _kThemeMode = 'theme_mode';
const _kPsDirectory = 'ps_directory';
const kDefaultApiBaseUrl = 'https://poketeamdex.duckdns.org';
// Default seed colour — Pokéball red
const kDefaultSeedColor = 0xFFCC0000;

class AppConfigRepository {
  AppConfigRepository(this._db);
  final AppDatabase _db;

  // ── Generic get / set ──────────────────────────────────────────────────────

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appConfigs)
          ..where((c) => c.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      _db.into(_db.appConfigs).insertOnConflictUpdate(
            AppConfigsCompanion(
              key: Value(key),
              value: Value(value),
              updatedAt: Value(DateTime.now()),
            ),
          );

  Stream<String?> watch(String key) => (_db.select(_db.appConfigs)
        ..where((c) => c.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);

  // ── Typed accessors ────────────────────────────────────────────────────────

  Future<String> getApiBaseUrl() async =>
      (await get(_kApiBaseUrl)) ?? kDefaultApiBaseUrl;

  Future<void> setApiBaseUrl(String url) => set(_kApiBaseUrl, url);

  Stream<String> watchApiBaseUrl() =>
      watch(_kApiBaseUrl).map((v) => v ?? kDefaultApiBaseUrl);

  // ── Sprite style ──────────────────────────────────────────────────────────

  /// Whether to use generation-appropriate sprites when a format is assigned.
  /// Defaults to true.
  Future<bool> getUseFormatSprites() async =>
      (await get(_kUseFormatSprites)) != 'false';

  Future<void> setUseFormatSprites(bool value) =>
      set(_kUseFormatSprites, value.toString());

  Stream<bool> watchUseFormatSprites() =>
      watch(_kUseFormatSprites).map((v) => v != 'false');

  // ── Accent / seed colour ──────────────────────────────────────────────────

  Future<int> getSeedColor() async =>
      int.tryParse(await get(_kSeedColor) ?? '') ?? kDefaultSeedColor;

  Future<void> setSeedColor(int colorValue) =>
      set(_kSeedColor, colorValue.toString());

  Stream<int> watchSeedColor() =>
      watch(_kSeedColor).map((v) => int.tryParse(v ?? '') ?? kDefaultSeedColor);

  // ── Theme mode ────────────────────────────────────────────────────────────

  static ThemeMode _parseThemeMode(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark'  => ThemeMode.dark,
        _       => ThemeMode.system,
      };

  Future<ThemeMode> getThemeMode() async =>
      _parseThemeMode(await get(_kThemeMode));

  Future<void> setThemeMode(ThemeMode mode) =>
      set(_kThemeMode, mode.name); // 'system' | 'light' | 'dark'

  Stream<ThemeMode> watchThemeMode() =>
      watch(_kThemeMode).map(_parseThemeMode);

  // ── Pokémon Showdown directory ─────────────────────────────────────────────

  /// Returns the configured PS teams directory path, or null if not set.
  Future<String?> getPsDirectory() async {
    final v = await get(_kPsDirectory);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setPsDirectory(String? path) =>
      set(_kPsDirectory, path ?? '');

  Stream<String?> watchPsDirectory() =>
      watch(_kPsDirectory).map((v) => (v == null || v.isEmpty) ? null : v);
}
