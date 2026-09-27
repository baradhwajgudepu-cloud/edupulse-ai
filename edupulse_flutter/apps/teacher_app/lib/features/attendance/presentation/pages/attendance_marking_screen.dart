import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';

import '../../domain/entities/attendance_enums.dart';
import '../providers/attendance_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../my_classes/domain/entities/student.dart';

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final String? timetableId;
  final String dateStr;
  final String? classId;
  final String? sectionId;
  final String? className;
  final String? sectionName;
  final String mode; // 'period' or 'daily'

  const AttendanceMarkingScreen({
    super.key,
    this.timetableId,
    required this.dateStr,
    this.classId,
    this.sectionId,
    this.className,
    this.sectionName,
    this.mode = 'period',
  });

  @override
  ConsumerState<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  final TextEditingController _searchController = TextEditingController();

  String get _resolvedDate {
    if (widget.dateStr.isNotEmpty) return widget.dateStr;
    return DateTime.now().toIso8601String().split('T')[0];
  }

  bool get _isDailyMode =>
      widget.mode == 'daily' ||
      (widget.timetableId == null || widget.timetableId!.isEmpty);

  String get _providerKey {
    if (_isDailyMode) {
      return 'daily:${widget.classId}:${widget.sectionId}:$_resolvedDate';
    } else {
      return 'period:${widget.timetableId}:$_resolvedDate';
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceStateProvider(_providerKey).notifier).fetchAttendance();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dashboardState = ref.watch(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dashboardData = dashboardState is DashboardSuccess
        ? dashboardState.data
        : (dashboardState as DashboardRefreshing).data;

    final attendanceState = ref.watch(attendanceStateProvider(_providerKey));

    dynamic timetable;
    if (!_isDailyMode) {
      final matching = dashboardData.schedule.where((e) => e.id == widget.timetableId);
      if (matching.isNotEmpty) {
        timetable = matching.first;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDailyMode ? 'Daily Class Attendance' : 'Period Attendance'),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_isDailyMode || timetable == null)
            _buildDailyHeader(attendanceState, theme, spacing, radius)
          else
            _buildTimetableHeader(timetable, theme, spacing, radius),
          Expanded(
            child: _buildStateBody(attendanceState, theme, spacing, radius),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHeader(AttendanceState state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final parsedDate = DateTime.tryParse(_resolvedDate) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(parsedDate);

    String displayName = 'Class Roster';
    if (state is AttendanceSuccess && state.className != null && state.className!.isNotEmpty) {
      displayName = '${state.className} - ${state.sectionName ?? ''}';
    } else if (widget.className != null && widget.className!.isNotEmpty) {
      displayName = '${widget.className} - ${widget.sectionName ?? ''}';
    }

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(radius.sm),
                    ),
                    child: Text(
                      'Daily Attendance (Homeroom)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableHeader(dynamic timetable, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final parsedDate = DateTime.tryParse(_resolvedDate) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(parsedDate);

    Color accentColor = theme.colorScheme.primary;
    if (timetable.displayColor != null && timetable.displayColor.isNotEmpty) {
      try {
        final hex = timetable.displayColor.replaceAll('#', '');
        accentColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${timetable.className} - ${timetable.sectionName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(radius.sm),
                    ),
                    child: Text(
                      timetable.subjectName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    'Period ${timetable.periodNumber} (${timetable.startTime} - ${timetable.endTime})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBody(AttendanceState state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    if (state is AttendanceLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state is AttendanceError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.md),
            ElevatedButton(
              onPressed: () => ref.read(attendanceStateProvider(_providerKey).notifier).fetchAttendance(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (state is AttendanceSuccess) {
      return _buildMarkingView(state, theme, spacing, radius);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMarkingView(AttendanceSuccess state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final isSubmitted = state.session?.status == AttendanceSessionStatus.SUBMITTED;
    final isLocked = state.session?.status == AttendanceSessionStatus.LOCKED;

    final dashboardState = ref.watch(dashboardStateProvider);
    bool isWeekdayMismatch = false;
    String slotDay = '';
    String selectedDay = '';

    if (!_isDailyMode && (dashboardState is DashboardSuccess || dashboardState is DashboardRefreshing)) {
      final data = dashboardState is DashboardSuccess 
          ? dashboardState.data 
          : (dashboardState as DashboardRefreshing).data;
      final matching = data.schedule.where((entry) => entry.id == widget.timetableId);
      if (matching.isNotEmpty) {
        final timetable = matching.first;
        slotDay = timetable.dayOfWeek.toUpperCase();
        final parsedDate = DateTime.tryParse(_resolvedDate);
        if (parsedDate != null) {
          selectedDay = DateFormat('EEEE').format(parsedDate).toUpperCase();
          if (slotDay != selectedDay) {
            isWeekdayMismatch = true;
          }
        }
      }
    }

    return Column(
      children: [
        if (isWeekdayMismatch)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.amber.shade900,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    'Warning: Selected date ($_resolvedDate, $selectedDay) differs from timetable weekday ($slotDay).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Scenario A: Admin recorded full day attendance (blocking banner)
        if (state.scenario == AdminAttendanceScenario.scenarioA)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 20,
                  color: Colors.amber.shade900,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    state.scenarioBannerMessage ??
                        'Full-day attendance has already been recorded by school administration for this date. Further submissions are disabled.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        // Scenario B: Admin recorded full day, but teacher takes period attendance (informative banner)
        else if (state.scenario == AdminAttendanceScenario.scenarioB)
          Container(
            width: double.infinity,
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    state.scenarioBannerMessage ??
                        'Daily attendance recorded by administration. You may still record period-specific attendance for this timetable slot.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        // Scenario C or Submitted/Locked: Attendance already submitted
        else if (isSubmitted || isLocked || state.scenario == AdminAttendanceScenario.scenarioC)
          Container(
            width: double.infinity,
            color: isLocked 
                ? theme.colorScheme.errorContainer.withOpacity(0.3) 
                : theme.colorScheme.secondaryContainer.withOpacity(0.3),
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: isLocked ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    isLocked 
                        ? 'This session is LOCKED. Attendance cannot be modified.'
                        : 'Attendance is SUBMITTED. Modifying records requires a correction reason.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isLocked ? theme.colorScheme.error : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildCounterSummary(state, theme, spacing, radius),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search student...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(attendanceStateProvider(_providerKey).notifier).searchLocal('');
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius.sm),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(attendanceStateProvider(_providerKey).notifier).searchLocal(val);
                  },
                ),
              ),
              if (!isLocked && !isSubmitted) ...[
                SizedBox(width: spacing.sm),
                TextButton.icon(
                  onPressed: () {
                    ref.read(attendanceStateProvider(_providerKey).notifier).markAllPresent();
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('All Present'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: state.filteredStudents.isEmpty
              ? Center(
                  child: Text(
                    state.query.isNotEmpty ? 'No matching students.' : 'No students enrolled.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                  itemCount: state.filteredStudents.length,
                  separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                  itemBuilder: (context, index) {
                    final student = state.filteredStudents[index];
                    final status = state.studentStatuses[student.id] ?? AttendanceStatus.PRESENT;
                    final hasRemarks = state.studentRemarks[student.id]?.isNotEmpty ?? false;

                    return _buildStudentCard(student, status, hasRemarks, isLocked, isSubmitted, theme, spacing, radius);
                  },
                ),
        ),
        if (!isLocked) _buildSubmitBar(state, theme, spacing),
      ],
    );
  }

  Widget _buildCounterSummary(AttendanceSuccess state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final total = state.totalCount;
    final present = state.presentCount;
    final absent = state.absentCount;
    final late = state.lateCount;
    final presentPct = total > 0 ? ((present / total) * 100).round() : 0;

    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Column(
        children: [
          if (total > 0) ...[
            DonutChart(
              title: 'Live Period Attendance Ratio',
              data: [
                DonutSegment(id: 'present', label: 'Present', value: present.toDouble(), color: const Color(0xFF059669)),
                DonutSegment(id: 'absent', label: 'Absent', value: absent.toDouble(), color: const Color(0xFFE11D48)),
                DonutSegment(id: 'late', label: 'Late', value: late.toDouble(), color: const Color(0xFFD97706)),
                if (state.otherCount > 0)
                  DonutSegment(id: 'other', label: 'Other', value: state.otherCount.toDouble(), color: EduPulseTheme.primaryTeal),
              ],
              centerLabel: '$presentPct%',
              centerSublabel: 'Marked Present',
              size: 130,
              thickness: 16,
              showLegend: false,
              unit: '',
            ),
            SizedBox(height: spacing.sm),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCounterItem('Total', state.totalCount.toString(), theme.colorScheme.onSurfaceVariant, theme),
              _buildCounterItem('Present', state.presentCount.toString(), const Color(0xFF059669), theme),
              _buildCounterItem('Absent', state.absentCount.toString(), const Color(0xFFE11D48), theme),
              _buildCounterItem('Late', state.lateCount.toString(), const Color(0xFFD97706), theme),
              if (state.otherCount > 0)
                _buildCounterItem('Other', state.otherCount.toString(), theme.colorScheme.primary, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterItem(String label, String count, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          count,
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

  Widget _buildStudentCard(
    StudentEntity student,
    AttendanceStatus status,
    bool hasRemarks,
    bool isLocked,
    bool isSubmitted,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    Color cardBorderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    if (status == AttendanceStatus.ABSENT) {
      cardBorderColor = const Color(0xFFFDA4AF);
    }

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isLocked
                  ? null
                  : () {
                      if (isSubmitted) {
                        final newStatus = status == AttendanceStatus.PRESENT
                            ? AttendanceStatus.ABSENT
                            : AttendanceStatus.PRESENT;
                        _showCorrectionDialog(student, newStatus);
                      } else {
                        ref.read(attendanceStateProvider(_providerKey).notifier).toggleStatus(student.id);
                      }
                    },
              borderRadius: BorderRadius.circular(radius.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: EduPulseTheme.primaryTeal.withOpacity(0.12),
                    child: Text(
                      '${student.firstName.isNotEmpty ? student.firstName[0] : ''}${student.lastName.isNotEmpty ? student.lastName[0] : ''}'
                          .toUpperCase(),
                      style: const TextStyle(
                        color: EduPulseTheme.primaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : EduPulseTheme.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasRemarks) ...[
                              SizedBox(width: spacing.xs),
                              const Icon(Icons.insert_comment_outlined, size: 12, color: EduPulseTheme.primaryTeal),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Roll No: ${student.rollNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Status badge showing status.name
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
            decoration: BoxDecoration(
              color: status == AttendanceStatus.PRESENT
                  ? Colors.green.shade50
                  : status == AttendanceStatus.ABSENT
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(radius.sm),
            ),
            child: Text(
              status.name,
              style: TextStyle(
                color: status == AttendanceStatus.PRESENT
                    ? Colors.green
                    : status == AttendanceStatus.ABSENT
                        ? Colors.red
                        : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // One-tap status switcher pills (P, A, L) matching Google AI Studio prototype
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusPill(
                label: 'P',
                isSelected: status == AttendanceStatus.PRESENT,
                activeColor: const Color(0xFF059669),
                isLocked: isLocked,
                onTap: () => _handleStatusTap(student, status, AttendanceStatus.PRESENT, isSubmitted, isLocked),
              ),
              const SizedBox(width: 4),
              _buildStatusPill(
                label: 'A',
                isSelected: status == AttendanceStatus.ABSENT,
                activeColor: const Color(0xFFE11D48),
                isLocked: isLocked,
                onTap: () => _handleStatusTap(student, status, AttendanceStatus.ABSENT, isSubmitted, isLocked),
              ),
              const SizedBox(width: 4),
              _buildStatusPill(
                label: 'L',
                isSelected: status == AttendanceStatus.LATE,
                activeColor: const Color(0xFFD97706),
                isLocked: isLocked,
                onTap: () => _handleStatusTap(student, status, AttendanceStatus.LATE, isSubmitted, isLocked),
              ),
              if (!isLocked) ...[
                const SizedBox(width: 2),
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _showMoreOptionsSheet(student, status, isSubmitted, theme, spacing, radius),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _handleStatusTap(
    StudentEntity student,
    AttendanceStatus currentStatus,
    AttendanceStatus targetStatus,
    bool isSubmitted,
    bool isLocked,
  ) {
    if (isLocked) return;
    if (isSubmitted) {
      if (currentStatus != targetStatus) {
        _showCorrectionDialog(student, targetStatus);
      }
    } else {
      ref.read(attendanceStateProvider(_providerKey).notifier).setStatus(student.id, targetStatus);
    }
  }

  Widget _buildSubmitBar(AttendanceSuccess state, ThemeData theme, AppSpacing spacing) {
    final isSaving = state.isSaving;
    final canSubmit = state.canSubmit;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: (isSaving || !canSubmit) ? null : () => _showReviewConfirmation(state),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            disabledBackgroundColor: theme.colorScheme.surfaceVariant,
            disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  !canSubmit
                      ? (state.scenario == AdminAttendanceScenario.scenarioA
                          ? 'SUBMISSION LOCKED BY ADMIN'
                          : 'ATTENDANCE ALREADY SUBMITTED')
                      : 'APPROVE & SUBMIT',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
        ),
      ),
    );
  }

  void _showMoreOptionsSheet(
    StudentEntity student,
    AttendanceStatus currentStatus,
    bool isSubmitted,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final remarksController = TextEditingController(
      text: ref.read(attendanceStateProvider(_providerKey) as ProviderListenable<AttendanceSuccess>).studentRemarks[student.id] ?? '',
    );
    AttendanceStatus selectedStatus = currentStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: spacing.md,
                right: spacing.md,
                top: spacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + spacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    student.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Roll No: ${student.rollNumber} | Admission: ${student.admissionNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    'Select Status',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spacing.sm),
                  Wrap(
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: AttendanceStatus.values.map((status) {
                      final isSelected = selectedStatus == status;
                      return ChoiceChip(
                        label: Text(status.name),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() => selectedStatus = status);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    'Remarks (Optional)',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spacing.xs),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(
                      hintText: 'Enter remarks...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.sm)),
                      contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (isSubmitted) {
                          // Correction flow
                          _showCorrectionDialog(student, selectedStatus, remarks: remarksController.text);
                        } else {
                          // Draft save
                          ref.read(attendanceStateProvider(_providerKey).notifier).setStatus(
                            student.id,
                            selectedStatus,
                            remarks: remarksController.text,
                          );
                        }
                      },
                      child: const Text('Save Details'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCorrectionDialog(StudentEntity student, AttendanceStatus newStatus, {String? remarks}) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Correct Attendance'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changing ${student.fullName}\'s status to ${newStatus.name}.',
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.md),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Correction Reason*',
                    hintText: 'e.g. Marked present by mistake',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Correction reason is required.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final reason = reasonController.text.trim();
                  Navigator.pop(context);
                  ref.read(attendanceStateProvider(_providerKey).notifier).correctStudentAttendance(
                        studentId: student.id,
                        newStatus: newStatus,
                        correctionReason: reason,
                        remarks: remarks,
                      );
                }
              },
              child: const Text('Submit Correction'),
            ),
          ],
        );
      },
    );
  }

  void _showReviewConfirmation(AttendanceSuccess state) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve Attendance?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${state.totalCount} Students'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Present:'),
                  Text(state.presentCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Absent:'),
                  Text(state.absentCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Late:'),
                  Text(state.lateCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Once submitted, changes may require correction depending on permissions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(attendanceStateProvider(_providerKey).notifier).submitAttendance().then((_) {
                  // After successful submission, check state and navigate back
                  final newState = ref.read(attendanceStateProvider(_providerKey));
                  if (newState is! AttendanceError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attendance Submitted successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.pop();
                  }
                });
              },
              child: const Text('Approve & Submit'),
            ),
          ],
        );
      },
    );
  }
}
