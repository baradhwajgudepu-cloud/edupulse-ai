import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/academic_provider.dart';
import '../../data/models/academic_models.dart';

class AcademicsScreen extends ConsumerStatefulWidget {
  const AcademicsScreen({super.key});

  @override
  ConsumerState<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends ConsumerState<AcademicsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicStateProvider.notifier).fetchExaminations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(academicStateProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(academicStateProvider.notifier).fetchExaminations(isRefresh: true),
        child: switch (state) {
          AcademicState(:final isLoading) when isLoading =>
            const Center(child: CircularProgressIndicator()),
          AcademicState(:final errorMessage) when errorMessage != null => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(spacing.lg),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    SizedBox(height: spacing.sm),
                    const Text('Failed to load academic records.'),
                    Text(errorMessage, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    SizedBox(height: spacing.md),
                    ElevatedButton(
                      onPressed: () => ref.read(academicStateProvider.notifier).fetchExaminations(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          AcademicState(:final examinations) when examinations.isEmpty => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: 400,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: spacing.sm),
                    const Text('No examinations scheduled.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          AcademicState(:final examinations) => ListView.separated(
              padding: EdgeInsets.all(spacing.md),
              itemCount: examinations.length,
              separatorBuilder: (context, index) => SizedBox(height: spacing.md),
              itemBuilder: (context, index) {
                final exam = examinations[index];
                return _buildExamCard(context, exam, spacing, radius, theme);
              },
            ),
        },
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
