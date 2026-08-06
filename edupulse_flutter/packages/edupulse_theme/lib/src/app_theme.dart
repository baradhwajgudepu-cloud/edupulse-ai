import 'package:flutter/material.dart';
import 'theme_extensions.dart';

class EduPulseTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0A66C2),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0F2FE),
        onPrimaryContainer: Color(0xFF0369A1),
        secondary: Color(0xFF0369A1),
        onSecondary: Colors.white,
        surface: Color(0xFFF8FAFC),
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardTheme: CardThemeData(
        color: const Color(0xFFF8FAFC),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppSpacing.standard(),
        AppRadius.standard(),
        AppGradients.standard(),
        AppElevation.standard(),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        onPrimary: Colors.black,
        primaryContainer: Color(0xFF1E293B),
        onPrimaryContainer: Color(0xFF93C5FD),
        secondary: Color(0xFF60A5FA),
        onSecondary: Colors.black,
        surface: Color(0xFF1E293B),
        onSurface: Color(0xFFF1F5F9),
        error: Color(0xFFF87171),
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF1F5F9),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppSpacing.standard(),
        AppRadius.standard(),
        AppGradients.standard(),
        AppElevation.standard(),
      ],
    );
  }
}
