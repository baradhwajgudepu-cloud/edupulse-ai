import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/teacher_leave_entity.dart';
import 'leave_status_badge.dart';
import 'leave_type_badge.dart';

class LeaveRequestCard extends StatelessWidget {
  final TeacherLeaveEntity leave;
  final VoidCallback onTap;

  const LeaveRequestCard({
    super.key,
    required this.leave,
    required this.onTap,
  });

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final duration = leave.durationDays;
    final dayLabel = duration == 1 ? 'day' : 'days';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      margin: EdgeInsets.only(bottom: spacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.md),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LeaveTypeBadge(leaveType: leave.leaveType),
                  LeaveStatusBadge(status: leave.status),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$duration $dayLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (leave.reason.trim().isNotEmpty) ...[
                SizedBox(height: spacing.sm),
                Text(
                  leave.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
