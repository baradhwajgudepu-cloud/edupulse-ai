import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import '../providers/ai_intelligence_providers.dart';
import '../widgets/ai_components.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

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
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.purple, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'School Intelligence Command Center',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(aiIntelligenceSummaryProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Analytics'),
                ),
              ],
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

            // Scoping Filters
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Academic Year Filter
                    if (academicYearsState != null)
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          value: filters.academicYearId,
                          decoration: const InputDecoration(labelText: 'Academic Year', isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Academic Years')),
                            ...academicYearsState.years.map<DropdownMenuItem<String>>((AcademicYearDto ay) => DropdownMenuItem<String>(value: ay.id, child: Text(ay.name))),
                          ],
                          onChanged: (val) => ref.read(aiFiltersProvider.notifier).setAcademicYear(val),
                        ),
                      ),

                    // Class Filter
                    if (classesState != null)
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: filters.classId,
                          decoration: const InputDecoration(labelText: 'Class', isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                            ...classesState.classes.map<DropdownMenuItem<String>>((ClassDto c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => ref.read(aiFiltersProvider.notifier).setClass(val),
                        ),
                      ),

                    // Section Filter
                    if (filters.classId != null)
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: filters.sectionId,
                          decoration: const InputDecoration(labelText: 'Section', isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                            ...classSections.map<DropdownMenuItem<String>>((SectionDto s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name))),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPerformanceTrendsSection(context, summary, theme)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildSubjectDifficultySection(context, summary, theme)),
                      ],
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Academic Risk Radar (${riskList.length} Flagged Students)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                            Row(
                              children: [
                                Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Text(
                                  '(${student.className} - ${student.sectionName})',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                const Spacer(),
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
                Text(
                  'Performance Trend Intelligence',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildSubjectDifficultySection(BuildContext context, summary, ThemeData theme) {
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
              children: [
                const Icon(Icons.psychology, color: Colors.deepOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Subject Difficulty Analysis',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, idx) {
                  final s = subjects[idx];
                  final isHigh = s.difficultyIndex == 'HIGH';

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${s.below50Percentage}% scored below 50%', style: TextStyle(fontSize: 11, color: isHigh ? Colors.red : Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(s.difficultyIndex, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.blue)),
                        backgroundColor: isHigh ? Colors.red.shade50 : Colors.blue.shade50,
                        visualDensity: VisualDensity.compact,
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
                Text(
                  'Marks Anomaly & Statistical Variance Detection',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
