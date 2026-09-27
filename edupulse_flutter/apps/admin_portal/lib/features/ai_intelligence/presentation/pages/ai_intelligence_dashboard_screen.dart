// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/ai_intelligence_models.dart';
import '../providers/ai_intelligence_providers.dart';
import '../widgets/ai_components.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AIIntelligenceDashboardScreen extends ConsumerStatefulWidget {
  const AIIntelligenceDashboardScreen({super.key});

  @override
  ConsumerState<AIIntelligenceDashboardScreen> createState() => _AIIntelligenceDashboardScreenState();
}

class _AIIntelligenceDashboardScreenState extends ConsumerState<AIIntelligenceDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(aiIntelligenceSummaryProvider);
    final filters = ref.watch(aiFiltersProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    final academicYearsState = schoolId.isNotEmpty ? ref.watch(academicYearsProvider(schoolId)) : null;
    final classesState = schoolId.isNotEmpty ? ref.watch(classesProvider(schoolId)) : null;
    final sectionsState = schoolId.isNotEmpty ? ref.watch(sectionsProvider(schoolId)) : null;

    final List<SectionDto> classSections = filters.classId != null && sectionsState != null
        ? sectionsState.sections.where((SectionDto s) => s.classId == filters.classId).toList()
        : <SectionDto>[];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar (Responsive: Stacks on narrow screens, Expanded Row on desktop)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                final titleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.purple, size: 28),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'School Intelligence Command Center',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analytical intelligence, academic risk radars, subject difficulty indices, and anomaly detection.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                );

                final actionButton = OutlinedButton.icon(
                  onPressed: () => ref.invalidate(aiIntelligenceSummaryProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Analytics'),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      actionButton,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    actionButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Intelligence Reliability Banner
            const AIAlertBanner(
              title: 'EduPulse Intelligence Insight',
              message: 'Metrics and predictive signals are computed deterministically from published examinations, attendance ratios, and operational records.',
              icon: Icons.verified_user_outlined,
              color: Colors.indigo,
            ),
            const SizedBox(height: 20),

            // Scoping Filters (Responsive LayoutBuilder: Proportional Row on wide, Wrap on narrow)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    if (availableWidth >= 820) {
                      // Desktop & Wide Laptop view: Clean horizontal alignment adapting to full available width
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (academicYearsState != null)
                            Expanded(
                              flex: 3,
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.academicYearId,
                                decoration: const InputDecoration(
                                  labelText: 'Academic Year',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Academic Years', overflow: TextOverflow.ellipsis)),
                                  ...academicYearsState.years.map<DropdownMenuItem<String>>((AcademicYearDto ay) =>
                                    DropdownMenuItem<String>(value: ay.id, child: Text(ay.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setAcademicYear(val),
                              ),
                            ),
                          const SizedBox(width: 12),

                          if (classesState != null)
                            Expanded(
                              flex: 2,
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.classId,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Classes', overflow: TextOverflow.ellipsis)),
                                  ...classesState.classes.map<DropdownMenuItem<String>>((ClassDto c) =>
                                    DropdownMenuItem<String>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setClass(val),
                              ),
                            ),

                          if (filters.classId != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.sectionId,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Sections', overflow: TextOverflow.ellipsis)),
                                  ...classSections.map<DropdownMenuItem<String>>((SectionDto s) =>
                                    DropdownMenuItem<String>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setSection(val),
                              ),
                            ),
                          ],

                          const SizedBox(width: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Reset Filters'),
                            onPressed: () => ref.read(aiFiltersProvider.notifier).reset(),
                          ),
                        ],
                      );
                    } else {
                      // Narrow & Tablet view: Gracefully wrapped without horizontal overflows
                      final itemWidth = (availableWidth - 16) / 2 > 170 ? (availableWidth - 16) / 2 : availableWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (academicYearsState != null)
                            SizedBox(
                              width: itemWidth.clamp(170.0, 260.0),
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.academicYearId,
                                decoration: const InputDecoration(labelText: 'Academic Year', isDense: true, border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Academic Years', overflow: TextOverflow.ellipsis)),
                                  ...academicYearsState.years.map<DropdownMenuItem<String>>((AcademicYearDto ay) =>
                                    DropdownMenuItem<String>(value: ay.id, child: Text(ay.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setAcademicYear(val),
                              ),
                            ),

                          if (classesState != null)
                            SizedBox(
                              width: itemWidth.clamp(150.0, 220.0),
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.classId,
                                decoration: const InputDecoration(labelText: 'Class', isDense: true, border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Classes', overflow: TextOverflow.ellipsis)),
                                  ...classesState.classes.map<DropdownMenuItem<String>>((ClassDto c) =>
                                    DropdownMenuItem<String>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setClass(val),
                              ),
                            ),

                          if (filters.classId != null)
                            SizedBox(
                              width: itemWidth.clamp(150.0, 220.0),
                              child: SafeDropdownButtonFormField<String>(
                                isExpanded: true,
                                value: filters.sectionId,
                                decoration: const InputDecoration(labelText: 'Section', isDense: true, border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Sections', overflow: TextOverflow.ellipsis)),
                                  ...classSections.map<DropdownMenuItem<String>>((SectionDto s) =>
                                    DropdownMenuItem<String>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) => ref.read(aiFiltersProvider.notifier).setSection(val),
                              ),
                            ),

                          TextButton.icon(
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Reset Filters'),
                            onPressed: () => ref.read(aiFiltersProvider.notifier).reset(),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Async Body
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Evaluating school intelligence metrics...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Failed to load AI Intelligence: ${err.toString()}', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(aiIntelligenceSummaryProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (summary) {
                if (summary == null) {
                  return const Center(child: Text('No analytical intelligence data available.'));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: School Academic Health Score & Executive Narrative
                    _buildHealthScoreSection(context, summary, theme),
                    const SizedBox(height: 28),

                    // Section 2: Academic Risk Radar
                    _buildRiskRadarSection(context, summary, theme),
                    const SizedBox(height: 28),

                    // Section 3: Performance Trend Intelligence & Subject Difficulty
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 920) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPerformanceTrendsSection(context, summary, theme),
                              const SizedBox(height: 20),
                              _buildSubjectDifficultySection(
                                context,
                                summary,
                                theme,
                                filters,
                                academicYearsState,
                                classesState,
                                classSections,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPerformanceTrendsSection(context, summary, theme)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildSubjectDifficultySection(
                                context,
                                summary,
                                theme,
                                filters,
                                academicYearsState,
                                classesState,
                                classSections,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Section 4: Marks Anomaly Detection
                    _buildMarksAnomaliesSection(context, summary, theme),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreSection(BuildContext context, summary, ThemeData theme) {
    final healthScore = summary.schoolHealthScore;
    final sub = summary.subScores;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$healthScore',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Academic Health Index (Score $healthScore / 100)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.aiExecutiveSummary,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Sub-scores Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSubScorePill('Academic Performance', '${sub.academicPerformance.score}%', sub.academicPerformance.status),
                _buildSubScorePill('Attendance Correlation', '${sub.attendanceCorrelation.score}%', sub.attendanceCorrelation.status),
                _buildSubScorePill('Subject Difficulty', '${sub.subjectDifficulty.score}/100', sub.subjectDifficulty.status),
                _buildSubScorePill('Marks Completion', '${sub.marksCompletion.score}%', sub.marksCompletion.status),
                _buildSubScorePill('Exam Readiness', '${sub.examReadiness.score}%', sub.examReadiness.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubScorePill(String label, String value, String status) {
    Color color;
    if (status == 'STRONG' || status == 'HEALTHY' || status == 'READY') {
      color = Colors.green;
    } else if (status == 'MODERATE') {
      color = Colors.amber.shade800;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildRiskRadarSection(BuildContext context, summary, ThemeData theme) {
    final riskList = summary.academicRiskRadar;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Academic Risk Radar (${riskList.length} Flagged Students)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    '${riskList.where((r) => r.riskTier == "HIGH").length} High Risk',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  backgroundColor: Colors.red.shade50,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (riskList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
                    SizedBox(height: 8),
                    Text('No students are currently flagged as high or medium risk.', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: riskList.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (context, idx) {
                  final student = riskList[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: student.riskTier == 'HIGH' ? Colors.red.shade100 : Colors.amber.shade100,
                        child: Icon(
                          student.riskTier == 'HIGH' ? Icons.crisis_alert : Icons.warning_amber,
                          color: student.riskTier == 'HIGH' ? Colors.red : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '(${student.className} - ${student.sectionName})',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                AIRiskBadge(tier: student.riskTier, confidenceScore: student.confidenceScore),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Academic Average: ${student.academicPercentage}% | Failing Subjects: ${student.failedSubjectsCount}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AI Recommendation: ${student.recommendedIntervention}',
                              style: TextStyle(fontSize: 12, color: Colors.purple.shade900, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          context.push('/results/students/${student.studentId}');
                        },
                        child: const Text('View Student'),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTrendsSection(BuildContext context, summary, ThemeData theme) {
    final trends = summary.performanceTrends;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Performance Trend Intelligence',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (trends.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No chronological examination trends recorded yet.'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trends.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, idx) {
                  final t = trends[idx];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.examinationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Date: ${t.startDate}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('${t.averagePercentage}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          AITrendIndicator(direction: t.trendDirection, delta: t.deltaPercentage),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDifficultySection(
    BuildContext context,
    summary,
    ThemeData theme,
    AIFiltersState filters,
    AcademicYearsState? academicYearsState,
    ClassesState? classesState,
    List<SectionDto> classSections,
  ) {
    final subjects = summary.subjectDifficultyAnalysis;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Subject Difficulty Analysis',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${subjects.length} Subjects',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Click any subject row or badge to open difficulty details and distribution.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 14),
            if (subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subject examination records available.'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, idx) {
                  final s = subjects[idx];
                  final isHigh = s.difficultyIndex == 'HIGH';
                  final isMod = s.difficultyIndex == 'MODERATE';
                  final isWatch = s.difficultyIndex == 'WATCH';

                  final Color statusColor = isHigh
                      ? Colors.red
                      : (isMod ? Colors.deepOrange : (isWatch ? Colors.amber.shade900 : Colors.grey.shade600));

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _showSubjectDetailDialog(
                      context,
                      s,
                      filters,
                      academicYearsState,
                      classesState,
                      classSections,
                    ),
                    child: Tooltip(
                      message: 'Click to view ${s.subjectName} difficulty analysis & marks distribution',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.subjectName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.below50Percentage}% scored below 50% • Avg: ${s.averagePercentage}%',
                                    style: TextStyle(fontSize: 11, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showSubjectDetailDialog(
                                context,
                                s,
                                filters,
                                academicYearsState,
                                classesState,
                                classSections,
                              ),
                              child: _buildDifficultyBadge(s.difficultyIndex),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSubjectDetailDialog(
    BuildContext context,
    SubjectDifficultyModel subject,
    AIFiltersState filters,
    AcademicYearsState? academicYearsState,
    ClassesState? classesState,
    List<SectionDto> classSections,
  ) {
    final theme = Theme.of(context);
    final isHigh = subject.difficultyIndex == 'HIGH';
    final isMod = subject.difficultyIndex == 'MODERATE';
    final isWatch = subject.difficultyIndex == 'WATCH';

    final Color statusColor = isHigh
        ? Colors.red
        : (isMod ? Colors.deepOrange : (isWatch ? Colors.amber.shade800 : Colors.green));

    final selectedYearName = filters.academicYearId != null && academicYearsState != null
        ? academicYearsState.years.where((y) => y.id == filters.academicYearId).firstOrNull?.name ?? 'All Academic Years'
        : 'All Academic Years';

    final selectedClassName = filters.classId != null && classesState != null
        ? classesState.classes.where((c) => c.id == filters.classId).firstOrNull?.name ?? 'All Classes'
        : 'All Classes';

    final selectedSectionName = filters.sectionId != null
        ? classSections.where((s) => s.id == filters.sectionId).firstOrNull?.name ?? 'All Sections'
        : 'All Sections';

    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.psychology, color: statusColor, size: 28),
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
                                    subject.subjectName,
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _buildDifficultyBadge(subject.difficultyIndex),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildFilterScopeChip(Icons.calendar_today, selectedYearName),
                                _buildFilterScopeChip(Icons.school, selectedClassName),
                                _buildFilterScopeChip(Icons.grid_view, selectedSectionName),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Deterministic Difficulty Explanation Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: statusColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subject.difficultyExplanation.isNotEmpty
                                ? subject.difficultyExplanation
                                : '${subject.subjectName} is classified as ${subject.difficultyIndex} based on student scoring trends and academic averages.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Performance Metrics Grid
                  Text('Performance Metrics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 500;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Total Evaluated',
                            value: '${subject.totalStudentsEvaluated} Students',
                            icon: Icons.people_outline,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Average Marks',
                            value: '${subject.averagePercentage}%',
                            icon: Icons.analytics_outlined,
                            color: Colors.indigo,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Median Marks',
                            value: subject.medianPercentage != null ? '${subject.medianPercentage}%' : 'N/A',
                            icon: Icons.show_chart,
                            color: Colors.blue.shade700,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Highest Marks',
                            value: '${subject.highestPercentage}%',
                            icon: Icons.arrow_upward,
                            color: Colors.green,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Lowest Marks',
                            value: '${subject.lowestPercentage}%',
                            icon: Icons.arrow_downward,
                            color: Colors.red.shade700,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Pass Percentage',
                            value: '${subject.passPercentage}%',
                            icon: Icons.check_circle_outline,
                            color: subject.passPercentage >= 75 ? Colors.green : Colors.amber.shade900,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Students Below 50%',
                            value: '${subject.below50Count} (${subject.below50Percentage}%)',
                            icon: Icons.warning_amber_rounded,
                            color: subject.below50Percentage >= 25 ? Colors.red : Colors.grey.shade800,
                          ),
                          _buildMetricTile(
                            width: isWide ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2,
                            label: 'Difficulty Score',
                            value: '${subject.difficultyScore} / 100',
                            icon: Icons.speed,
                            color: statusColor,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Marks Distribution Breakdown
                  Text('Marks Distribution', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDistributionSection(subject.marksDistribution, subject.totalStudentsEvaluated),
                  const SizedBox(height: 20),

                  // Remedial Recommendation
                  if (subject.remedialRecommendation.isNotEmpty) ...[
                    Text('Remedial Recommendation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        subject.remedialRecommendation,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Footer Actions
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistributionSection(MarksDistributionModel dist, int total) {
    final denom = total > 0 ? total : 1;
    return Column(
      children: [
        _buildDistributionRow('90–100%', dist.score90To100, denom, Colors.green.shade600),
        const SizedBox(height: 8),
        _buildDistributionRow('75–89%', dist.score75To89, denom, Colors.teal.shade600),
        const SizedBox(height: 8),
        _buildDistributionRow('60–74%', dist.score60To74, denom, Colors.blue.shade600),
        const SizedBox(height: 8),
        _buildDistributionRow('50–59%', dist.score50To59, denom, Colors.amber.shade700),
        const SizedBox(height: 8),
        _buildDistributionRow('Below 50%', dist.scoreBelow50, denom, Colors.red.shade600),
      ],
    );
  }

  Widget _buildDistributionRow(String rangeLabel, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) * 100.0 : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            rangeLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 85,
          child: Text(
            '$count (${pct.toStringAsFixed(1)}%)',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final tileColor = color ?? Colors.grey.shade800;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: tileColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tileColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterScopeChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(String tier) {
    final upper = tier.toUpperCase();
    final isHigh = upper == 'HIGH';
    final isMod = upper == 'MODERATE';
    final isWatch = upper == 'WATCH';

    final color = isHigh
        ? Colors.red
        : (isMod ? Colors.deepOrange : (isWatch ? Colors.amber.shade900 : Colors.green.shade800));
    final bg = isHigh
        ? Colors.red.shade50
        : (isMod ? Colors.deepOrange.shade50 : (isWatch ? Colors.amber.shade50 : Colors.green.shade50));
    final border = isHigh
        ? Colors.red.shade200
        : (isMod ? Colors.deepOrange.shade200 : (isWatch ? Colors.amber.shade200 : Colors.green.shade200));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        upper,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMarksAnomaliesSection(BuildContext context, summary, ThemeData theme) {
    final anomalies = summary.marksAnomalies;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marks Anomaly & Statistical Variance Detection',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (anomalies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('No statistical grading anomalies detected across active classes.'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: anomalies.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, idx) {
                  final a = anomalies[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a.classSection} • ${a.subjectName} (Avg: ${a.averagePercentage}% | StdDev: ${a.standardDeviation})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(a.recommendedReview, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
