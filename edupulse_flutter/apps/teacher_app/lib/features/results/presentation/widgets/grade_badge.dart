import 'package:flutter/material.dart';

class GradeBadge extends StatelessWidget {
  final String grade;

  const GradeBadge({
    super.key,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;

    switch (grade.toUpperCase()) {
      case 'A+':
      case 'A':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'B':
      case 'C':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'D':
      case 'E':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'F':
      default:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        grade,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
