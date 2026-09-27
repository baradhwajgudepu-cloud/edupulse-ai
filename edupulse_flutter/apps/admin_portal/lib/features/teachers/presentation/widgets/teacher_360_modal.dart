import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';
import '../../data/models/teachers_models.dart';
import '../../data/models/teacher_360_models.dart';
import '../providers/teachers_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/auth/portal_permissions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';

/// Full-featured Teacher 360 Folio Modal matching the Gemini AI Studio design language.
/// Provides an 8-tab comprehensive operational view: Overview, Classes & Subjects,
/// Syllabus Progress, Timetable, Attendance, Homework, Examinations, and Workload & Profile.
class Teacher360Modal extends ConsumerStatefulWidget {
  final TeacherDto teacher;
  final String schoolId;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onResetPassword;

  const Teacher360Modal({
    super.key,
    required this.teacher,
    required this.schoolId,
    this.onEdit,
    this.onToggleStatus,
    this.onResetPassword,
  });

  static Future<void> show(
    BuildContext context, {
    required TeacherDto teacher,
    required String schoolId,
    VoidCallback? onEdit,
    VoidCallback? onToggleStatus,
    VoidCallback? onResetPassword,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final screenWidth = media.size.width;
        final screenHeight = media.size.height;
        final isCompact = screenWidth < 768;
        final responsiveInsetPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 32,
          vertical: isCompact ? 12 : 24,
        );
        final maxH = (screenHeight * 0.92).clamp(400.0, 820.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: responsiveInsetPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1100, maxHeight: maxH),
            child: Teacher360Modal(
              teacher: teacher,
              schoolId: schoolId,
              onEdit: onEdit,
              onToggleStatus: onToggleStatus,
              onResetPassword: onResetPassword,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<Teacher360Modal> createState() => _Teacher360ModalState();
}

class _Teacher360ModalState extends ConsumerState<Teacher360Modal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDay = 'MONDAY';

  final List<String> _weekDays = const [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(teacher360AnalyticsProvider(
          Teacher360Key(schoolId: widget.schoolId, teacherId: widget.teacher.id),
        ));
      }
    });
  }

  @override
  void didUpdateWidget(covariant Teacher360Modal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacher.id != widget.teacher.id || oldWidget.schoolId != widget.schoolId) {
      ref.invalidate(teacher360AnalyticsProvider(
        Teacher360Key(schoolId: widget.schoolId, teacherId: widget.teacher.id),
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'ON_LEAVE':
        return Colors.amber.shade700;
      case 'RETIRED':
        return Colors.blueGrey;
      case 'INACTIVE':
      default:
        return Colors.red;
    }
  }

  String _formatINR(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final t = widget.teacher;

    final effectiveSchoolId = widget.schoolId.isNotEmpty
        ? widget.schoolId
        : (ref.watch(selectedSchoolIdProvider) ?? t.schoolId);

    final analyticsAsync = ref.watch(
      teacher360AnalyticsProvider(
        Teacher360Key(schoolId: effectiveSchoolId, teacherId: t.id),
      ),
    );

    final statusColor = _getStatusColor(t.status);
    final initials = (t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '') +
        (t.lastName.isNotEmpty ? t.lastName[0].toUpperCase() : '');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 1. Modal Top Micro-Bar
            Container(
              color: EduPulseTheme.slate950,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EduPulseTheme.primaryTeal.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EduPulseTheme.primaryTeal.withAlpha(100)),
                        ),
                        child: Text(
                          t.employeeCode.isNotEmpty ? t.employeeCode : t.staffCode,
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '• Teacher 360 Folio •',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${t.designation ?? "Faculty"} • ${t.department ?? "General Academics"}',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close Folio',
                  ),
                ],
              ),
            ),

            // 2. Identity Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                            ? NetworkImage(t.photoUrl!)
                            : null,
                        child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                            ? Text(
                                initials.isNotEmpty ? initials : 'TC',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? EduPulseTheme.slate900 : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.fullName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: statusColor.withAlpha(70)),
                              ),
                              child: Text(
                                t.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.officialEmail} • ${t.mobile.isNotEmpty ? t.mobile : "No Phone"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onResetPassword != null && t.status != 'RETIRED') ...[
                    OutlinedButton.icon(
                      onPressed: widget.onResetPassword,
                      icon: const Icon(Icons.lock_reset_outlined, size: 14),
                      label: const Text('Reset Credentials'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onEdit != null && t.status != 'RETIRED') ...[
                    ElevatedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit Staff'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Tab Bar (8 tabs)
            Container(
              color: isDark ? EduPulseTheme.slate900 : Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: EduPulseTheme.primaryTeal,
                labelColor: EduPulseTheme.primaryTeal,
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_outlined, size: 16), text: 'Overview'),
                  Tab(icon: Icon(Icons.class_outlined, size: 16), text: 'Classes & Subjects'),
                  Tab(icon: Icon(Icons.auto_stories_outlined, size: 16), text: 'Syllabus Progress'),
                  Tab(icon: Icon(Icons.schedule_outlined, size: 16), text: 'Timetable'),
                  Tab(icon: Icon(Icons.calendar_today_outlined, size: 16), text: 'Attendance'),
                  Tab(icon: Icon(Icons.assignment_outlined, size: 16), text: 'Homework'),
                  Tab(icon: Icon(Icons.fact_check_outlined, size: 16), text: 'Examinations'),
                  Tab(icon: Icon(Icons.pie_chart_outline, size: 16), text: 'Workload & Profile'),
                ],
              ),
            ),

            // 4. Tab Views
            Expanded(
              child: Container(
                color: isDark ? EduPulseTheme.slate950 : EduPulseTheme.slate50,
                child: analyticsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load Teacher 360 data: $err',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(teacher360AnalyticsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (data) => TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(context, t, isDark, data),
                      _buildClassesSubjectsTab(context, isDark, data),
                      _buildSyllabusTab(context, isDark, data),
                      _buildTimetableTab(context, isDark, data),
                      _buildAttendanceTab(context, isDark, data),
                      _buildHomeworkTab(context, isDark, data),
                      _buildExaminationsTab(context, isDark, data),
                      _buildWorkloadProfileTab(context, t, isDark, data),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: OVERVIEW
  Widget _buildOverviewTab(
    BuildContext context,
    TeacherDto t,
    bool isDark,
    Teacher360Response data,
  ) {
    final overview = data.overview;
    final theme = Theme.of(context);

    Color paceColor;
    switch (overview.syllabusPaceStatus) {
      case 'AHEAD':
        paceColor = Colors.teal;
        break;
      case 'ON_TRACK':
        paceColor = Colors.green;
        break;
      case 'SLIGHTLY_BEHIND':
        paceColor = Colors.amber.shade800;
        break;
      default:
        paceColor = Colors.red;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Metric Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Assigned Classes',
                  value: '${overview.totalClasses}',
                  sublabel: '${overview.totalSections} sections • ${overview.activeStudentsTaught} students',
                  icon: Icons.school_outlined,
                  color: EduPulseTheme.primaryTeal,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Weekly Teaching Load',
                  value: '${overview.weeklyPeriods} / 30',
                  sublabel: '${((overview.weeklyPeriods / 30.0) * 100).toStringAsFixed(1)}% Capacity',
                  icon: Icons.timer_outlined,
                  color: Colors.blue,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Syllabus Pace',
                  value: '${overview.syllabusCompletionRate}%',
                  sublabel: 'Status: ${overview.syllabusPaceStatus.replaceAll('_', ' ')}',
                  icon: Icons.auto_stories_outlined,
                  color: paceColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Exam Marks Compliance',
                  value: '${overview.marksSubmissionRate}%',
                  sublabel: 'Quarterly & Unit Tests',
                  icon: Icons.fact_check_outlined,
                  color: overview.marksSubmissionRate >= 90 ? Colors.green : Colors.orange,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Overview Details Row: Primary Subjects & Class Teacher
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Subjects
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 16, color: EduPulseTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Text(
                            'Primary Subjects Taught',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (overview.primarySubjects.isEmpty)
                        Text(
                          'No subjects assigned yet.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: overview.primarySubjects.map((sub) {
                            return Chip(
                              label: Text(sub, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Class Teacher Responsibilities
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_outline, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Class Teacher Responsibility',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (overview.classTeacherOf.isEmpty)
                        Text(
                          'Not designated as Class Teacher for any section.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: overview.classTeacherOf.map((role) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.supervisor_account, size: 14, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Next Timetable Schedule Quick View
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? EduPulseTheme.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.today_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Schedule Summary',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      'Total Slots: ${data.timetable.length}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.timetable.isEmpty)
                  Text(
                    'No timetable periods configured yet.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekDays.map((day) {
                      final dayPeriods = data.timetable.where((tt) => tt.dayOfWeek.toUpperCase() == day).length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day.substring(0, 3),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dayPeriods periods',
                              style: TextStyle(
                                fontSize: 11,
                                color: dayPeriods > 0 ? EduPulseTheme.primaryTeal : Colors.grey,
                                fontWeight: dayPeriods > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: CLASSES & SUBJECTS
  Widget _buildClassesSubjectsTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final theme = Theme.of(context);
    final assignments = data.assignments;

    if (assignments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.class_outlined,
        title: 'No Class Assignments Found',
        message: 'No active teaching subject assignments are recorded for this teacher.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = assignments[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: EduPulseTheme.primaryTeal.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EduPulseTheme.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${a.className} • ${a.sectionName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (a.isClassTeacher) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withAlpha(80)),
                            ),
                            child: const Text(
                              'Class Teacher',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${a.subjectName} ${a.subjectCode != null ? "(${a.subjectCode})" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Enrolled Students
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${a.studentCount} Students',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Weekly periods badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${a.weeklyPeriods} periods/wk',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: SYLLABUS PROGRESS
  Widget _buildSyllabusTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final theme = Theme.of(context);
    final progressList = data.syllabusProgress;

    if (progressList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'No Syllabus Curriculum Mapped',
        message: 'No syllabus curriculum topics found for the teacher\'s assigned classes and subjects.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: progressList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = progressList[index];

        Color paceColor;
        switch (item.paceStatus) {
          case 'AHEAD':
            paceColor = Colors.teal;
            break;
          case 'ON_TRACK':
            paceColor = Colors.green;
            break;
          case 'SLIGHTLY_BEHIND':
            paceColor = Colors.amber.shade800;
            break;
          default:
            paceColor = Colors.red;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.className} • ${item.sectionName} — ${item.subjectName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.completedTopics} of ${item.totalTopics} topics completed • Expected by now: ${item.expectedTopicsByNow}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: paceColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: paceColor.withAlpha(70)),
                    ),
                    child: Text(
                      '${item.paceStatus.replaceAll("_", " ")} (${item.paceVariance >= 0 ? "+" : ""}${item.paceVariance}%)',
                      style: TextStyle(
                        color: paceColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.totalTopics > 0 ? item.completedTopics / item.totalTopics : 0.0,
                  backgroundColor: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate200,
                  color: paceColor,
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 14),

              // Topics Expansion / List Preview
              if (item.topics.isNotEmpty) ...[
                Text(
                  'Curriculum Topics (${item.topics.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...item.topics.map((t) {
                  final isDone = t.coverageStatus == 'COMPLETED';
                  final isExpected = t.isExpectedByNow;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : (isExpected ? Icons.pending_actions : Icons.circle_outlined),
                          size: 16,
                          color: isDone
                              ? Colors.green
                              : (isExpected ? Colors.orange : Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t.unitName}: ${t.topicName}',
                            style: TextStyle(
                              fontSize: 12,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? Colors.grey : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (isExpected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Expected by Today',
                              style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Upcoming',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  // TAB 4: TIMETABLE
  Widget _buildTimetableTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final theme = Theme.of(context);
    final allSlots = data.timetable;

    if (allSlots.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule_outlined,
        title: 'No Timetable Periods Configured',
        message: 'No weekly timetable schedule periods have been scheduled for this teacher yet.',
      );
    }

    final daySlots = allSlots
        .where((s) => s.dayOfWeek.toUpperCase() == _selectedDay.toUpperCase())
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    return Column(
      children: [
        // Day selector chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate900 : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _weekDays.map((day) {
                final isSelected = _selectedDay == day;
                final count = allSlots.where((s) => s.dayOfWeek.toUpperCase() == day).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text('$day ($count)'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    selectedColor: EduPulseTheme.primaryTeal.withAlpha(30),
                    checkmarkColor: EduPulseTheme.primaryTeal,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? EduPulseTheme.primaryTeal : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Day Periods List
        Expanded(
          child: daySlots.isEmpty
              ? _buildEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No Periods on $_selectedDay',
                  message: 'Teacher has no scheduled teaching slots on this day.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: daySlots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final slot = daySlots[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? EduPulseTheme.slate800 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'P${slot.periodNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot.subjectName ?? 'Subject Not Set',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${slot.className ?? ""} • ${slot.sectionName ?? ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${slot.startTime} – ${slot.endTime}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                slot.periodType,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 5: ATTENDANCE
  Widget _buildAttendanceTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final att = data.attendance;

    if (!att.hasData) {
      return _buildEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No Staff Attendance Logged',
        message: 'No biometric or geofenced attendance logs have been synced for this teacher for the current academic session.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Attendance Rate',
                  value: att.attendanceRate != null ? '${att.attendanceRate}%' : '—',
                  sublabel: 'Target: 90%+',
                  icon: Icons.fact_check_outlined,
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Present Days',
                  value: '${att.presentDays}',
                  sublabel: 'Total Recorded: ${att.totalRecordedDays}',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Leave Days',
                  value: '${att.leaveDays}',
                  sublabel: 'Approved leaves',
                  icon: Icons.beach_access_outlined,
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (att.recentLogs.isNotEmpty) ...[
            const Text('Recent Attendance Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...att.recentLogs.map((log) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Check-in: ${log['check_in'] ?? "—"}'),
                    Text('Check-out: ${log['check_out'] ?? "—"}'),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // TAB 6: HOMEWORK
  Widget _buildHomeworkTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final homeworks = data.homework;
    if (homeworks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No Homework Recorded',
        message: 'No homework assignments recorded yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: homeworks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hw = homeworks[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hw.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${hw.className} • ${hw.sectionName} — ${hw.subjectName}'),
              const SizedBox(height: 4),
              Text('Assigned: ${hw.assignedDate} • Due: ${hw.dueDate}'),
            ],
          ),
        );
      },
    );
  }

  // TAB 7: EXAMINATIONS
  Widget _buildExaminationsTab(
    BuildContext context,
    bool isDark,
    Teacher360Response data,
  ) {
    final theme = Theme.of(context);
    final exams = data.examCompliance;

    if (exams.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No Examination Schedules Found',
        message: 'No scheduled examinations or marks entries are associated with the teacher\'s subjects yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ex = exams[index];
        final isCompleted = ex.status == 'COMPLETED';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ex.examName} — ${ex.subjectName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ex.className} • ${ex.sectionName} • Exam Date: ${ex.examDate}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withAlpha(20) : Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCompleted ? Colors.green.withAlpha(70) : Colors.orange.withAlpha(70),
                      ),
                    ),
                    child: Text(
                      isCompleted ? 'COMPLETED' : '${ex.compliancePercentage}% ENTERED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ex.compliancePercentage / 100.0,
                  backgroundColor: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate200,
                  color: isCompleted ? Colors.green : Colors.orange,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Marks entered: ${ex.marksEnteredCount} of ${ex.totalStudents} students',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (ex.marksPendingCount > 0)
                    Text(
                      '${ex.marksPendingCount} Pending',
                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 8: WORKLOAD & PROFILE
  Widget _buildWorkloadProfileTab(
    BuildContext context,
    TeacherDto t,
    bool isDark,
    Teacher360Response data,
  ) {
    final theme = Theme.of(context);
    final workload = data.workload;
    final authState = ref.watch(authStateProvider);
    final user = authState is Authenticated ? authState.user : null;
    final permissions = PortalPermissions.fromUser(user);
    final canViewPayroll = permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capacity utilization card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? EduPulseTheme.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Teaching Capacity Utilization',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${workload.assignedWeeklyPeriods} of ${workload.weeklyPeriodCapacity} standard periods assigned (${workload.utilizationRate}%)',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: workload.assignedWeeklyPeriods / workload.weeklyPeriodCapacity,
                    backgroundColor: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate200,
                    color: EduPulseTheme.primaryTeal,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Subject & Class distribution
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subject Load Breakdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...workload.subjectDistribution.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.subjectName, style: const TextStyle(fontSize: 12)),
                              Text('${item.weeklyPeriods} periods (${item.percentage}%)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class Load Breakdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...workload.classDistribution.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.className, style: const TextStyle(fontSize: 12)),
                              Text('${item.weeklyPeriods} periods (${item.percentage}%)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Detailed Employment & Verification
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? EduPulseTheme.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employment Details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('Employment Type', t.employmentType.replaceAll('_', ' '))),
                    Expanded(child: _buildInfoRow('Monthly Salary', t.salary != null ? _formatINR(t.salary!) : 'Not Specified')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('Joining Date', t.joiningDate.isNotEmpty ? t.joiningDate : 'N/A')),
                    Expanded(child: _buildInfoRow('Department', t.department ?? 'General Academics')),
                  ],
                ),
              ],
            ),
          ),

          if (canViewPayroll) ...[
            const SizedBox(height: 16),
            _buildPayrollProfileSection(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPayrollProfileSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final payrollAsync = ref.watch(
      singleTeacherPayrollProfileProvider(
        TeacherPayrollKey(schoolId: widget.schoolId, teacherId: widget.teacher.id),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: EduPulseTheme.primaryTeal.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.payments_outlined, size: 18, color: EduPulseTheme.primaryTeal),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Teacher Compensation & Attendance Payroll Profile',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              payrollAsync.maybeWhen(
                data: (profile) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.isActive
                        ? const Color(0xFF10B981).withAlpha(25)
                        : const Color(0xFF64748B).withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: profile.isActive
                          ? const Color(0xFF10B981).withAlpha(80)
                          : const Color(0xFF64748B).withAlpha(80),
                    ),
                  ),
                  child: Text(
                    profile.isActive ? 'PAYROLL ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: profile.isActive ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          payrollAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EduPulseTheme.slate900.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No dedicated payroll profile record configured. System uses default base contract salary (${widget.teacher.salary != null ? _formatINR(widget.teacher.salary!) : "₹0"}).',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            data: (profile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Gross', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _formatINR(profile.monthlyGrossSalary),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EduPulseTheme.primaryTeal),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Deductions', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _formatINR(profile.providentFundDeduction + profile.taxDeduction + profile.otherDeductions),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? EduPulseTheme.slate900 : EduPulseTheme.slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paid Leave Quota', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.paidLeaveQuotaPerYear} days / yr',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Salary Breakdown
                  const Text('Earnings & Allowances Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoRow('Basic Pay', _formatINR(profile.basicSalary))),
                      Expanded(child: _buildInfoRow('HRA Allowance', _formatINR(profile.hraAllowance))),
                      Expanded(child: _buildInfoRow('Special Allowance', _formatINR(profile.specialAllowance))),
                      Expanded(child: _buildInfoRow('Other Allowances', _formatINR(profile.otherAllowances))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Deductions & Bank
                  const Text('Deductions & Bank Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoRow('PF Deduction', _formatINR(profile.providentFundDeduction))),
                      Expanded(child: _buildInfoRow('TDS / Tax', _formatINR(profile.taxDeduction))),
                      Expanded(child: _buildInfoRow('Bank', profile.bankName ?? 'Not Specified')),
                      Expanded(child: _buildInfoRow('Account Number', profile.bankAccountNumber ?? 'Not Specified')),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String sublabel,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: EduPulseTheme.primaryTeal.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: EduPulseTheme.primaryTeal),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
