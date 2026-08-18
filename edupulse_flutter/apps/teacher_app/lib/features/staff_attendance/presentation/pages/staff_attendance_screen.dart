import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../providers/staff_attendance_provider.dart';
import '../widgets/geofence_status_banner.dart';
import '../widgets/attendance_action_button.dart';
import '../widgets/staff_attendance_status_card.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffAttendanceStateProvider.notifier).fetchTodayStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final state = ref.watch(staffAttendanceStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(staffAttendanceStateProvider.notifier).fetchTodayStatus(isSilent: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Today's Attendance",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.lg),
                _buildContent(state, theme, spacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(StaffAttendanceState state, ThemeData theme, AppSpacing spacing) {
    switch (state) {
      case StaffAttendanceInitial():
      case StaffAttendanceLoading():
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: CircularProgressIndicator(),
          ),
        );

      case StaffAttendanceError(:final message, :final existingData):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GeofenceStatusBanner(message: message, isError: true),
            SizedBox(height: spacing.lg),
            if (existingData != null) ...[
              StaffAttendanceStatusCard(data: existingData),
              SizedBox(height: spacing.lg),
            ],
            _buildActionArea(state, theme, spacing, existingData),
          ],
        );

      case StaffAttendanceNotCheckedIn():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not Checked In',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.md),
            _buildActionArea(state, theme, spacing, null),
          ],
        );

      case StaffAttendanceCheckingIn(:final existingData):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (existingData != null) ...[
              StaffAttendanceStatusCard(data: existingData),
              SizedBox(height: spacing.lg),
            ] else ...[
              Text(
                'Not Checked In',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.md),
            ],
            _buildActionArea(state, theme, spacing, existingData),
          ],
        );

      case StaffAttendanceCheckedIn(:final data):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaffAttendanceStatusCard(data: data),
            SizedBox(height: spacing.lg),
            _buildActionArea(state, theme, spacing, data),
          ],
        );

      case StaffAttendanceCheckingOut(:final existingData):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaffAttendanceStatusCard(data: existingData),
            SizedBox(height: spacing.lg),
            _buildActionArea(state, theme, spacing, existingData),
          ],
        );

      case StaffAttendanceCheckedOut(:final data):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaffAttendanceStatusCard(data: data),
            SizedBox(height: spacing.lg),
            const Text(
              'Your staff attendance is completed for today. No further actions are available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
    }
  }

  Widget _buildActionArea(
    StaffAttendanceState state,
    ThemeData theme,
    AppSpacing spacing,
    dynamic data,
  ) {
    final isLoading = state is StaffAttendanceCheckingIn || state is StaffAttendanceCheckingOut;
    final isCheckIn = data == null || (data.status != 'CHECKED_IN' && data.status != 'CHECKED_OUT');

    if (state is StaffAttendanceCheckedOut) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCheckIn) ...[
          AttendanceActionButton(
            label: 'Check In',
            icon: Icons.login_rounded,
            isLoading: state is StaffAttendanceCheckingIn,
            onTap: isLoading ? null : () => ref.read(staffAttendanceStateProvider.notifier).checkIn(),
          ),
          SizedBox(height: spacing.sm),
          Text(
            'Your current location will be verified against the school boundary.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          AttendanceActionButton(
            label: 'Check Out',
            icon: Icons.logout_rounded,
            color: Colors.orange,
            isLoading: state is StaffAttendanceCheckingOut,
            onTap: isLoading ? null : () => ref.read(staffAttendanceStateProvider.notifier).checkOut(),
          ),
          SizedBox(height: spacing.sm),
          Text(
            'Your current location will be verified before check-out.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
