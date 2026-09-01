import 'package:flutter/material.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceSummary extends StatelessWidget {
  final List<AttendanceRecordEntity> records;

  const AttendanceSummary({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final total = records.length;
    final present = records
        .where((r) =>
            r.status == AttendanceStatus.present ||
            r.status == AttendanceStatus.online)
        .length;
    final absent =
        records.where((r) => r.status == AttendanceStatus.absent).length;
    final leave = records
        .where((r) =>
            r.status == AttendanceStatus.leave ||
            r.status == AttendanceStatus.late ||
            r.status == AttendanceStatus.halfDay)
        .length;

    final percentage = total > 0 ? (present / total) * 100 : 100.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 75 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(width: spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    local?.translate('attendance_percentage') ??
                        'Attendance Rate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                        context: context,
                        label: local?.translate('present') ?? 'Present',
                        count: present,
                        color: Colors.green,
                      ),
                      _buildSummaryItem(
                        context: context,
                        label: local?.translate('absent') ?? 'Absent',
                        count: absent,
                        color: Colors.red,
                      ),
                      _buildSummaryItem(
                        context: context,
                        label: local?.translate('leave') ?? 'Leave',
                        count: leave,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
