import 'package:flutter/material.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      colorScheme: ColorScheme.light().copyWith(secondary: Colors.blueAccent),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.black,
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: PokemonTypeColors.colors['dark']!,
        brightness: Brightness.dark,
      ).copyWith(secondary: Colors.blueAccent),
    );
  }
}
