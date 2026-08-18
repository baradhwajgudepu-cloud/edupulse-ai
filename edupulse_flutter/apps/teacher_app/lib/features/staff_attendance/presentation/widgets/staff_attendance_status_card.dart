import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/staff_attendance_entity.dart';

class StaffAttendanceStatusCard extends StatelessWidget {
  final StaffAttendanceEntity data;

  const StaffAttendanceStatusCard({
    super.key,
    required this.data,
  });

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parsed = DateTime.parse(timeStr).toLocal();
      return DateFormat('hh:mm a').format(parsed);
    } catch (_) {
      return timeStr;
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1) return 'Inside Boundary';
    return '${meters.toStringAsFixed(1)} m';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final statusText = data.status == 'CHECKED_OUT'
        ? 'Attendance Completed'
        : 'Checked In';
    final statusColor = data.status == 'CHECKED_OUT'
        ? Colors.green
        : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data.isMockedLocation)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(radius.xs),
                    ),
                    child: Text(
                      'MOCKED GPS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: spacing.md),
            const Divider(),
            SizedBox(height: spacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildLogItem(
                    context,
                    label: 'Check-In',
                    time: _formatTime(data.checkInTime),
                    distance: _formatDistance(data.checkInDistanceMeters),
                    icon: Icons.login_rounded,
                    iconColor: Colors.blue,
                  ),
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildLogItem(
                    context,
                    label: 'Check-Out',
                    time: _formatTime(data.checkOutTime),
                    distance: _formatDistance(data.checkOutDistanceMeters),
                    icon: Icons.logout_rounded,
                    iconColor: Colors.orange,
                  ),
                ),
              ],
            ),
            if (data.status == 'CHECKED_OUT') ...[
              SizedBox(height: spacing.md),
              const Divider(),
              SizedBox(height: spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Work Duration:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatDuration(data.durationSeconds),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(
    BuildContext context, {
    required String label,
    required String time,
    required String distance,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              SizedBox(width: spacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            time,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            distance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
