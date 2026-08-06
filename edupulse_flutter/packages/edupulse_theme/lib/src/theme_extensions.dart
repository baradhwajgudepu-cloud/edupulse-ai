import 'package:flutter/material.dart';

class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  const AppSpacing.standard()
      : xs = 4.0,
        sm = 8.0,
        md = 16.0,
        lg = 24.0,
        xl = 32.0,
        xxl = 48.0;

  @override
  ThemeExtension<AppSpacing> copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  ThemeExtension<AppSpacing> lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: xs + (other.xs - xs) * t,
      sm: sm + (other.sm - sm) * t,
      md: md + (other.md - md) * t,
      lg: lg + (other.lg - lg) * t,
      xl: xl + (other.xl - xl) * t,
      xxl: xxl + (other.xxl - xxl) * t,
    );
  }
}

class AppRadius extends ThemeExtension<AppRadius> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double circular;

  const AppRadius({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.circular,
  });

  const AppRadius.standard()
      : xs = 4.0,
        sm = 8.0,
        md = 12.0,
        lg = 16.0,
        xl = 24.0,
        circular = 9999.0;

  @override
  ThemeExtension<AppRadius> copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? circular,
  }) {
    return AppRadius(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      circular: circular ?? this.circular,
    );
  }

  @override
  ThemeExtension<AppRadius> lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) return this;
    return AppRadius(
      xs: xs + (other.xs - xs) * t,
      sm: sm + (other.sm - sm) * t,
      md: md + (other.md - md) * t,
      lg: lg + (other.lg - lg) * t,
      xl: xl + (other.xl - xl) * t,
      circular: circular + (other.circular - circular) * t,
    );
  }
}

class AppGradients extends ThemeExtension<AppGradients> {
  final LinearGradient primary;
  final LinearGradient accent;

  const AppGradients({
    required this.primary,
    required this.accent,
  });

  const AppGradients.standard()
      : primary = const LinearGradient(
          colors: [Color(0xFF0A66C2), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accent = const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  @override
  ThemeExtension<AppGradients> copyWith({
    LinearGradient? primary,
    LinearGradient? accent,
  }) {
    return AppGradients(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
    );
  }

  @override
  ThemeExtension<AppGradients> lerp(
      ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      primary: LinearGradient.lerp(primary, other.primary, t) ?? primary,
      accent: LinearGradient.lerp(accent, other.accent, t) ?? accent,
    );
  }
}

class AppElevation extends ThemeExtension<AppElevation> {
  final double none;
  final double low;
  final double medium;
  final double high;

  const AppElevation({
    required this.none,
    required this.low,
    required this.medium,
    required this.high,
  });

  const AppElevation.standard()
      : none = 0.0,
        low = 2.0,
        medium = 6.0,
        high = 12.0;

  @override
  ThemeExtension<AppElevation> copyWith({
    double? none,
    double? low,
    double? medium,
    double? high,
  }) {
    return AppElevation(
      none: none ?? this.none,
      low: low ?? this.low,
      medium: medium ?? this.medium,
      high: high ?? this.high,
    );
  }

  @override
  ThemeExtension<AppElevation> lerp(
      ThemeExtension<AppElevation>? other, double t) {
    if (other is! AppElevation) return this;
    return AppElevation(
      none: none + (other.none - none) * t,
      low: low + (other.low - low) * t,
      medium: medium + (other.medium - medium) * t,
      high: high + (other.high - high) * t,
    );
  }
}
