import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_summary.dart';
import '../widgets/attendance_day_card.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecords();
    });
  }

  void _loadRecords({bool isRefresh = false}) {
    final authState = ref.read(authStateProvider);
    if (authState is Authenticated) {
      final schoolId = authState.user.schools.firstOrNull ?? '16730f87-bf8d-44e0-acf9-4b055a778b58';
      
      String studentId = 'a8bc2968-3d0d-431d-ab06-b90f518a0801';
      String academicYearId = '113282c1-9831-4e54-a00e-1746d3c2829d';
      
      final dbState = ref.read(dashboardStateProvider);
      if (dbState is DashboardSuccess) {
        final selected = dbState.data.selectedStudent;
        if (selected != null) {
          studentId = selected.id;
          academicYearId = selected.academicYearId;
        }
      }

      ref.read(attendanceStateProvider.notifier).fetchAttendance(
            studentId: studentId,
            academicYearId: academicYearId,
            schoolId: schoolId,
            isRefresh: isRefresh,
          );
    }
  }

  Future<void> _onRefresh() async {
    _loadRecords(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<AttendanceState>(attendanceStateProvider, (previous, next) {
      if (next is AttendanceSuccess && next.isFromCache) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              local?.translate('offline_cache_warning') ??
                  'Offline: Showing cached data',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final state = ref.watch(attendanceStateProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
        title: Text(local?.translate('attendance') ?? 'Attendance'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(context, state, theme, spacing, radius, local),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AttendanceState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    return switch (state) {
      AttendanceInitial() => const Center(child: CircularProgressIndicator()),
      AttendanceLoading() => const Center(child: CircularProgressIndicator()),
      AttendanceError(:final message) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.lg),
          child: Center(
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    SizedBox(height: spacing.md),
                    Text(
                      local?.translate('attendance_error') ??
                          'Failed to load attendance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => _loadRecords(),
                      icon: const Icon(Icons.refresh),
                      label: Text(local?.translate('retry') ?? 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      AttendanceEmpty() => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: spacing.md),
                Text(
                  local?.translate('no_attendance') ??
                      'No attendance records found',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      AttendanceSuccess(:final records) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttendanceSummary(records: records),
              SizedBox(height: spacing.md),
              AttendanceCalendar(
                records: records,
                onDaySelected: (day) {
                  setState(() {
                    _selectedDay = day;
                  });
                },
              ),
              SizedBox(height: spacing.md),
              _buildDailyDetailsCard(records, spacing, radius, theme),
            ],
          ),
        ),
    };
  }

  Widget _buildDailyDetailsCard(
    List<AttendanceRecordEntity> records,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final targetRecord = records.firstWhere(
      (r) => DateUtils.isSameDay(r.date, _selectedDay),
      orElse: () => AttendanceRecordEntity(
        id: '',
        studentId: '',
        date: _selectedDay,
        status: AttendanceStatus.holiday,
        remarks: 'No attendance marked for this day.',
      ),
    );

    if (targetRecord.id.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.sm),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  'No attendance data marked for this date.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AttendanceDayCard(record: targetRecord);
  }
}
