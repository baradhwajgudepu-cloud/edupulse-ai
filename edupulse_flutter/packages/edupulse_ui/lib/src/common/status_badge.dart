import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

enum StatusBadgeVariant {
  success,
  warning,
  error,
  info,
  neutral,
  brand,
}

enum StatusBadgeSize {
  sm,
  md,
}

/// Status badge matching the approved Google AI Studio design.
/// Provides standardized status indicators across the entire ERP platform.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeVariant variant;
  final StatusBadgeSize size;
  final Widget? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.neutral,
    this.size = StatusBadgeSize.md,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case StatusBadgeVariant.success:
        bg = isDark ? const Color(0xFF064E3B).withAlpha(150) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
        border = isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
        break;
      case StatusBadgeVariant.warning:
        bg = isDark ? const Color(0xFF78350F).withAlpha(150) : const Color(0xFFFFFBEB);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
        border = isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
        break;
      case StatusBadgeVariant.error:
        bg = isDark ? const Color(0xFF7F1D1D).withAlpha(150) : const Color(0xFFFFF1F2);
        fg = isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239);
        border = isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3);
        break;
      case StatusBadgeVariant.info:
        bg = isDark ? const Color(0xFF1E3A8A).withAlpha(150) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
        border = isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);
        break;
      case StatusBadgeVariant.brand:
        bg = isDark ? const Color(0xFF134E4A).withAlpha(150) : const Color(0xFFF0FDFA);
        fg = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF115E59);
        border = isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4);
        break;
      case StatusBadgeVariant.neutral:
        bg = isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate100;
        fg = isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700;
        border = isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200;
        break;
    }

    final isSm = size == StatusBadgeSize.sm;
    final padding = isSm
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final fontSize = isSm ? 11.0 : 12.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
