import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import '../providers/attendance_providers.dart';
import '../../data/models/attendance_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

class AttendanceDashboardView extends ConsumerStatefulWidget {
  final void Function(int tabIndex, {String? statusFilter, bool? pendingOnly})? onNavigateToTab;
  final void Function({
    String? status,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? classId,
    String? sectionId,
  })? onNavigateToRegister;

  final void Function({
    String? classId,
    String? sectionId,
    DateTime? date,
    String? academicYearId,
  })? onNavigateToMark;

  const AttendanceDashboardView({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToRegister,
    this.onNavigateToMark,
  });

  @override
  ConsumerState<AttendanceDashboardView> createState() => _AttendanceDashboardViewState();
}

class _AttendanceDashboardViewState extends ConsumerState<AttendanceDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
    });
  }

  Future<void> _pickDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(attendanceDashboardProvider.notifier).fetchDashboard(date: picked);
    }
  }

  void _navigateToRegister({
    String? status,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? classId,
    String? sectionId,
  }) {
    final targetStart = startDate ?? date;
    final targetEnd = endDate ?? date;

    if (widget.onNavigateToRegister != null) {
      widget.onNavigateToRegister!(
        status: status,
        date: date,
        startDate: targetStart,
        endDate: targetEnd,
        classId: classId,
        sectionId: sectionId,
      );
      return;
    }

    if (widget.onNavigateToTab != null) {
      ref.read(attendanceRegisterProvider.notifier).setFilters(
        classId: classId,
        sectionId: sectionId,
        startDate: targetStart,
        endDate: targetEnd,
        status: status,
      );
      widget.onNavigateToTab!(2, statusFilter: status);
      return;
    }

    ref.read(attendanceRegisterProvider.notifier).setFilters(
      classId: classId,
      sectionId: sectionId,
      startDate: targetStart,
      endDate: targetEnd,
      status: status,
    );

    final q = <String, String>{};
    if (status != null) q['status'] = status;
    if (targetStart != null) q['start_date'] = DateFormat('yyyy-MM-dd').format(targetStart);
    if (targetEnd != null) q['end_date'] = DateFormat('yyyy-MM-dd').format(targetEnd);
    if (classId != null) q['class_id'] = classId;
    if (sectionId != null) q['section_id'] = sectionId;

    final uri = Uri(path: AppRoutes.attendanceRegister, queryParameters: q.isEmpty ? null : q);
    try {
      GoRouter.of(context).go(uri.toString());
    } catch (_) {}
  }

  void _navigateToMark({
    String? classId,
    String? sectionId,
    DateTime? date,
    String? academicYearId,
  }) {
    if (widget.onNavigateToMark != null) {
      widget.onNavigateToMark!(
        classId: classId,
        sectionId: sectionId,
        date: date,
        academicYearId: academicYearId,
      );
      return;
    }

    if (widget.onNavigateToTab != null) {
      ref.read(dailyAttendanceMarkProvider.notifier).setSelection(
        classId: classId,
        sectionId: sectionId,
        attendanceDate: date,
        academicYearId: academicYearId,
      );
      widget.onNavigateToTab!(1);
      return;
    }

    ref.read(dailyAttendanceMarkProvider.notifier).setSelection(
      classId: classId,
      sectionId: sectionId,
      attendanceDate: date,
      academicYearId: academicYearId,
    );

    final q = <String, String>{};
    if (classId != null) q['class_id'] = classId;
    if (sectionId != null) q['section_id'] = sectionId;
    if (date != null) q['date'] = DateFormat('yyyy-MM-dd').format(date);
    if (academicYearId != null) q['ay_id'] = academicYearId;

    final uri = Uri(path: AppRoutes.attendanceMark, queryParameters: q.isEmpty ? null : q);
    try {
      GoRouter.of(context).go(uri.toString());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final dashState = ref.watch(attendanceDashboardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (dashState.isLoading && dashState.stats == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (dashState.error != null && dashState.stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading dashboard: ${dashState.error}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => ref.read(attendanceDashboardProvider.notifier).fetchDashboard(),
              ),
            ],
          ),
        ),
      );
    }

    final stats = dashState.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date selector & summary header
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Attendance Overview',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time campus-wide attendance monitoring & streak analytics',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      DateFormat('EEE, MMM d, yyyy').format(dashState.selectedDate),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _pickDate(dashState.selectedDate),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Analytics',
                    onPressed: () => ref.read(attendanceDashboardProvider.notifier).fetchDashboard(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Alert Banner (if any)
          if (dashState.alerts.isNotEmpty) ...[
            _buildAlertsSection(context, dashState.alerts, dashState.selectedDate, stats),
            const SizedBox(height: 24),
          ],

          // 3. KPI Cards
          if (stats != null) ...[
            _buildKpiCards(context, stats, dashState.selectedDate),
            const SizedBox(height: 24),

            // 4. 7-Day Trend Visualizer
            if (stats.dailyTrend.isNotEmpty) ...[
              _buildTrendSection(context, stats.dailyTrend),
              const SizedBox(height: 24),
            ],

            // 5. Responsive 2-column layout: Class breakdown & Low attendance students
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildClassBreakdownCard(context, stats.classWiseStats, dashState.selectedDate),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: _buildLowAttendanceCard(context, stats.lowAttendanceStudents),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildClassBreakdownCard(context, stats.classWiseStats, dashState.selectedDate),
                      const SizedBox(height: 20),
                      _buildLowAttendanceCard(context, stats.lowAttendanceStudents),
                    ],
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsSection(
    BuildContext context,
    List<dynamic> alerts,
    DateTime selectedDate,
    AttendanceDashboardStatsDto? stats,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Attendance Alerts (${alerts.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((alert) {
            final isStreak = alert.alertType == 'CONSECUTIVE_ABSENCE';
            final key = isStreak ? const Key('alert_consecutive_absence') : const Key('alert_unmarked_classes');
            final semanticLabel = isStreak ? 'View consecutive absence records' : 'View pending attendance classes';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Semantics(
                label: semanticLabel,
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: key,
                    onTap: isStreak
                        ? () => _navigateToRegister(status: 'ABSENT', date: selectedDate)
                        : (stats != null ? () => _showPendingClassesDialog(context, selectedDate, stats) : null),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isStreak ? Colors.red.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isStreak ? 'STREAK ABSENCE' : 'UNMARKED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isStreak ? Colors.red[700] : Colors.orange[800],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alert.message,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isStreak ? 'View in Register' : 'Review Pending',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isStreak ? Colors.red[700] : Colors.orange[800],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: isStreak ? Colors.red[700] : Colors.orange[800],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, AttendanceDashboardStatsDto stats, DateTime selectedDate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget card({
      required Key key,
      required String semanticLabel,
      required String title,
      required String val,
      required IconData icon,
      required Color color,
      String? subtitle,
      required VoidCallback onTap,
      required String actionLabel,
      String? tooltip,
    }) {
      final content = Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              val,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    actionLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 12, color: color),
              ],
            ),
          ],
        ),
      );

      return Semantics(
        label: semanticLabel,
        button: true,
        child: Tooltip(
          message: tooltip ?? actionLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: color.withValues(alpha: 0.08),
              child: content,
            ),
          ),
        ),
      );
    }

    final rateColor = stats.attendancePercentage >= 85.0
        ? Colors.green
        : (stats.attendancePercentage >= 75.0 ? Colors.orange : Colors.red);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        card(
          key: const Key('kpi_card_attendance_rate'),
          semanticLabel: 'View attendance rate register',
          title: 'Attendance Rate',
          val: '${stats.attendancePercentage.toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: rateColor,
          subtitle: 'Monthly: ${stats.monthlyPercentage.toStringAsFixed(1)}%',
          actionLabel: 'View Register',
          tooltip: 'Click to open monthly Attendance Register',
          onTap: () {
            final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
            final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
            _navigateToRegister(
              startDate: startOfMonth,
              endDate: endOfMonth,
            );
          },
        ),
        card(
          key: const Key('kpi_card_present_students'),
          semanticLabel: 'View present students',
          title: 'Present Students',
          val: '${stats.presentCount} / ${stats.totalStudents}',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          subtitle: 'Enrolled & active',
          actionLabel: 'View Register',
          tooltip: 'Filter register by Present students',
          onTap: () => _navigateToRegister(
            status: 'PRESENT',
            date: selectedDate,
          ),
        ),
        card(
          key: const Key('kpi_card_absent'),
          semanticLabel: 'View absent students',
          title: 'Absent',
          val: '${stats.absentCount}',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          subtitle: 'Unexcused / Illness',
          actionLabel: 'View Register',
          tooltip: 'Filter register by Absent students',
          onTap: () => _navigateToRegister(
            status: 'ABSENT',
            date: selectedDate,
          ),
        ),
        card(
          key: const Key('kpi_card_late_arrivals'),
          semanticLabel: 'View late arrivals',
          title: 'Late Arrivals',
          val: '${stats.lateCount}',
          icon: Icons.schedule,
          color: Colors.orange,
          subtitle: 'Arrived after cutoff',
          actionLabel: 'View Register',
          tooltip: 'Filter register by Late arrivals',
          onTap: () => _navigateToRegister(
            status: 'LATE',
            date: selectedDate,
          ),
        ),
        card(
          key: const Key('kpi_card_excused_leave'),
          semanticLabel: 'View students on leave',
          title: 'Excused / Leave',
          val: '${stats.excusedCount + stats.halfDayCount}',
          icon: Icons.event_available,
          color: Colors.purple,
          subtitle: 'Approved leaves',
          actionLabel: 'View Register',
          tooltip: 'Filter register by Leave records',
          onTap: () => _navigateToRegister(
            status: 'EXCUSED',
            date: selectedDate,
          ),
        ),
        card(
          key: const Key('kpi_card_classes_marked'),
          semanticLabel: 'View class attendance status',
          title: 'Classes Marked',
          val: '${stats.classesMarked} / ${stats.classesMarked + stats.classesPending}',
          icon: Icons.fact_check_outlined,
          color: stats.classesPending == 0 ? Colors.green : Colors.amber,
          subtitle: '${stats.classesPending} pending today',
          actionLabel: 'View Status',
          tooltip: 'Click to open Class Attendance Status',
          onTap: () => _showClassAttendanceStatusDialog(context, selectedDate, stats),
        ),
      ],
    );
  }

  Widget _buildTrendSection(BuildContext context, List<Map<String, dynamic>> dailyTrend) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '7-Day Attendance Trend',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: dailyTrend.map((day) {
                      final dateRaw = day['date'] as String? ?? '';
                      DateTime? dt;
                      try {
                        dt = DateTime.parse(dateRaw);
                      } catch (_) {}
                      final dayLabel = dt != null ? DateFormat('E, MMM d').format(dt) : dateRaw;
                      final pct = (day['percentage'] as num?)?.toDouble() ?? 0.0;
                      final total = day['total'] as int? ?? 0;
                      final present = day['present'] as int? ?? 0;

                      final barColor = pct >= 85
                          ? Colors.green
                          : (pct >= 75 ? Colors.orange : Colors.red);

                      return Semantics(
                        label: 'View attendance for $dayLabel',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: Key('trend_day_$dateRaw'),
                            onTap: dt != null
                                ? () => _navigateToRegister(date: dt)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Tooltip(
                              message: dt != null
                                  ? 'Click to inspect register for ${DateFormat('yMMMd').format(dt)}'
                                  : '$dayLabel: ${pct.toStringAsFixed(1)}%',
                              child: Container(
                                width: 135,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dayLabel,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${pct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: barColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: total > 0 ? (present / total) : 0,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$present / $total present',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'View Register →',
                                      style: TextStyle(fontSize: 10, color: barColor, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassBreakdownCard(
    BuildContext context,
    List<Map<String, dynamic>> classStats,
    DateTime selectedDate,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final schoolId = ref.watch(selectedSchoolIdProvider);
    final sectionsState = schoolId != null ? ref.watch(sectionsProvider(schoolId)) : null;
    final sections = sectionsState?.sections ?? <SectionDto>[];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Class-wise Attendance',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (classStats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No attendance records marked today.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 600;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: classStats.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = classStats[index];
                      final clsId = item['class_id'] as String? ?? '';
                      final className = item['class_name'] as String? ?? 'Class';
                      final sectionName = item['section_name'] as String? ?? '';
                      final total = item['total'] as int? ?? 0;
                      final present = item['present'] as int? ?? 0;
                      final pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;
                      final isMarked = item['is_marked'] == true;

                      String? sectionId = item['section_id'] as String?;
                      if (sectionId == null && sectionName.isNotEmpty && sections.isNotEmpty) {
                        try {
                          sectionId = sections.firstWhere((s) => s.classId == clsId && s.name.toLowerCase() == sectionName.toLowerCase()).id;
                        } catch (_) {}
                      }

                      final color = isMarked
                          ? (pct >= 85 ? Colors.green : (pct >= 75 ? Colors.orange : Colors.red))
                          : Colors.orange;

                      if (isCompact) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sectionName.isNotEmpty ? '$className - $sectionName' : className,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isMarked ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isMarked ? 'MARKED' : 'PENDING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMarked ? Colors.green[700] : Colors.orange[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? present / total : 0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    '$present / $total present (${pct.toStringAsFixed(1)}%)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                  if (isMarked)
                                    OutlinedButton.icon(
                                      key: Key('class_register_btn_$clsId'),
                                      icon: const Icon(Icons.arrow_forward, size: 14),
                                      label: const Text('View Register →', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _navigateToRegister(
                                        classId: clsId,
                                        sectionId: sectionId,
                                        date: selectedDate,
                                      ),
                                    )
                                  else
                                    FilledButton.icon(
                                      key: Key('class_mark_btn_$clsId'),
                                      icon: const Icon(Icons.how_to_reg, size: 14),
                                      label: const Text('Mark Attendance →', style: TextStyle(fontSize: 11)),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _navigateToMark(
                                        classId: clsId,
                                        sectionId: sectionId,
                                        date: selectedDate,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sectionName.isNotEmpty ? '$className - $sectionName' : className,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isMarked ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isMarked ? 'MARKED' : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isMarked ? Colors.green[700] : Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: total > 0 ? present / total : 0,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$present / $total present (${pct.toStringAsFixed(1)}%)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isMarked)
                              OutlinedButton.icon(
                                key: Key('class_register_btn_$clsId'),
                                icon: const Icon(Icons.arrow_forward, size: 14),
                                label: const Text('View Register →', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _navigateToRegister(
                                  classId: clsId,
                                  sectionId: sectionId,
                                  date: selectedDate,
                                ),
                              )
                            else
                              FilledButton.icon(
                                key: Key('class_mark_btn_$clsId'),
                                icon: const Icon(Icons.how_to_reg, size: 14),
                                label: const Text('Mark Attendance →', style: TextStyle(fontSize: 11)),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _navigateToMark(
                                  classId: clsId,
                                  sectionId: sectionId,
                                  date: selectedDate,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showClassAttendanceStatusDialog(
    BuildContext context,
    DateTime selectedDate,
    AttendanceDashboardStatsDto stats,
  ) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    final sectionsState = schoolId != null ? ref.read(sectionsProvider(schoolId)) : null;
    final sections = sectionsState?.sections ?? <SectionDto>[];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          key: const Key('class_attendance_status_dialog'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Class Attendance Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('EEE, MMM d, yyyy').format(selectedDate)}  •  ${stats.classesMarked} Marked  •  ${stats.classesPending} Pending',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: stats.classWiseStats.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No class records available.')),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        ...stats.classWiseStats.map((item) {
                          final clsId = item['class_id'] as String? ?? '';
                          final className = item['class_name'] as String? ?? 'Class';
                          final sectionName = item['section_name'] as String? ?? '';
                          final isMarked = item['is_marked'] == true;
                          final total = item['total'] as int? ?? 0;
                          final present = item['present'] as int? ?? 0;

                          String? sectionId = item['section_id'] as String?;
                          if (sectionId == null && sectionName.isNotEmpty && sections.isNotEmpty) {
                            try {
                              sectionId = sections.firstWhere((s) => s.classId == clsId && s.name.toLowerCase() == sectionName.toLowerCase()).id;
                            } catch (_) {}
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sectionName.isNotEmpty ? '$className - $sectionName' : className,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$present / $total present',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isMarked
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isMarked
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.orange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    isMarked ? '✓ Marked' : '⚠ Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMarked ? Colors.green[700] : Colors.orange[800],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isMarked)
                                  OutlinedButton(
                                    key: Key('dialog_register_btn_$clsId'),
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _navigateToRegister(
                                        classId: clsId,
                                        sectionId: sectionId,
                                        date: selectedDate,
                                      );
                                    },
                                    child: const Text('View Register →', style: TextStyle(fontSize: 12)),
                                  )
                                else
                                  FilledButton(
                                    key: Key('dialog_mark_btn_$clsId'),
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _navigateToMark(
                                        classId: clsId,
                                        sectionId: sectionId,
                                        date: selectedDate,
                                      );
                                    },
                                    child: const Text('Mark Attendance →', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPendingClassesDialog(
    BuildContext context,
    DateTime selectedDate,
    AttendanceDashboardStatsDto stats,
  ) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    final sectionsState = schoolId != null ? ref.read(sectionsProvider(schoolId)) : null;
    final sections = sectionsState?.sections ?? <SectionDto>[];

    final pendingClasses = stats.classWiseStats.where((c) => c['is_marked'] != true).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          key: const Key('pending_classes_dialog'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Attendance Classes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Unmarked classes for ${DateFormat('EEE, MMM d, yyyy').format(selectedDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: pendingClasses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'All classes have recorded attendance for today!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        ...pendingClasses.map((item) {
                          final clsId = item['class_id'] as String? ?? '';
                          final className = item['class_name'] as String? ?? 'Class';
                          final sectionName = item['section_name'] as String? ?? '';
                          final total = item['total'] as int? ?? 0;

                          String? sectionId = item['section_id'] as String?;
                          if (sectionId == null && sectionName.isNotEmpty && sections.isNotEmpty) {
                            try {
                              sectionId = sections.firstWhere((s) => s.classId == clsId && s.name.toLowerCase() == sectionName.toLowerCase()).id;
                            } catch (_) {}
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sectionName.isNotEmpty ? '$className - $sectionName' : className,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$total enrolled students  •  Attendance pending',
                                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  key: Key('pending_dialog_mark_btn_$clsId'),
                                  icon: const Icon(Icons.how_to_reg, size: 14),
                                  label: const Text('Mark Attendance →', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.of(dialogCtx).pop();
                                    _navigateToMark(
                                      classId: clsId,
                                      sectionId: sectionId,
                                      date: selectedDate,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLowAttendanceCard(BuildContext context, List<Map<String, dynamic>> lowStudents) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_off_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Students Below 75% Attendance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lowStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No students currently below 75% threshold.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lowStudents.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = lowStudents[index];
                  final name = item['student_name'] as String? ?? 'Student';
                  final adm = item['admission_number'] as String? ?? '';
                  final cName = item['class_name'] as String? ?? '';
                  final sName = item['section_name'] as String? ?? '';
                  final attended = item['attended_sessions'] as int? ?? 0;
                  final total = item['total_sessions'] as int? ?? 0;
                  final pct = (item['attendance_percentage'] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Adm: $adm  •  $cName $sName',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$attended / $total days',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
