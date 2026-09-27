import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/student_models.dart';
import '../../data/models/student_360_models.dart';
import '../providers/student_providers.dart';
import '../pages/student_details_screen.dart';
import 'student_avatar.dart';
import '../../../guardians/presentation/widgets/guardian_avatar.dart';
import '../../../teachers/presentation/providers/teachers_providers.dart';
import '../../../teachers/data/models/teachers_models.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../fees/data/models/fee_models.dart';
import '../../../fees/presentation/providers/fees_provider.dart';
import '../../../fees/presentation/widgets/fee_receipt_dialog.dart';
import '../../../fees/presentation/widgets/record_fee_payment_dialog.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../results/presentation/providers/academic_predictive_providers.dart';

/// Full-featured Student 360 Folio Modal matching the approved Google AI Studio design.
/// Provides an 8-tab comprehensive operational view: Overview, Academic, Attendance,
/// Homework, Fees, Guardian, Reports, and Activity Log.
class Student360Modal extends ConsumerStatefulWidget {
  final StudentDto student;
  final String schoolId;
  final VoidCallback? onEdit;
  final VoidCallback? onRecordFee;

  const Student360Modal({
    super.key,
    required this.student,
    required this.schoolId,
    this.onEdit,
    this.onRecordFee,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentDto student,
    required String schoolId,
    VoidCallback? onEdit,
    VoidCallback? onRecordFee,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth < 768 ? 12 : 32,
            vertical: screenHeight < 768 ? 12 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1100,
              maxHeight: (screenHeight * 0.92).clamp(400.0, 820.0),
            ),
            child: Student360Modal(
              student: student,
              schoolId: schoolId,
              onEdit: onEdit,
              onRecordFee: onRecordFee,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<Student360Modal> createState() => _Student360ModalState();
}

class _Student360ModalState extends ConsumerState<Student360Modal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDownloadingReport = false;
  String? _downloadingReportTitle;
  String? _reportCardError;
  String? _reportCardSuccess;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(studentDetailProvider(widget.student.id));
        ref.invalidate(studentLedgerProvider(widget.student.id));
        ref.invalidate(student360AnalyticsProvider(
          Student360Key(schoolId: widget.schoolId, studentId: widget.student.id),
        ));
      }
    });
  }

  @override
  void didUpdateWidget(covariant Student360Modal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id || oldWidget.schoolId != widget.schoolId) {
      ref.invalidate(studentDetailProvider(oldWidget.student.id));
      ref.invalidate(studentLedgerProvider(oldWidget.student.id));
      ref.invalidate(student360AnalyticsProvider(
        Student360Key(schoolId: oldWidget.schoolId, studentId: oldWidget.student.id),
      ));
      ref.invalidate(studentDetailProvider(widget.student.id));
      ref.invalidate(studentLedgerProvider(widget.student.id));
      ref.invalidate(student360AnalyticsProvider(
        Student360Key(schoolId: widget.schoolId, studentId: widget.student.id),
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openEditStudent(BuildContext context) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: StudentDetailsScreen(
              schoolId: widget.schoolId,
              studentId: widget.student.id,
            ),
          ),
        ),
      ),
    );

    if (updated == true) {
      ref.invalidate(studentDetailProvider(widget.student.id));
      ref.invalidate(studentLedgerProvider(widget.student.id));
      ref.invalidate(student360AnalyticsProvider(
        Student360Key(schoolId: widget.schoolId, studentId: widget.student.id),
      ));
      ref.invalidate(studentListProvider);
      widget.onEdit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final studentAsync = ref.watch(studentDetailProvider(widget.student.id));
    final s = studentAsync.valueOrNull ?? widget.student;

    final fullName = '${s.firstName} ${s.middleName ?? ''} ${s.lastName}'.replaceAll('  ', ' ').trim();

    // Strict Student 360 operational analytics derivation
    final effectiveSchoolId = widget.schoolId.isNotEmpty
        ? widget.schoolId
        : (ref.watch(selectedSchoolIdProvider) ?? s.schoolId);

    final analyticsAsync = ref.watch(
      student360AnalyticsProvider(
        Student360Key(schoolId: effectiveSchoolId, studentId: s.id),
      ),
    );
    final analytics = analyticsAsync.valueOrNull;

    // Strict non-fabricated derivation: NO 92.4, NO 84.5, NO 'Cleared' fallbacks
    final attendancePct = analytics?.attendance.attendanceRate ??
        (s.aiMetrics['attendance_rate'] as num?)?.toDouble();
    final academicAvg = analytics?.academics.academicAverage ??
        (s.aiMetrics['academic_average'] as num?)?.toDouble();
    final feePaidPct = analytics?.fees.paidPercentage;
    final feeStatus = analytics?.fees.status ??
        s.aiMetrics['fee_status']?.toString();

    final effectiveAcademicYearId = ref.watch(selectedAcademicYearIdProvider);
    final assignmentsAsync = (s.sectionId.isNotEmpty && effectiveSchoolId.isNotEmpty)
        ? ref.watch(allTeacherAssignmentsProvider((
            schoolId: effectiveSchoolId,
            academicYearId: effectiveAcademicYearId,
            sectionId: s.sectionId,
            classId: s.classId.isNotEmpty ? s.classId : null,
            teacherId: null,
            subjectId: null,
            status: 'ACTIVE',
            search: null,
          )))
        : const AsyncValue<List<TeacherSubjectAssignmentDto>>.data([]);

    final assignments = assignmentsAsync.valueOrNull ?? const [];
    TeacherSubjectAssignmentDto? ctAssignment;
    for (final a in assignments) {
      if (a.isClassTeacher) {
        ctAssignment = a;
        break;
      }
    }

    final teachersState = ref.watch(teachersListProvider);
    TeacherDto? classTeacher;
    if (ctAssignment != null) {
      for (final t in teachersState.teachers) {
        if (t.id == ctAssignment.teacherId) {
          classTeacher = t;
          break;
        }
      }
    }

    final resolvedTeacher = classTeacher ??
        (ctAssignment != null
            ? ref.watch(teacherDetailProvider(ctAssignment.teacherId)).valueOrNull
            : null);
    final classTeacherName = resolvedTeacher?.fullName ??
        (ctAssignment != null ? 'Class Teacher' : null);
    final classTeacherId = ctAssignment?.teacherId;

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
                          s.admissionNumber,
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
                        '• Student 360 Folio •',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Roll #${s.rollNumber}',
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
                  StudentAvatar(
                    studentId: s.id,
                    schoolId: effectiveSchoolId,
                    photoUrl: s.photoUrl,
                    firstName: s.firstName,
                    lastName: s.lastName,
                    version: '${s.version}_${s.updatedAt}',
                    radius: 28,
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
                                fullName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : EduPulseTheme.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: attendancePct != null
                                  ? '${attendancePct.toStringAsFixed(0)}% Attendance'
                                  : 'No attendance data',
                              variant: attendancePct == null
                                  ? StatusBadgeVariant.neutral
                                  : (attendancePct >= 75
                                      ? StatusBadgeVariant.success
                                      : StatusBadgeVariant.error),
                              size: StatusBadgeSize.sm,
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: (feeStatus != null && feeStatus != 'No fee records')
                                  ? feeStatus
                                  : 'No fee records',
                              variant: feeStatus == 'Cleared'
                                  ? StatusBadgeVariant.success
                                  : (feeStatus == 'Partial'
                                      ? StatusBadgeVariant.warning
                                      : StatusBadgeVariant.neutral),
                              size: StatusBadgeSize.sm,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${s.className ?? 'Class'} • Section ${s.sectionName ?? 'A'}  |  Admitted: ${s.admissionDate}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (classTeacherId != null)
                              InkWell(
                                key: const Key('student_360_class_teacher_link'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('${AppRoutes.teachers}/$classTeacherId?school_id=$effectiveSchoolId');
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? EduPulseTheme.primaryTeal.withValues(alpha: 0.18) : const Color(0xFFE6FFFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: EduPulseTheme.primaryTeal.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.school_outlined, size: 12, color: EduPulseTheme.primaryTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Class Teacher: ${classTeacherName ?? 'Assigned'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: EduPulseTheme.primaryTeal,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.open_in_new, size: 10, color: EduPulseTheme.primaryTeal),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('student_360_record_fee_button'),
                    onPressed: widget.onRecordFee ?? () => _showRecordPaymentDialog(context),
                    icon: const Icon(Icons.payment_rounded, size: 14),
                    label: const Text('Record Fee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EduPulseTheme.emeraldSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('student_360_edit_button'),
                    onPressed: () => _openEditStudent(context),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
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
                  Tab(icon: Icon(Icons.school_outlined, size: 16), text: 'Academic'),
                  Tab(icon: Icon(Icons.calendar_today_outlined, size: 16), text: 'Attendance'),
                  Tab(icon: Icon(Icons.assignment_outlined, size: 16), text: 'Homework'),
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 16), text: 'Fees'),
                  Tab(icon: Icon(Icons.family_restroom_outlined, size: 16), text: 'Guardian'),
                  Tab(icon: Icon(Icons.description_outlined, size: 16), text: 'Reports'),
                  Tab(icon: Icon(Icons.history_outlined, size: 16), text: 'Activity'),
                ],
              ),
            ),

            // 4. Tab Views
            Expanded(
              child: Container(
                color: isDark ? EduPulseTheme.slate950 : EduPulseTheme.slate50,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(
                      context,
                      s,
                      isDark,
                      analytics,
                      attendancePct,
                      academicAvg,
                      feePaidPct,
                      feeStatus,
                      classTeacherName: classTeacherName,
                      classTeacherId: classTeacherId,
                      effectiveSchoolId: effectiveSchoolId,
                    ),
                    _buildAcademicTab(context, s, isDark, analytics),
                    _buildAttendanceTab(context, s, isDark, analytics, attendancePct),
                    _buildHomeworkTab(context, s, isDark, analytics),
                    _buildFeesTab(context, s, isDark, analytics),
                    _buildGuardianTab(context, s, isDark, effectiveSchoolId),
                    _buildReportsTab(context, s, isDark, analytics),
                    _buildActivityTab(context, s, isDark, analytics),
                  ],
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
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
    double? attendancePct,
    double? academicAvg,
    double? feePaidPct,
    String? feeStatus, {
    String? classTeacherName,
    String? classTeacherId,
    String? effectiveSchoolId,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 Metric Ring Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: attendancePct != null
                      ? ProgressRing(
                          value: attendancePct,
                          size: 80,
                          strokeWidth: 8,
                          color: attendancePct >= 75
                              ? EduPulseTheme.emeraldSuccess
                              : EduPulseTheme.roseDanger,
                          label: 'Attendance Rate',
                          sublabel: '75% Target',
                        )
                      : _buildNoDataMetricCard(
                          title: 'Attendance Rate',
                          value: '—',
                          sublabel: 'No attendance data',
                          isDark: isDark,
                          icon: Icons.calendar_today_outlined,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: academicAvg != null
                      ? ProgressRing(
                          value: academicAvg,
                          size: 80,
                          strokeWidth: 8,
                          color: EduPulseTheme.primaryTeal,
                          label: 'Academic Score',
                          sublabel: 'Term 1 Avg',
                        )
                      : _buildNoDataMetricCard(
                          title: 'Academic Score',
                          value: '—',
                          sublabel: 'No academic data',
                          isDark: isDark,
                          icon: Icons.school_outlined,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: feePaidPct != null
                      ? ProgressRing(
                          value: feePaidPct,
                          size: 80,
                          strokeWidth: 8,
                          color: EduPulseTheme.emeraldSuccess,
                          label: 'Fees Paid',
                          sublabel: '${feePaidPct.toStringAsFixed(0)}% Cleared',
                        )
                      : _buildNoDataMetricCard(
                          title: 'Fees Paid',
                          value: '—',
                          sublabel: (feeStatus != null && feeStatus != 'No fee records')
                              ? feeStatus
                              : 'No fee records',
                          isDark: isDark,
                          icon: Icons.receipt_long_outlined,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Insight Card (Strict: never fabricate recommendations when data is insufficient)
          if (analytics?.aiAnalysis.hasData == true && analytics?.aiAnalysis.headline != null)
            AIInsightCard(
              trend: analytics!.aiAnalysis.trend == 'declining'
                  ? TrendDirection.declining
                  : TrendDirection.improving,
              headline: analytics.aiAnalysis.headline!,
              insight: analytics.aiAnalysis.insight ?? '',
              strongHighlights: analytics.aiAnalysis.strongHighlights,
              supportHighlights: analytics.aiAnalysis.supportHighlights,
              actionRecommendation: analytics.aiAnalysis.actionRecommendation ?? '',
            )
          else
            const AIInsightCard(
              trend: TrendDirection.improving,
              headline: 'Insufficient data for AI analysis',
              insight:
                  'Classroom attendance and examination marks are required before AI insights can be generated for this student.',
              strongHighlights: [],
              supportHighlights: [],
              actionRecommendation:
                  'Record student attendance and examination scores to enable AI analysis.',
            ),
          const SizedBox(height: 16),

          // Quick Info Grid
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
                Text(
                  'STUDENT PROFILE & CONTACT INFORMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('DOB', s.dateOfBirth, isDark)),
                    Expanded(child: _buildInfoItem('Gender', s.gender, isDark)),
                    Expanded(child: _buildInfoItem('Blood Group', s.bloodGroup ?? '—', isDark)),
                    Expanded(child: _buildInfoItem('Mobile', s.mobile ?? '—', isDark)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('Aadhaar #', s.aadhaarNumber ?? '—', isDark)),
                    Expanded(child: _buildInfoItem('EMIS #', s.emisNumber ?? '—', isDark)),
                    Expanded(child: _buildInfoItem('Email', s.email ?? '—', isDark)),
                    Expanded(
                        child: _buildInfoItem(
                            'City', s.address['city']?.toString() ?? '—', isDark)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('Class', s.className ?? '—', isDark)),
                    Expanded(child: _buildInfoItem('Section', s.sectionName ?? '—', isDark)),
                    Expanded(
                      child: classTeacherId != null
                          ? InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('${AppRoutes.teachers}/$classTeacherId?school_id=${effectiveSchoolId ?? s.schoolId}');
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CLASS TEACHER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          classTeacherName ?? 'View Teacher',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: EduPulseTheme.primaryTeal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.open_in_new, size: 12, color: EduPulseTheme.primaryTeal),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : _buildInfoItem('Class Teacher', 'Not Assigned', isDark),
                    ),
                    Expanded(child: _buildInfoItem('Admitted On', s.admissionDate, isDark)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: ACADEMIC & MARKS
  Widget _buildAcademicTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final hasAcademicData = analytics?.academics.hasData == true &&
        ((analytics?.academics.examTrends.isNotEmpty ?? false) ||
            (analytics?.academics.subjectScores.isNotEmpty ?? false));

    if (!hasAcademicData) {
      return const EmptyStateWidget(
        title: 'No Academic Records',
        description: 'No examination marks or evaluations have been recorded for this student yet.',
      );
    }

    final examTrendPoints = (analytics?.academics.examTrends ?? const [])
        .map((e) => TrendDataPoint(
              label: e.label,
              value: e.value,
              tooltipDetail: e.tooltipDetail,
            ))
        .toList();

    final subjectScores = (analytics?.academics.subjectScores ?? const [])
        .map((sc) => SubjectScore(
              subject: sc.subject,
              score: sc.score,
              grade: sc.grade ?? '',
              strong: sc.strong,
              needsSupport: sc.needsSupport,
            ))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Academic Summary KPI Header Card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVERALL SCORE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            analytics?.academics.currentScore != null
                                ? '${analytics!.academics.currentScore!.toStringAsFixed(1)}%'
                                : '—',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : EduPulseTheme.slate900,
                            ),
                          ),
                          if (analytics?.academics.overallGrade != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: EduPulseTheme.primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Grade ${analytics!.academics.overallGrade}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECTION RANK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analytics?.academics.sectionRank ?? '—',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : EduPulseTheme.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLASS RANK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analytics?.academics.classRank ?? '—',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : EduPulseTheme.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Completed Examination History
          if ((analytics?.academics.completedExaminations.isNotEmpty ?? false)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                      const Row(
                        children: [
                          Icon(Icons.workspace_premium_outlined, color: EduPulseTheme.primaryTeal, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Completed Examination Cycles',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '${analytics!.academics.completedExaminations.length} Published',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...analytics.academics.completedExaminations.map((exam) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? EduPulseTheme.slate900 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? EduPulseTheme.slate700 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.examinationName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : EduPulseTheme.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${exam.examType} • ${exam.examDate}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${exam.totalObtainedMarks.toStringAsFixed(0)} / ${exam.totalMaxMarks.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : EduPulseTheme.slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${exam.percentage.toStringAsFixed(1)}% (${exam.grade})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            StatusBadge(
                              label: exam.status,
                              variant: StatusBadgeVariant.success,
                              size: StatusBadgeSize.sm,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],

          // Student Predictive Trajectory & Score Band Forecast
          Consumer(
            builder: (context, ref, _) {
              final predAsync = ref.watch(studentPredictiveProvider(s.id));
              return predAsync.when(
                data: (pred) {
                  if (pred == null) return const SizedBox.shrink();
                  final suff = pred.dataSufficiency;
                  final summary = pred.studentPredictiveSummary;

                  if (suff.isInsufficient || suff.isDescriptiveOnly || summary == null) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? EduPulseTheme.slate800 : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suff.statusMessage.isNotEmpty
                                  ? suff.statusMessage
                                  : 'Trajectory prediction requires at least two examination cycles.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? EduPulseTheme.slate800 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? EduPulseTheme.slate700 : const Color(0xFF0D9488).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_graph_rounded, color: Color(0xFF0D9488), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'AI Academic Trajectory & Forecast',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: summary.trajectoryDirection == 'IMPROVING'
                                    ? const Color(0xFFDCFCE7)
                                    : summary.trajectoryDirection == 'DECLINING'
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${summary.trajectoryDirection} TRAJECTORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: summary.trajectoryDirection == 'IMPROVING'
                                      ? const Color(0xFF15803D)
                                      : summary.trajectoryDirection == 'DECLINING'
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (summary.predictedScoreBand != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.speed_rounded, color: Color(0xFF0D9488), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Expected Score Band for Upcoming Exam: ${summary.predictedScoreBand!.minPercentage.toStringAsFixed(1)}% – ${summary.predictedScoreBand!.maxPercentage.toStringAsFixed(1)}% (${summary.predictedScoreBand!.confidenceInterval} Confidence)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F766E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (summary.strongSubjects.isNotEmpty || summary.weakSubjects.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summary.strongSubjects.isNotEmpty)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Excelling In:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        children: summary.strongSubjects.map((sb) => Chip(
                                          label: Text(sb, style: const TextStyle(fontSize: 11)),
                                          backgroundColor: const Color(0xFFDCFCE7),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              if (summary.weakSubjects.isNotEmpty)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recommended Focus:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        children: summary.weakSubjects.map((sb) => Chip(
                                          label: Text(sb, style: const TextStyle(fontSize: 11)),
                                          backgroundColor: const Color(0xFFFEE2E2),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: 16),
          if (examTrendPoints.isNotEmpty) ...[
            LineTrendChart(
              title: 'Examination Performance Progression',
              timeframe: 'Current Academic Term',
              threshold: 75,
              thresholdLabel: '75% Distinction Target',
              data: examTrendPoints,
              trend: (analytics?.academics.academicAverage ?? 0) >= 75
                  ? TrendDirection.improving
                  : TrendDirection.declining,
              trendNote: 'Evaluated across ${examTrendPoints.length} examination cycles.',
            ),
            const SizedBox(height: 16),
          ],
          if (subjectScores.isNotEmpty)
            SubjectBarChart(
              title: 'Subject Performance Breakdown',
              benchmark: 75,
              data: subjectScores,
            ),
          const SizedBox(height: 16),
          _buildQuestionAndTopicAssessmentSection(context, s, isDark, analytics),
        ],
      ),
    );
  }

  Widget _buildQuestionAndTopicAssessmentSection(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final dynamic rawTopics = s.aiMetrics['topic_performance'] ?? s.aiMetrics['topics'];
    final dynamic rawQuestions = s.aiMetrics['question_performance'] ?? s.aiMetrics['question_marks'];

    final hasQuestionData = (rawTopics is Map && rawTopics.isNotEmpty) ||
        (rawTopics is List && rawTopics.isNotEmpty) ||
        (rawQuestions is Map && rawQuestions.isNotEmpty) ||
        (rawQuestions is List && rawQuestions.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: Colors.indigo.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Question & Topic-Level Assessment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasQuestionData ? Colors.teal.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasQuestionData ? Colors.teal.shade300 : Colors.amber.shade300,
                  ),
                ),
                child: Text(
                  hasQuestionData ? 'Topic Mastery Available' : 'Mode A: Total Marks Only',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasQuestionData ? Colors.teal.shade900 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasQuestionData)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate900 : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detailed topic analysis unavailable because question-wise marks were not entered.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Overall examination score is recorded. To unlock granular topic mastery and difficulty analytics, enter marks via Mode B (Question-Wise Grid).',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (rawTopics is Map)
              ...rawTopics.entries.map((e) {
                final topicName = e.key.toString();
                final scorePct = (e.value as num?)?.toDouble() ?? 0.0;
                final isStrong = scorePct >= 60.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(topicName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(
                            '${scorePct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isStrong ? Colors.teal.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (scorePct / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isStrong ? Colors.teal : Colors.orange,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  // TAB 3: ATTENDANCE
  Widget _buildAttendanceTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
    double? attendancePct,
  ) {
    final hasAttendanceData = analytics?.attendance.hasData == true &&
        (analytics?.attendance.totalDays ?? 0) > 0;

    if (!hasAttendanceData) {
      return const EmptyStateWidget(
        title: 'No Attendance Data',
        description: 'No daily or session attendance records have been marked for this student yet.',
      );
    }

    final presentDays = analytics?.attendance.presentDays ?? 0;
    final absentDays = analytics?.attendance.absentDays ?? 0;
    final lateDays = analytics?.attendance.lateDays ?? 0;
    final leaveDays = analytics?.attendance.leaveDays ?? 0;
    final workingDays = analytics?.attendance.workingDays ?? analytics?.attendance.totalDays ?? 0;

    final donutData = [
      DonutSegment(
        id: 'p',
        label: 'Present',
        value: presentDays.toDouble(),
        color: EduPulseTheme.emeraldSuccess,
      ),
      DonutSegment(
        id: 'a',
        label: 'Absent',
        value: absentDays.toDouble(),
        color: EduPulseTheme.roseDanger,
      ),
      if (lateDays > 0)
        DonutSegment(
          id: 'late',
          label: 'Late',
          value: lateDays.toDouble(),
          color: const Color(0xFFD97706),
        ),
      if (leaveDays > 0)
        DonutSegment(
          id: 'l',
          label: 'Excused Leave',
          value: leaveDays.toDouble(),
          color: EduPulseTheme.amberWarning,
        ),
    ];

    final monthlyAttendance = (analytics?.attendance.monthlyTrend ?? const [])
        .map((t) => TrendDataPoint(
              label: t.label,
              value: t.value,
            ))
        .toList();

    final rateDisplay = attendancePct != null
        ? '${attendancePct.toStringAsFixed(1)}%'
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Attendance Key Statistics Bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WORKING DAYS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$workingDays',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : EduPulseTheme.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRESENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$presentDays Days',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABSENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$absentDays Days',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$lateDays Days',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? EduPulseTheme.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
              ),
            ),
            child: DonutChart(
              title: 'Attendance Composition',
              timeframe: 'Current Academic Term',
              centerLabel: rateDisplay,
              centerSublabel: 'Total Presence',
              data: donutData,
            ),
          ),
          if (monthlyAttendance.isNotEmpty) ...[
            const SizedBox(height: 16),
            LineTrendChart(
              title: 'Monthly Attendance Trend',
              timeframe: 'Current Recorded Months',
              threshold: 75,
              thresholdLabel: '75% Mandatory Board Rule',
              data: monthlyAttendance,
              unit: '%',
            ),
          ],
        ],
      ),
    );
  }

  // TAB 4: HOMEWORK
  Widget _buildHomeworkTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final assignments = analytics?.homework ?? const [];
    if (assignments.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Homework Assigned',
        description: 'No active homework or assignments recorded for this student\'s section.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final item = assignments[idx];
        final isCompleted = item.status.toLowerCase() == 'completed' ||
            item.status.toLowerCase() == 'submitted';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.subject} • ${item.date}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: item.status,
                variant: isCompleted ? StatusBadgeVariant.success : StatusBadgeVariant.warning,
                size: StatusBadgeSize.sm,
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 5: FEES
  Widget _buildFeesTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final ledgerState = ref.watch(studentLedgerProvider(s.id));
    final ledger = ledgerState.ledger;

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    // Strict non-fabricated accounting from real ledger or analytics
    final hasRealLedger = ledger != null &&
        (ledger.assignments.isNotEmpty || ledger.payments.isNotEmpty);
    final hasAnalyticsFees = analytics != null && analytics.fees.hasData;

    final totalAssigned = hasRealLedger
        ? ledger.assignments.fold<double>(0.0, (sum, a) => sum + a.assignedAmount)
        : (hasAnalyticsFees ? analytics.fees.totalAssigned : 0.0);

    final totalPaid = hasRealLedger
        ? ledger.payments.where((p) => p.status == PaymentStatus.COMPLETED).fold<double>(0.0, (sum, p) => sum + p.amountPaid)
        : (hasAnalyticsFees ? analytics.fees.totalPaid : 0.0);

    final balanceOutstanding = hasRealLedger
        ? ledger.closingBalance
        : (hasAnalyticsFees ? analytics.fees.balanceOutstanding : 0.0);

    final hasFeeRecords = hasRealLedger ||
        (hasAnalyticsFees && (totalAssigned > 0 || totalPaid > 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: KPICard(
                  title: 'Total Tuition & Dues',
                  value: currencyFormatter.format(totalAssigned),
                  subtitle: hasFeeRecords ? 'Academic Term Dues' : 'No fee dues assigned',
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: EduPulseTheme.primaryTeal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KPICard(
                  title: 'Collected Amount',
                  value: currencyFormatter.format(totalPaid),
                  subtitle: !hasFeeRecords
                      ? 'No payments recorded'
                      : (balanceOutstanding <= 0 && totalAssigned > 0
                          ? '100% Paid in full'
                          : 'Partial payment recorded'),
                  icon: const Icon(Icons.check_circle_outline, color: EduPulseTheme.emeraldSuccess),
                  trendValue: !hasFeeRecords ? 'None' : (balanceOutstanding <= 0 ? 'Full Cleared' : 'Pending'),
                  trendPositive: hasFeeRecords && balanceOutstanding <= 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KPICard(
                  title: 'Balance Outstanding',
                  value: currencyFormatter.format(balanceOutstanding),
                  subtitle: !hasFeeRecords
                      ? 'No outstanding dues'
                      : (balanceOutstanding <= 0 ? 'No overdue balance' : 'Pending balance due'),
                  icon: Icon(
                    balanceOutstanding <= 0 ? Icons.check_outlined : Icons.warning_amber_rounded,
                    color: balanceOutstanding <= 0 ? Colors.blue : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT FEE RECEIPTS (INR)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('record_fee_tab_button'),
                onPressed: () => _showRecordPaymentDialog(context),
                icon: const Icon(Icons.payment, size: 14),
                label: const Text('Record Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduPulseTheme.emeraldSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? EduPulseTheme.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
              ),
            ),
            child: Column(
              children: [
                if (ledger != null && ledger.payments.isNotEmpty) ...[
                  for (int i = 0; i < ledger.payments.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    InkWell(
                      key: Key('receipt_row_${ledger.payments[i].receiptNumber}'),
                      onTap: () => _showReceiptDialog(
                        context,
                        ledger.payments[i],
                        s,
                        widget.schoolId,
                        ledger,
                      ),
                      child: _buildReceiptRow(
                        ledger.payments[i].receiptNumber ?? 'REC-${ledger.payments[i].id.substring(0, 8).toUpperCase()}',
                        DateFormat('dd MMM yyyy').format(ledger.payments[i].paymentDate),
                        currencyFormatter.format(ledger.payments[i].amountPaid),
                        ledger.payments[i].status.name,
                        ledger.payments[i].paymentMethod.name.replaceAll('_', ' '),
                        isDark,
                      ),
                    ),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No fee receipts recorded yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String rec, String date, String amount, String head, String mode, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rec,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                '$head • $mode',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: EduPulseTheme.emeraldSuccess,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 6: GUARDIAN
  Widget _buildGuardianTab(BuildContext context, StudentDto s, bool isDark, String effectiveSchoolId) {
    final mappingState = ref.watch(studentGuardianProvider(s.id));

    return mappingState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: EduPulseTheme.roseDanger, size: 32),
            const SizedBox(height: 8),
            Text('Error loading guardians: $err', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(studentGuardianProvider(s.id)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (mappings) {
        if (mappings.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Linked Guardians',
            description: 'This student record does not have linked parents or guardians registered yet.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mappings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final m = mappings[idx];
            final guardianName = m.guardian?.fullName.trim().isNotEmpty == true
                ? m.guardian!.fullName.trim()
                : 'Guardian';
            final phone = m.guardian?.mobile ?? '';
            final email = m.guardian?.email ?? '';
            final loginId = m.guardian?.loginId ?? '';
            final addressMap = m.guardian?.address;
            final addressParts = [
              if (addressMap?['line'] != null && addressMap!['line'].toString().isNotEmpty)
                addressMap['line'].toString(),
              if (addressMap?['city'] != null && addressMap!['city'].toString().isNotEmpty)
                addressMap['city'].toString(),
              if (addressMap?['state'] != null && addressMap!['state'].toString().isNotEmpty)
                addressMap['state'].toString(),
            ];
            final addressStr = addressParts.join(', ');

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuardianAvatar(
                        guardianId: m.guardianId,
                        schoolId: effectiveSchoolId,
                        photoUrl: m.guardian?.photoUrl,
                        firstName: m.guardian?.firstName ?? (guardianName.isNotEmpty ? guardianName.split(' ').first : 'G'),
                        lastName: m.guardian?.lastName ?? (guardianName.split(' ').length > 1 ? guardianName.split(' ').sublist(1).join(' ') : ''),
                        radius: 26,
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
                                    guardianName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (loginId.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? EduPulseTheme.slate700 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      loginId,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusBadge(
                                  label: m.relationship.toUpperCase(),
                                  variant: StatusBadgeVariant.info,
                                  size: StatusBadgeSize.sm,
                                ),
                                if (m.isPrimary)
                                  const StatusBadge(
                                    label: 'PRIMARY',
                                    variant: StatusBadgeVariant.brand,
                                    size: StatusBadgeSize.sm,
                                  ),
                                if (m.canPickupStudent)
                                  const StatusBadge(
                                    label: 'CAN PICKUP',
                                    variant: StatusBadgeVariant.success,
                                    size: StatusBadgeSize.sm,
                                  ),
                                if (m.receivesNotifications)
                                  const StatusBadge(
                                    label: 'NOTIFICATIONS',
                                    variant: StatusBadgeVariant.neutral,
                                    size: StatusBadgeSize.sm,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone.isNotEmpty ? phone : '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    if (m.guardian?.isMobileVerified == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 13, color: EduPulseTheme.emeraldSuccess),
                                    ],
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.email_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      email.isNotEmpty ? email : '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    if (m.guardian?.isEmailVerified == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 13, color: EduPulseTheme.emeraldSuccess),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (m.guardian?.occupation != null && m.guardian!.occupation!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.work_outline, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${m.guardian!.occupation}${m.guardian?.organization != null && m.guardian!.organization!.isNotEmpty ? ' at ${m.guardian!.organization}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (addressStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      addressStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Actions: Call, Email, and View Guardian 360
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone_outlined, size: 18),
                                tooltip: phone.isNotEmpty ? 'Copy Phone: $phone' : 'No phone number',
                                onPressed: phone.isNotEmpty
                                    ? () {
                                        Clipboard.setData(ClipboardData(text: phone));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Phone copied to clipboard: $phone')),
                                        );
                                      }
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                                tooltip: email.isNotEmpty ? 'Copy Email: $email' : 'No email address',
                                onPressed: email.isNotEmpty
                                    ? () {
                                        Clipboard.setData(ClipboardData(text: email));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Email copied to clipboard: $email')),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            key: Key('view_guardian_360_${m.guardianId}'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('${AppRoutes.guardians}/${m.guardianId}?school_id=$effectiveSchoolId');
                            },
                            icon: const Icon(Icons.person_pin_outlined, size: 14),
                            label: const Text('View Guardian 360'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EduPulseTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDownloadReport(BuildContext context, Student360ReportCard report, StudentDto s) async {
    final title = report.title;
    final isAvailable = report.isAvailable;

    if (!isAvailable) {
      setState(() {
        _reportCardError = '${title.isNotEmpty ? title : "Report card"} is not ready for download yet.';
        _reportCardSuccess = null;
      });
      return;
    }

    setState(() {
      _isDownloadingReport = true;
      _downloadingReportTitle = title;
      _reportCardError = null;
      _reportCardSuccess = null;
    });

    try {
      final effectiveSchoolId = widget.schoolId.isNotEmpty
          ? widget.schoolId
          : (ref.read(selectedSchoolIdProvider) ?? s.schoolId);

      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(
        '/report-cards/download/${s.id}?school_id=$effectiveSchoolId',
        options: Options(responseType: ResponseType.bytes),
        mapper: (bytes) => bytes,
      );

      bool downloaded = false;
      res.when(
        onSuccess: (data) {
          if (data is List<int>) {
            downloadBinaryFile(
              'EduPulse_ReportCard_${s.admissionNumber}.pdf',
              data,
              mimeType: 'application/pdf',
            );
            downloaded = true;
          }
        },
        onFailure: (failure) {
          if (mounted) {
            String errorMsg;
            if (failure.statusCode == 404 ||
                failure.message.contains('404') ||
                failure.message.contains('not been compiled') ||
                failure.message.contains('not found')) {
              errorMsg = 'Report card has not been compiled yet.';
            } else {
              errorMsg = failure.message.isNotEmpty
                  ? failure.message
                  : 'Unable to download the report card. Please try again.';
            }
            setState(() {
              _reportCardError = errorMsg;
              _reportCardSuccess = null;
            });
          }
        },
      );

      if (downloaded && mounted) {
        setState(() {
          _reportCardSuccess = 'Report card downloaded successfully.';
          _reportCardError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportCardError =
              'Unable to download report card: ${e.toString().replaceAll('Exception: ', '')}';
          _reportCardSuccess = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingReport = false;
          _downloadingReportTitle = null;
        });
      }
    }
  }

  // TAB 7: REPORTS
  Widget _buildReportsTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final reports = analytics?.reports ?? const [];

    if (reports.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Report Cards Published',
        description: 'No academic report cards have been published for this student yet. Report cards will appear here once generated and published by the academic office.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reportCardError != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _reportCardError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9F1239),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (reports.isNotEmpty)
                  TextButton(
                    onPressed: () => _handleDownloadReport(context, reports.first, s),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF9F1239)),
                  onPressed: () => setState(() => _reportCardError = null),
                ),
              ],
            ),
          ),
        if (_reportCardSuccess != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _reportCardSuccess!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF065F46)),
                  onPressed: () => setState(() => _reportCardSuccess = null),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final r = reports[idx];
              final isAvailable = r.isAvailable;
              final isThisDownloading =
                  _isDownloadingReport && _downloadingReportTitle == r.title;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            color: isAvailable ? EduPulseTheme.roseDanger : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : EduPulseTheme.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Status: ${r.status}${r.publishedDate != null ? ' • Published: ${r.publishedDate}' : (r.generatedDate != null ? ' • Generated: ${r.generatedDate}' : '')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _isDownloadingReport
                          ? null
                          : () => _handleDownloadReport(context, r, s),
                      icon: isThisDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isAvailable ? Icons.download_rounded : Icons.lock_outline,
                              size: 14,
                              color: isAvailable ? null : const Color(0xFF94A3B8),
                            ),
                      label: Text(
                        isThisDownloading
                            ? 'Downloading...'
                            : isAvailable
                                ? 'Download PDF'
                                : 'Pending Publication',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAvailable ? null : const Color(0xFF94A3B8),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
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

  // TAB 8: ACTIVITY LOG
  Widget _buildActivityTab(
    BuildContext context,
    StudentDto s,
    bool isDark,
    Student360Analytics? analytics,
  ) {
    final logs = analytics?.activityLogs ?? const [];
    if (logs.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Activity Recorded',
        description: 'No recent events or activity logs recorded for this student profile.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final log = logs[idx];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: EduPulseTheme.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                if (idx < logs.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.event,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.time} • Action by: ${log.by}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoDataMetricCard({
    required String title,
    required String value,
    required String sublabel,
    required bool isDark,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : EduPulseTheme.slate900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : EduPulseTheme.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : EduPulseTheme.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _showRecordPaymentDialog(BuildContext pageContext) async {
    final s = widget.student;
    final schoolId = widget.schoolId;

    await showRecordFeePaymentDialog(
      context: pageContext,
      studentId: s.id,
      studentName: '${s.firstName} ${s.lastName}',
      admissionNumber: s.admissionNumber,
      schoolId: schoolId,
      initialAcademicYearId: s.academicYearId,
      onPaymentSuccess: () {
        ref.invalidate(studentLedgerProvider(s.id));
        ref.invalidate(studentDetailProvider(s.id));
        ref.invalidate(student360AnalyticsProvider(
          Student360Key(schoolId: schoolId, studentId: s.id),
        ));
        ref.invalidate(studentListProvider);
      },
    );
  }

  void _showReceiptDialog(
    BuildContext context,
    FeePayment payment,
    StudentDto student,
    String schoolId,
    StudentLedger ledger,
  ) {
    final schoolsState = ref.read(schoolsListProvider);
    SchoolDto? school;
    for (final sch in schoolsState.schools) {
      if (sch.id == schoolId) {
        school = sch;
        break;
      }
    }

    final ayState = ref.read(academicYearsProvider(schoolId));
    AcademicYearDto? ay;
    for (final y in ayState.years) {
      if (y.id == payment.academicYearId) {
        ay = y;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => FeeReceiptDialog(
        payment: payment,
        student: student,
        schoolName: school?.name ?? 'EduPulse Academy',
        schoolAddress: school?.address,
        schoolPhone: school?.phone,
        schoolEmail: school?.email,
        academicYearName: ay?.name,
        assignedAmount: ledger.assignments.isNotEmpty ? ledger.assignments.first.assignedAmount : null,
        remainingBalance: ledger.closingBalance,
        apiClient: ref.read(apiClientProvider),
      ),
    );
  }
}
