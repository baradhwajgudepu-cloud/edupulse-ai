import 'package:flutter/material.dart';
import '../../domain/entities/student_mark_entity.dart';

class MarksStatusSelector extends StatelessWidget {
  final ExamResult currentStatus;
  final ValueChanged<ExamResult> onStatusChanged;
  final bool isLocked;

  const MarksStatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    required this.isLocked,
  });

  Color _getStatusColor(ExamResult status, ThemeData theme) {
    switch (status) {
      case ExamResult.PRESENT:
        return Colors.green;
      case ExamResult.ABSENT:
        return Colors.red;
      case ExamResult.MALPRACTICE:
        return Colors.orange;
      case ExamResult.EXEMPTED:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(currentStatus, theme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          currentStatus.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: _getStatusColor(currentStatus, theme),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return PopupMenuButton<ExamResult>(
      initialValue: currentStatus,
      onSelected: onStatusChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(currentStatus, theme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _getStatusColor(currentStatus, theme).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentStatus.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getStatusColor(currentStatus, theme),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
      itemBuilder: (context) => ExamResult.values.map((status) {
        return PopupMenuItem<ExamResult>(
          value: status,
          child: Text(
            status.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _getStatusColor(status, theme),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }
}
