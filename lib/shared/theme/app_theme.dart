import 'package:flutter/material.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';

class AppTheme {
  static const Color _defaultSeed = Color(kDefaultSeedColor);

  static ThemeData light([Color? seed]) {
    final s = seed ?? _defaultSeed;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: s,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: s,
        unselectedItemColor: const Color(0xFF9E9E9E),
        showUnselectedLabels: true,
        elevation: 8,
      ),
    );
  }

  static ThemeData dark([Color? seed]) {
    final s = seed ?? _defaultSeed;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: s,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: s,
        unselectedItemColor: const Color(0xFF757575),
        showUnselectedLabels: true,
        elevation: 8,
      ),
    );
  }
}
