import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class LeaveTypeBadge extends StatelessWidget {
  final String leaveType;

  const LeaveTypeBadge({super.key, required this.leaveType});

  String _formatLabel(String type) {
    switch (type.toUpperCase()) {
      case 'CASUAL':
        return 'Casual Leave';
      case 'SICK':
        return 'Sick Leave';
      case 'EARNED':
        return 'Earned Leave';
      case 'EMERGENCY':
        return 'Emergency Leave';
      case 'OTHER':
        return 'Other';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color bgColor = theme.colorScheme.primaryContainer;
    Color textColor = theme.colorScheme.onPrimaryContainer;

    switch (leaveType.toUpperCase()) {
      case 'SICK':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'CASUAL':
        bgColor = Colors.teal.shade50;
        textColor = Colors.teal.shade700;
        break;
      case 'EMERGENCY':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'EARNED':
        bgColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: Text(
        _formatLabel(leaveType),
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
