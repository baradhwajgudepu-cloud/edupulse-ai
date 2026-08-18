import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class LeaveStatusBadge extends StatelessWidget {
  final String status;

  const LeaveStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color bgColor;
    Color textColor;
    String label;

    switch (status.toUpperCase()) {
      case 'PENDING':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        label = 'PENDING';
        break;
      case 'APPROVED':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        label = 'APPROVED';
        break;
      case 'REJECTED':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        label = 'REJECTED';
        break;
      case 'CANCELLED':
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = 'CANCELLED';
        break;
      default:
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
