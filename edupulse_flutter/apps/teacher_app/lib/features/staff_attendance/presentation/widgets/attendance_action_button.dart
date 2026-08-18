import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class AttendanceActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? color;

  const AttendanceActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final btnColor = color ?? theme.colorScheme.primary;

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        foregroundColor: theme.colorScheme.onPrimary,
        backgroundColor: btnColor,
        disabledBackgroundColor: btnColor.withOpacity(0.5),
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
        ),
        elevation: 0,
      ),
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
