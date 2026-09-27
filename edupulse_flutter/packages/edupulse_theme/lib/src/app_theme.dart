import 'package:flutter/material.dart';
import 'theme_extensions.dart';

class EduPulseTheme {
  // Brand color tokens from approved UX design system
  static const Color primaryTeal = Color(0xFF0D9488); // Teal 600
  static const Color primaryTealDark = Color(0xFF0F766E); // Teal 700
  static const Color primaryTealLight = Color(0xFF14B8A6); // Teal 500
  static const Color emeraldSuccess = Color(0xFF059669); // Emerald 600
  static const Color amberWarning = Color(0xFFD97706); // Amber 600
  static const Color roseDanger = Color(0xFFE11D48); // Rose 600
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFCCFBF1), // Teal 100
        onPrimaryContainer: Color(0xFF115E59), // Teal 800
        secondary: primaryTealDark,
        onSecondary: Colors.white,
        surface: slate50,
        onSurface: slate900,
        error: roseDanger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: slate50,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: slate200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: slate900),
        titleTextStyle: TextStyle(
          color: slate900,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerColor: slate200,
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
        primary: primaryTealLight,
        onPrimary: Colors.black,
        primaryContainer: slate800,
        onPrimaryContainer: Color(0xFF99F6E4), // Teal 200
        secondary: primaryTeal,
        onSecondary: Colors.black,
        surface: slate800,
        onSurface: Color(0xFFF1F5F9),
        error: Color(0xFFF87171),
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: slate950,
      cardTheme: CardThemeData(
        color: slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: slate700),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: slate900,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF1F5F9),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerColor: slate700,
      extensions: const <ThemeExtension<dynamic>>[
        AppSpacing.standard(),
        AppRadius.standard(),
        AppGradients.standard(),
        AppElevation.standard(),
      ],
    );
  }
}
