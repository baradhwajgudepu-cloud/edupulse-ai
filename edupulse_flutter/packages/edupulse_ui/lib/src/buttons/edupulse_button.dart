import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

enum EduPulseButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
}

enum EduPulseButtonSize {
  sm,
  md,
  lg,
}

/// A standard button matching the Gemini AI Studio design system (`Button.tsx`).
/// Follows the strict 2x horizontal padding rule and semantic design variants.
class EduPulseButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EduPulseButtonVariant variant;
  final EduPulseButtonSize size;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final bool isLoading;
  final bool disabled;
  final double? width;

  const EduPulseButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EduPulseButtonVariant.primary,
    this.size = EduPulseButtonSize.md,
    this.leftIcon,
    this.rightIcon,
    this.isLoading = false,
    this.disabled = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isEffectiveDisabled = disabled || isLoading || onPressed == null;

    // Size specs:
    // sm: py-1.5 px-3 (6v, 12h), text-xs (12), gap-1.5 (6), min-h 32
    // md: py-2 px-4 (8v, 16h), text-sm (13), gap-2 (8), min-h 40
    // lg: py-2.5 px-5 (10v, 20h), text-base (15), gap-2.5 (10), min-h 44
    final double minHeight;
    final EdgeInsetsGeometry padding;
    final double fontSize;
    final double iconSize;
    final double gap;

    switch (size) {
      case EduPulseButtonSize.sm:
        minHeight = 32.0;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        fontSize = 12.0;
        iconSize = 14.0;
        gap = 6.0;
        break;
      case EduPulseButtonSize.md:
        minHeight = 40.0;
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        fontSize = 13.0;
        iconSize = 16.0;
        gap = 8.0;
        break;
      case EduPulseButtonSize.lg:
        minHeight = 44.0;
        padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
        fontSize = 15.0;
        iconSize = 18.0;
        gap = 10.0;
        break;
    }

    Color bgColor;
    Color fgColor;
    BorderSide borderSide;

    switch (variant) {
      case EduPulseButtonVariant.primary:
        bgColor = isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate900;
        fgColor = Colors.white;
        borderSide = BorderSide(color: bgColor);
        break;
      case EduPulseButtonVariant.secondary:
        bgColor = EduPulseTheme.primaryTealDark; // Teal 700 (#0F766E)
        fgColor = Colors.white;
        borderSide = const BorderSide(color: EduPulseTheme.primaryTealDark);
        break;
      case EduPulseButtonVariant.outline:
        bgColor = isDark ? EduPulseTheme.slate900 : Colors.white;
        fgColor = isDark ? EduPulseTheme.slate200 : EduPulseTheme.slate700;
        borderSide = BorderSide(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate300);
        break;
      case EduPulseButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = isDark ? EduPulseTheme.slate200 : EduPulseTheme.slate700;
        borderSide = BorderSide.none;
        break;
      case EduPulseButtonVariant.danger:
        bgColor = EduPulseTheme.roseDanger; // Rose 600 (#E11D48)
        fgColor = Colors.white;
        borderSide = const BorderSide(color: EduPulseTheme.roseDanger);
        break;
    }

    Widget content = Row(
      mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          SizedBox(width: gap),
        ] else if (leftIcon != null) ...[
          IconTheme(
            data: IconThemeData(size: iconSize, color: fgColor),
            child: leftIcon!,
          ),
          SizedBox(width: gap),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: fgColor,
            letterSpacing: 0.1,
          ),
        ),
        if (!isLoading && rightIcon != null) ...[
          SizedBox(width: gap),
          IconTheme(
            data: IconThemeData(size: iconSize, color: fgColor),
            child: rightIcon!,
          ),
        ],
      ],
    );

    return Opacity(
      opacity: isEffectiveDisabled ? 0.5 : 1.0,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEffectiveDisabled ? null : onPressed,
          hoverColor: Colors.white.withValues(alpha: 0.08),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Container(
            width: width,
            constraints: BoxConstraints(minHeight: minHeight),
            padding: padding,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
