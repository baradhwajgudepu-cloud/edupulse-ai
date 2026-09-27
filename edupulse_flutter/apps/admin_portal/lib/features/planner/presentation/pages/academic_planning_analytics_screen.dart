import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/routing/routes.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';
import '../widgets/cross_teacher_recovery_dialog.dart';
import '../widgets/academic_heatmap_widget.dart';
import '../widgets/admin_recovery_plans_widget.dart';

class AcademicPlanningAnalyticsScreen extends ConsumerStatefulWidget {
  const AcademicPlanningAnalyticsScreen({super.key});

  @override
  ConsumerState<AcademicPlanningAnalyticsScreen> createState() => _AcademicPlanningAnalyticsScreenState();
}

class _AcademicPlanningAnalyticsScreenState extends ConsumerState<AcademicPlanningAnalyticsScreen> {
  String? _selectedAyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        body: Center(
          child: Text('Please select a school campus from the header to view Academic Planning Analytics.'),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final hasValidSelection = _selectedAyId != null && ayState.years.any((y) => y.id == _selectedAyId);
    if (!hasValidSelection && ayState.years.isNotEmpty) {
      final current = ayState.years.where((y) => y.isCurrent).firstOrNull ?? ayState.years.first;
      _selectedAyId = current.id;
    } else if (ayState.years.isEmpty) {
      _selectedAyId = null;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        appBar: AppBar(
          title: const Text('Academic Planning Intelligence & Pace Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0.5,
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                side: const BorderSide(color: Color(0xFF0F766E)),
              ),
              icon: const Icon(Icons.edit_note, size: 16),
              label: const Text('Syllabus Editor'),
              onPressed: () => context.push(AppRoutes.syllabusEditor),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const Text('Timetable Management'),
              onPressed: () => context.push(AppRoutes.timetables),
            ),
            const SizedBox(width: 16),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF0F766E),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF0F766E),
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Curriculum Pace & Analytics'),
              Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Academic Heatmap (Class × Subject)'),
              Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'Recovery Plans & Validator'),
            ],
          ),
        ),
        body: _selectedAyId == null
            ? (ayState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 16),
                          const Text(
                            'No Academic Years Configured',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Configure academic years for this school campus to view planning analytics.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            onPressed: () => ref.read(academicYearsProvider(schoolId).notifier).fetchYears(),
                          ),
                        ],
                      ),
                    ),
                  ))
            : TabBarView(
                children: [
                  _buildOverviewTab(context, ref, schoolId, ayState),
                  AcademicHeatmapWidget(schoolId: schoolId, academicYearId: _selectedAyId!),
                  AdminRecoveryPlansWidget(schoolId: schoolId, academicYearId: _selectedAyId!),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, WidgetRef ref, String schoolId, AcademicYearsState ayState) {
    final List<DropdownMenuItem<String>> ayItems = ayState.years.isEmpty
        ? const <DropdownMenuItem<String>>[]
        : ayState.years.map<DropdownMenuItem<String>>(
            (y) => DropdownMenuItem<String>(
              key: Key('ay_dropdown_item_${y.id}'),
              value: y.id,
              child: Text(y.name),
            ),
          ).toList();

    final selectedValue = ayItems.any((item) => item.value == _selectedAyId)
        ? _selectedAyId
        : (ayItems.isNotEmpty ? ayItems.first.value : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Academic Year Selector Header (Always visible)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Academic Term Progress Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('Real-time syllabus completion pace, exam deadline projections, and automated schedule calibrations.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: const Key('academic_year_dropdown'),
                  value: selectedValue,
                  decoration: InputDecoration(
                    labelText: 'Academic Year',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  items: ayItems,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAyId = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview Analytics Content
          Consumer(
            builder: (context, ref, child) {
              final summaryAsync = ref.watch(academicPlanningSummaryProvider((
                schoolId: schoolId,
                academicYearId: _selectedAyId!,
              )));

              return summaryAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stackTrace) {
                  debugPrint('AcademicPlanningAnalytics error: $err\n$stackTrace');
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          const Text(
                            'Academic Planning Analytics Unavailable',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load academic planning analytics: $err',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            key: const Key('retry_academic_planning_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            onPressed: () => ref.invalidate(academicPlanningSummaryProvider((
                              schoolId: schoolId,
                              academicYearId: _selectedAyId!,
                            ))),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (summary) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top KPI Metric Cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 650 ? 2 : 1);
                          final cardWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildKpiCard(
                                  title: 'School Completion Rate',
                                  value: '${summary.schoolWideCompletionPct.toStringAsFixed(1)}%',
                                  subtitle: '${summary.totalSubjectsTracked} Active Subjects',
                                  icon: Icons.trending_up,
                                  color: const Color(0xFF0F766E),
                                  progressValue: summary.schoolWideCompletionPct / 100.0,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildKpiCard(
                                  title: 'Subjects On Track',
                                  value: '${summary.onTrackCount}',
                                  subtitle: 'Meeting Pace Target',
                                  icon: Icons.check_circle_outline,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildKpiCard(
                                  title: 'Subjects At Risk',
                                  value: '${summary.atRiskCount + summary.likelyToMissCount}',
                                  subtitle: '${summary.likelyToMissCount} Miss Exam Target',
                                  icon: Icons.warning_amber_rounded,
                                  color: (summary.atRiskCount + summary.likelyToMissCount > 0) ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildKpiCard(
                                  title: 'Upcoming Examinations',
                                  value: '${summary.upcomingExamsCount}',
                                  subtitle: 'Exam Deadlines Active',
                                  icon: Icons.event_available,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                          const SizedBox(height: 24),

                          // Continuous Adaptive Recommendations (if any)
                          if (summary.adaptiveRecommendations.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: Color(0xFFB45309)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Continuous Adaptive Timetable Recommendations',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'EduPulse AI detected subjects falling behind schedule. Applying the recommended period calibrations will restore required buffer before upcoming examinations.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                                  ),
                                  const SizedBox(height: 16),
                                  ...summary.adaptiveRecommendations.map((rec) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '+${rec.periodsDifference} Period/Wk',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('${rec.className} • ${rec.subjectName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text(rec.rationale, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F766E),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            ),
                                            icon: const Icon(Icons.tune, size: 14),
                                            label: const Text('Calibrate in Timetable'),
                                            onPressed: () {
                                              context.push('${AppRoutes.timetables}?class_id=${rec.classId}&section_id=${rec.sectionId ?? ''}');
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Two Column Section: Class Breakdown & At-Risk Subjects
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Class-by-Class Breakdown
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Class-by-Class Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          Icon(Icons.bar_chart, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (summary.classSummaries.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Center(child: Text('No class records available.', style: TextStyle(color: Color(0xFF64748B)))),
                                        )
                                      else
                                        ...summary.classSummaries.map((cls) {
                                          final pct = (cls['completion_percentage'] as num?)?.toDouble() ?? 0.0;
                                          final atRisk = (cls['at_risk_count'] as num?)?.toInt() ?? 0;
                                          final totalSub = (cls['total_subjects'] as num?)?.toInt() ?? 0;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(cls['class_name'] as String? ?? 'Class', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E))),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: pct / 100.0,
                                                    backgroundColor: const Color(0xFFE2E8F0),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      pct >= 70 ? const Color(0xFF10B981) : (pct >= 40 ? const Color(0xFF0F766E) : const Color(0xFFF59E0B)),
                                                    ),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('$totalSub Tracked Subjects', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                    if (atRisk > 0)
                                                      Text('$atRisk At Risk', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)))
                                                    else
                                                      const Text('All On Track', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Right: At-Risk Subjects & Completion Prediction Cards
                              Expanded(
                                flex: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('At-Risk Subjects & Pace Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          Icon(Icons.radar, color: Color(0xFFEF4444)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (summary.atRiskSubjects.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          alignment: Alignment.center,
                                          child: const Column(
                                            children: [
                                              Icon(Icons.task_alt, size: 40, color: Color(0xFF10B981)),
                                              SizedBox(height: 8),
                                              Text('No Subjects Currently At Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              SizedBox(height: 4),
                                              Text('All subjects are pacing according to syllabus workload and upcoming exam schedules.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        )
                                      else
                                        ...summary.atRiskSubjects.map((sub) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF5F5),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFFED7D7)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('${sub.className} • ${sub.subjectName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B))),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: sub.riskBadgeColor,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(sub.riskLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                if (sub.teacherName != null)
                                                  Text('Faculty: ${sub.teacherName}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    _buildPaceStat('Planned Pace', '${sub.plannedPace} top/wk'),
                                                    const SizedBox(width: 16),
                                                    _buildPaceStat('Actual Pace', '${sub.actualPace} top/wk', isWarning: true),
                                                    const SizedBox(width: 16),
                                                    _buildPaceStat('Completion', '${sub.completionPercentage}%'),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                if (sub.targetExamName != null)
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFFED7D7)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.alarm, size: 14, color: Color(0xFFEF4444)),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            '${sub.targetExamName}: ${sub.targetExamDate ?? ''} (${sub.daysUntilExam ?? 0} days remaining). Projected finish: ${sub.projectedCompletionDate ?? 'N/A'}.',
                                                            style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F766E),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                    icon: const Icon(Icons.psychology_alt, size: 14),
                                                    label: const Text('Cross-Teacher Recovery AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (ctx) => CrossTeacherRecoveryDialog(
                                                          schoolId: schoolId,
                                                          academicYearId: _selectedAyId!,
                                                          classId: sub.classId,
                                                          sectionId: sub.sectionId ?? '',
                                                          className: sub.className,
                                                          sectionName: sub.sectionName ?? '',
                                                          subjectId: sub.subjectId,
                                                          subjectName: sub.subjectName,
                                                          currentCompletion: sub.completionPercentage,
                                                        ),
                                                      ).then((_) {
                                                        ref.invalidate(academicPlanningSummaryProvider((
                                                          schoolId: schoolId,
                                                          academicYearId: _selectedAyId!,
                                                        )));
                                                      });
                                                    },
                                                  ),
                                                ),
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
                          const SizedBox(height: 24),
                          // 4. Recovery & Calibrated Timetable Analytics
                          Consumer(
                            builder: (context, ref, _) {
                              final analyticsAsync = ref.watch(recoveryAnalyticsProvider((
                                schoolId: schoolId,
                                academicYearId: _selectedAyId!,
                              )));
                              return analyticsAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (analytics) => _buildRecoveryAnalyticsSection(analytics),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? progressValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          if (progressValue != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceStat(String label, String value, {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildRecoveryAnalyticsSection(RecoveryAnalyticsSummaryModel analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Color(0xFF0F766E), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Academic Delivery & Recovery Analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  '${analytics.activeRecoveryPlansCount} Active Plans • ${analytics.completedRecoveryPlansCount} Recovered',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsMetric(
                  'Normal Teaching',
                  '${analytics.totalNormalTeachingPeriods}',
                  'Regular Timetable Slots',
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetric(
                  'Recovery Teaching',
                  '${analytics.totalRecoveryTeachingPeriods}',
                  'Remedial / Extra Periods',
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetric(
                  'Cross-Teacher Support',
                  '${analytics.totalCrossTeacherSupportPeriods}',
                  'Peer Faculty Assisted',
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetric(
                  'Absence Recovery',
                  '${analytics.totalAbsenceRecoveryPeriods}',
                  'Substitute / Leave Cover',
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String count, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 6),
          Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
