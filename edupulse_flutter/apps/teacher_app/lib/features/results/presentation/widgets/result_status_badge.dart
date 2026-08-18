import 'package:flutter/material.dart';

class ResultStatusBadge extends StatelessWidget {
  final String status;

  const ResultStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PUBLISHED':
      case 'PASS':
      case 'PRESENT':
      case 'PROMOTED':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'UNDER_REVIEW':
      case 'PROMOTION_UNDER_REVIEW':
        backgroundColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
        break;
      case 'APPROVED':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'LOCKED':
        backgroundColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        break;
      case 'DRAFT':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      case 'FAIL':
      case 'DETAINED':
      case 'ABSENT':
      case 'MALPRACTICE':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'EXEMPTED':
      case 'CONDITIONALLY_PROMOTED':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
