import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_providers.dart';
import '../widgets/attendance_kpi_cards.dart';
import '../widgets/attendance_filters.dart';
import '../widgets/attendance_session_table.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch of sessions and logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceSessionsProvider.notifier).fetchSessions();
      ref.read(attendanceLogsProvider.notifier).fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to view attendance records.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final sessionState = ref.watch(attendanceSessionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Administration',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audit daily attendance, review sessions, correct records, and lock submitted sessions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  key: const Key('refresh_attendance_btn'),
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(attendanceSessionsProvider.notifier).fetchSessions();
                    ref.read(attendanceLogsProvider.notifier).fetchLogs();
                  },
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Cards Section
            const AttendanceKpiCards(),
            const SizedBox(height: 24),

            // Filters Section
            const AttendanceFilters(),
            const SizedBox(height: 24),

            // Content Area
            if (sessionState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (sessionState.error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load attendance sessions: ${sessionState.error}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        key: const Key('retry_load_sessions_btn'),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () {
                          ref.read(attendanceSessionsProvider.notifier).fetchSessions();
                          ref.read(attendanceLogsProvider.notifier).fetchLogs();
                        },
                      ),
                    ],
                  ),
                ),
              )
            else if (sessionState.sessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No attendance sessions match the selected filters.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const Key('reset_filters_empty_state_btn'),
                        onPressed: () => ref.read(attendanceFiltersProvider.notifier).clearAll(),
                        child: const Text('Reset All Filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              AttendanceSessionTable(sessions: sessionState.sessions),
          ],
        ),
      ),
    );
  }
}
