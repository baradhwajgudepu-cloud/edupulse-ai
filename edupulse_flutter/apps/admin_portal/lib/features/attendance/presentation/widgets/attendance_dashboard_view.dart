import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceDashboardView extends ConsumerStatefulWidget {
  const AttendanceDashboardView({super.key});

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
            _buildAlertsSection(context, dashState.alerts),
            const SizedBox(height: 24),
          ],

          // 3. KPI Cards
          if (stats != null) ...[
            _buildKpiCards(context, stats),
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
                        child: _buildClassBreakdownCard(context, stats.classWiseStats),
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
                      _buildClassBreakdownCard(context, stats.classWiseStats),
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

  Widget _buildAlertsSection(BuildContext context, List<dynamic> alerts) {
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
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
                        Text(
                          alert.message,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, dynamic stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget card(String title, String val, IconData icon, Color color, {String? subtitle}) {
      return Container(
        width: 175,
        padding: const EdgeInsets.all(16),
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
          ],
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
          'Attendance Rate',
          '${stats.attendancePercentage.toStringAsFixed(1)}%',
          Icons.percent,
          rateColor,
          subtitle: 'Monthly: ${stats.monthlyPercentage.toStringAsFixed(1)}%',
        ),
        card(
          'Present Students',
          '${stats.presentCount} / ${stats.totalStudents}',
          Icons.check_circle_outline,
          Colors.green,
          subtitle: 'Enrolled & active',
        ),
        card(
          'Absent',
          '${stats.absentCount}',
          Icons.cancel_outlined,
          Colors.red,
          subtitle: 'Unexcused / Illness',
        ),
        card(
          'Late Arrivals',
          '${stats.lateCount}',
          Icons.schedule,
          Colors.orange,
        ),
        card(
          'Excused / Leave',
          '${stats.excusedCount + stats.halfDayCount}',
          Icons.event_available,
          Colors.purple,
          subtitle: 'Approved leaves',
        ),
        card(
          'Classes Marked',
          '${stats.classesMarked} / ${stats.classesMarked + stats.classesPending}',
          Icons.fact_check_outlined,
          stats.classesPending == 0 ? Colors.green : Colors.amber,
          subtitle: '${stats.classesPending} pending today',
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

                      return Container(
                        width: 130,
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
                          ],
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

  Widget _buildClassBreakdownCard(BuildContext context, List<Map<String, dynamic>> classStats) {
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
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: classStats.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = classStats[index];
                  final className = item['class_name'] as String? ?? 'Class';
                  final sectionName = item['section_name'] as String? ?? '';
                  final total = item['total'] as int? ?? 0;
                  final present = item['present'] as int? ?? 0;
                  final pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;

                  final color = pct >= 85 ? Colors.green : (pct >= 75 ? Colors.orange : Colors.red);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '$className - $sectionName',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
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
                                '$present / $total present',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
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
