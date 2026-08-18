import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class GeofenceStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const GeofenceStatusBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final bgColor = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    final icon = isError ? Icons.warning_amber_rounded : Icons.info_outline_rounded;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(
          color: isError ? theme.colorScheme.error.withOpacity(0.3) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
