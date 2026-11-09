import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF3F7FC),
      primaryColor: const Color(0xFF0077B6),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0077B6),
        secondary: Color(0xFF00B4D8),
        surface: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF06101E),
      primaryColor: const Color(0xFF00B4D8),
      cardColor: const Color(0xFF0D1D31),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00B4D8),
        secondary: Color(0xFF00E5FF),
        surface: Color(0xFF0D1D31),
      ),
    );
  }
}
