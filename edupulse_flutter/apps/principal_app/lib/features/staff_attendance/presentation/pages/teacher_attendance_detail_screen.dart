import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/staff_attendance_model.dart';
import '../providers/staff_attendance_provider.dart';

class TeacherAttendanceDetailScreen extends ConsumerWidget {
  final String teacherId;

  const TeacherAttendanceDetailScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final state = ref.watch(staffAttendanceStateProvider);
    final records = state.summary?.records ?? [];
    
    // Find the teacher record from daily report
    final item = records.firstWhere(
      (r) => r.teacherId == teacherId,
      orElse: () => StaffDailyAttendanceReportItem(
        teacherId: teacherId,
        teacherName: 'Unknown Teacher',
        attendanceStatus: 'ABSENT',
        isMockedLocation: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.teacherName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.designation ?? 'Teacher'} | ${item.department ?? 'Staff'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _buildStatusBadge(context, item.attendanceStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),

            // Compliance Alert if mocked location is true
            if (item.isMockedLocation) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mock location detected during verification.',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
            ],

            // Check-in details
            _buildCheckCard(
              context,
              title: 'Check-In Details',
              time: item.checkInTime,
              latitude: item.checkInLatitude,
              longitude: item.checkInLongitude,
              distance: item.checkInDistanceMeters,
              icon: Icons.login_rounded,
              iconColor: Colors.green,
            ),
            SizedBox(height: spacing.md),

            // Check-out details
            _buildCheckCard(
              context,
              title: 'Check-Out Details',
              time: item.checkOutTime,
              latitude: item.checkOutLatitude,
              longitude: item.checkOutLongitude,
              distance: item.checkOutDistanceMeters,
              icon: Icons.logout_rounded,
              iconColor: Colors.red,
            ),
            SizedBox(height: spacing.lg),

            // View History Button
            ElevatedButton.icon(
              icon: const Icon(Icons.history_rounded),
              label: const Text('View Attendance History'),
              onPressed: () {
                context.push('/teacher-attendance/$teacherId/history');
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color color;
    switch (status) {
      case 'PRESENT':
        color = Colors.green;
        break;
      case 'ABSENT':
        color = Colors.red;
        break;
      case 'LATE':
        color = Colors.amber.shade700;
        break;
      case 'HALF_DAY':
        color = Colors.orange;
        break;
      case 'ON_LEAVE':
        color = Colors.blue;
        break;
      default:
        color = theme.colorScheme.outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCheckCard(
    BuildContext context, {
    required String title,
    required String? time,
    required double? latitude,
    required double? longitude,
    required double? distance,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    final hasData = time != null;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (!hasData)
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                child: Text(
                  'No check-in/out recorded.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else ...[
              _buildDetailRow(
                context,
                label: 'Time',
                value: _formatTime(time),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                label: 'Location coordinates',
                value: latitude != null && longitude != null
                    ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
                    : 'N/A',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                label: 'Distance from school',
                value: distance != null ? '${distance.toStringAsFixed(1)} m' : 'N/A',
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(String isoDateTime) {
    try {
      final dt = DateTime.parse(isoDateTime);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return isoDateTime;
    }
  }
}
