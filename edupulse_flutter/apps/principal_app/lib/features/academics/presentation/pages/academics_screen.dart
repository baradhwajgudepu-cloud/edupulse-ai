import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/academic_provider.dart';
import '../../data/models/academic_models.dart';
import '../widgets/syllabus_recovery_widgets.dart';

class AcademicsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool? showAppBar;

  const AcademicsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.showAppBar,
  });

  @override
  ConsumerState<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends ConsumerState<AcademicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _syllabusSubTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicStateProvider.notifier).fetchExaminations();
      ref.read(academicStateProvider.notifier).fetchAcademicHeatmap();
      ref.read(academicStateProvider.notifier).fetchRecoveryPlans();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(academicStateProvider);

    ref.listen<AcademicState>(academicStateProvider, (previous, next) {
      if (next.recoveryMessage != null && next.recoveryMessage != previous?.recoveryMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.recoveryMessage!),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    final shouldShowAppBar = widget.showAppBar ?? (Navigator.canPop(context) && widget.initialTabIndex == 1);

    Widget body = Column(
      children: [
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D9488),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF0D9488),
            tabs: const [
              Tab(icon: Icon(Icons.assignment_rounded, size: 20), text: 'Examinations & Schedules'),
              Tab(icon: Icon(Icons.auto_stories_rounded, size: 20), text: 'Syllabus Progress & Health'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: () => ref.read(academicStateProvider.notifier).fetchExaminations(isRefresh: true),
                child: _buildExaminationsTab(context, state, spacing, radius, theme),
              ),
              _buildSyllabusTab(context, state, spacing, radius, theme),
            ],
          ),
        ),
      ],
    );

    if (shouldShowAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Academics & Syllabus Intelligence'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: body,
      );
    }

    return Scaffold(body: body);
  }

  Widget _buildSyllabusTab(
    BuildContext context,
    AcademicState state,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment<int>(
                      value: 0,
                      label: Text('Academic Heatmap'),
                      icon: Icon(Icons.grid_view_rounded, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Recovery Plans (${state.recoveryPlans.length})'),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    ),
                  ],
                  selected: {_syllabusSubTabIndex},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _syllabusSubTabIndex = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _syllabusSubTabIndex == 0
              ? AcademicHeatmapView(
                  onSwitchToRecoveryTab: () {
                    setState(() {
                      _syllabusSubTabIndex = 1;
                    });
                  },
                )
              : const RecoveryPlansListView(),
        ),
      ],
    );
  }

  Widget _buildExaminationsTab(
    BuildContext context,
    AcademicState state,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.examinations.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(spacing.lg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              SizedBox(height: spacing.sm),
              const Text('Failed to load academic records.'),
              Text(state.errorMessage!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              SizedBox(height: spacing.md),
              ElevatedButton(
                onPressed: () => ref.read(academicStateProvider.notifier).fetchExaminations(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.examinations.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          _buildAcademicHealthBanner(context, spacing, radius, theme),
          const SizedBox(height: 40),
          const Center(
            child: Column(
              children: [
                Icon(Icons.menu_book_rounded, size: 56, color: Colors.grey),
                SizedBox(height: 8),
                Text('No examinations scheduled.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: state.examinations.length + 1,
      separatorBuilder: (context, index) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAcademicHealthBanner(context, spacing, radius, theme);
        }
        final exam = state.examinations[index - 1];
        return _buildExamCard(context, exam, spacing, radius, theme);
      },
    );
  }


  Widget _buildAcademicHealthBanner(
    BuildContext context,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final state = ref.watch(academicStateProvider);
    final summary = state.planningSummary;

    final double completionPct = (summary?['school_wide_completion_pct'] as num?)?.toDouble() ?? 0.0;
    final int totalTracked = (summary?['total_subjects_tracked'] as num?)?.toInt() ?? 0;
    final int onTrack = (summary?['on_track_count'] as num?)?.toInt() ?? 0;
    final int atRisk = (summary?['at_risk_count'] as num?)?.toInt() ?? 0;
    final int likelyMiss = (summary?['likely_to_miss_count'] as num?)?.toInt() ?? 0;
    final List<dynamic> atRiskSubjects = (summary?['at_risk_subjects'] as List<dynamic>?) ?? [];
    final List<dynamic> adaptiveRecs = (summary?['adaptive_recommendations'] as List<dynamic>?) ?? [];

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: Color(0xFF0D9488), size: 22),
                  SizedBox(width: spacing.sm),
                  const Text(
                    'Academic Health & Curriculum Pacing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
              if (summary != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${completionPct.toStringAsFixed(1)}% Completed',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            'Predictive curriculum tracking correlates topic completion with examination performance. Assessment data updates across academic terms.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          if (summary != null) ...[
            SizedBox(height: spacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (completionPct / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionPct >= 70 ? const Color(0xFF10B981) : (completionPct >= 40 ? const Color(0xFF0D9488) : const Color(0xFFF59E0B)),
                ),
                minHeight: 6,
              ),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                _buildStatBadge('$totalTracked Subjects', Icons.subject, const Color(0xFF0F766E)),
                const SizedBox(width: 8),
                _buildStatBadge('$onTrack On Track', Icons.check_circle_outline, const Color(0xFF10B981)),
                if (atRisk + likelyMiss > 0) ...[
                  const SizedBox(width: 8),
                  _buildStatBadge('${atRisk + likelyMiss} At Risk', Icons.warning_amber_rounded, const Color(0xFFEF4444)),
                ],
              ],
            ),
            if (atRiskSubjects.isNotEmpty) ...[
              SizedBox(height: spacing.sm),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.radar, size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 6),
                        Text('At-Risk Subjects Pacing Alert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...atRiskSubjects.take(3).map((sub) {
                      final sMap = Map<String, dynamic>.from(sub as Map);
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• ${sMap['class_name']} ${sMap['subject_name']}: Actual pace ${sMap['actual_pace']} topics/wk vs planned ${sMap['planned_pace']}. Deadline: ${sMap['target_exam_name'] ?? 'Upcoming Exam'}.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            if (adaptiveRecs.isNotEmpty) ...[
              SizedBox(height: spacing.sm),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${adaptiveRecs.length} AI Timetable Recommendations available to calibrate teaching period quotas.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    Examination exam,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final statusColor = exam.status == 'COMPLETED'
        ? Colors.grey
        : exam.status == 'ONGOING'
            ? Colors.green
            : Colors.blue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          exam.examName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${exam.examType}'),
              Text('Duration: ${exam.startDate} to ${exam.endDate}'),
            ],
          ),
        ),
        leading: Icon(Icons.school, color: theme.colorScheme.primary),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(radius.sm),
          ),
          child: Text(
            exam.status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        children: [
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Text(
              'Subject Papers & Performance Summaries',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          if (exam.schedules.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: const Text('No subject papers scheduled for this exam.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exam.schedules.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, idx) {
                final schedule = exam.schedules[idx];
                return _buildScheduleItem(context, schedule, spacing, radius, theme);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(
    BuildContext context,
    ExamSchedule schedule,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    // Trigger marks summary loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicStateProvider.notifier).fetchSummaryForSchedule(schedule.id);
    });

    final state = ref.watch(academicStateProvider);
    final summary = state.scheduleSummaries[schedule.id];

    return Padding(
      padding: EdgeInsets.all(spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule Details Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subject ID: ${schedule.subjectId.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                schedule.examDate,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            'Time: ${schedule.startTime} - ${schedule.endTime} | Max Marks: ${schedule.maxMarks} | Pass Marks: ${schedule.passMarks}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.black54),
          ),
          
          SizedBox(height: spacing.sm),
          
          // Performance Summary Card
          if (summary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (summary.classAverage == 0.0 && summary.passPercentage == 0.0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'No marks entry details compiled for this subject paper.',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(radius.sm),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Average', '${summary.classAverage.toStringAsFixed(1)}%'),
                      _buildSummaryStat('Pass Rate', '${summary.passPercentage.toStringAsFixed(1)}%'),
                      _buildSummaryStat('Highest', '${summary.highestScore}'),
                      _buildSummaryStat('Lowest', '${summary.lowestScore}'),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Missing Entry', '${summary.missingCount}', Colors.orange),
                      _buildSummaryStat('Absent Count', '${summary.absentCount}', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
