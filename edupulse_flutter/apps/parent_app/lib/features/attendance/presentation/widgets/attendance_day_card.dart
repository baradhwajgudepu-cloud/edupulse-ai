import 'package:flutter/material.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceDayCard extends StatelessWidget {
  final AttendanceRecordEntity record;

  const AttendanceDayCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dateStr = DateFormat('EEEE, MMMM d').format(record.date);

    final (statusLabel, statusColor) = switch (record.status) {
      AttendanceStatus.present => (
          local?.translate('present') ?? 'Present',
          Colors.green
        ),
      AttendanceStatus.absent => (
          local?.translate('absent') ?? 'Absent',
          Colors.red
        ),
      AttendanceStatus.leave => (
          local?.translate('leave') ?? 'Leave',
          Colors.orange
        ),
      AttendanceStatus.late => (
          local?.translate('late') ?? 'Late',
          Colors.amber
        ),
      AttendanceStatus.halfDay => ('Half Day', Colors.deepOrange),
      AttendanceStatus.holiday => (
          local?.translate('holiday') ?? 'Holiday',
          Colors.grey
        ),
      AttendanceStatus.online => ('Online', Colors.blue),
    };

    return Card(
      margin: EdgeInsets.only(bottom: spacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xs,
        ),
        title: Text(
          dateStr,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: record.remarks.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(top: spacing.xs),
                child: Text(
                  record.remarks,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : null,
        trailing: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(radius.xs),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            statusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
