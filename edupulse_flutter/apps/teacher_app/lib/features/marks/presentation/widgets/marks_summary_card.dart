import 'package:flutter/material.dart';

class MarksSummaryCard extends StatelessWidget {
  final int totalStudents;
  final int enteredCount;
  final int missingCount;
  final int presentCount;
  final int absentCount;
  final int malpracticeCount;
  final int exemptedCount;
  final double? averageScore;
  final int maxMarks;

  const MarksSummaryCard({
    super.key,
    required this.totalStudents,
    required this.enteredCount,
    required this.missingCount,
    required this.presentCount,
    required this.absentCount,
    required this.malpracticeCount,
    required this.exemptedCount,
    this.averageScore,
    required this.maxMarks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local Draft Summary',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total', totalStudents.toString(), theme),
                _buildStatItem('Entered', enteredCount.toString(), theme),
                _buildStatItem('Missing', missingCount.toString(), theme, color: missingCount > 0 ? Colors.orange : null),
                _buildStatItem('Present', presentCount.toString(), theme, color: Colors.green),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Absent', absentCount.toString(), theme, color: Colors.red),
                _buildStatItem('Exempt', exemptedCount.toString(), theme, color: Colors.blue),
                _buildStatItem('Malpractice', malpracticeCount.toString(), theme, color: Colors.deepOrange),
                _buildStatItem('Avg Score', averageScore != null ? '${averageScore!.toStringAsFixed(1)}/$maxMarks' : '--', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
