import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

enum EduPulseCardPadding {
  none,
  sm,
  md,
  lg,
}

/// A standard card container matching the Gemini AI Studio design system (`Card.tsx`).
/// Provides white background, 12px border radius, subtle border, and optional interaction states.
class EduPulseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EduPulseCardPadding padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final bool interactive;

  const EduPulseCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EduPulseCardPadding.md,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.interactive = false,
  });

  EdgeInsetsGeometry _getPadding() {
    switch (padding) {
      case EduPulseCardPadding.none:
        return EdgeInsets.zero;
      case EduPulseCardPadding.sm:
        return const EdgeInsets.all(16);
      case EduPulseCardPadding.md:
        return const EdgeInsets.all(20);
      case EduPulseCardPadding.lg:
        return const EdgeInsets.all(24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = backgroundColor ?? (isDark ? EduPulseTheme.slate900 : Colors.white);
    final effectiveBorder = borderColor ?? (isDark ? EduPulseTheme.slate800 : const Color(0xFFE2E8F0));
    final isClickable = interactive || onTap != null;

    final decoration = BoxDecoration(
      color: effectiveBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: effectiveBorder, width: 1.0),
      boxShadow: isDark
          ? const []
          : const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
    );

    if (isClickable) {
      return Container(
        width: width,
        height: height,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            hoverColor: isDark ? const Color(0x1AFFFFFF) : const Color(0x08000000),
            splashColor: EduPulseTheme.primaryTeal.withValues(alpha: 0.1),
            child: Padding(
              padding: _getPadding(),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      padding: _getPadding(),
      decoration: decoration,
      child: child,
    );
  }
}
