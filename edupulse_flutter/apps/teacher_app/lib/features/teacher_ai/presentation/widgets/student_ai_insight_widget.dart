import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../presentation/providers/teacher_ai_provider.dart';

class StudentAiInsightWidget extends ConsumerWidget {
  final String studentId;

  const StudentAiInsightWidget({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final state = ref.watch(studentInsightNotifierProvider(studentId));

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '✨ EduPulse AI Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (state is StudentInsightSuccess)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Regenerate',
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      ref.read(studentInsightNotifierProvider(studentId).notifier)
                          .fetchStudentInsight(studentId: studentId);
                    },
                  ),
              ],
            ),
            SizedBox(height: spacing.sm),
            switch (state) {
              StudentInsightInitial() => _buildInitialView(context, ref),
              StudentInsightLoading() => _buildLoadingView(theme, spacing),
              StudentInsightSuccess(:final insight) => _buildSuccessView(insight, theme, spacing, radius, ref),
              StudentInsightError(:final message) => _buildErrorView(message, theme, spacing, ref),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Column(
      children: [
        Text(
          'Get automated academic remarks, performance analysis, and improvement suggestions for this student.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.md),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(studentInsightNotifierProvider(studentId).notifier)
                .fetchStudentInsight(studentId: studentId);
          },
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate Student Insight'),
        ),
      ],
    );
  }

  Widget _buildLoadingView(ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.lg),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: spacing.md),
          Text(
            'Analyzing performance history, marks, and attendance...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(
    dynamic insight,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Performance & Attendance Trend Rows
        _buildTrendChip(
          label: 'Academic Trend',
          value: insight.performanceTrend,
          icon: Icons.trending_up_rounded,
          color: Colors.green,
          theme: theme,
          spacing: spacing,
          radius: radius,
        ),
        SizedBox(height: spacing.xs),
        _buildTrendChip(
          label: 'Attendance Trend',
          value: insight.attendanceTrend,
          icon: Icons.calendar_today_rounded,
          color: Colors.blue,
          theme: theme,
          spacing: spacing,
          radius: radius,
        ),
        if (insight.recentAcademicChanges != null && insight.recentAcademicChanges!.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          _buildTrendChip(
            label: 'Recent Changes',
            value: insight.recentAcademicChanges!,
            icon: Icons.notification_important_rounded,
            color: Colors.orange,
            theme: theme,
            spacing: spacing,
            radius: radius,
          ),
        ],
        SizedBox(height: spacing.md),

        // Summary
        Text(
          'Summary',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: spacing.xs),
        Text(
          insight.summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.md),

        // Improvement Areas
        if (insight.improvementAreas.isNotEmpty) ...[
          Text(
            'Key Areas for Improvement',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          ...insight.improvementAreas.map((area) => _buildBulletPoint(area, theme, spacing)),
          SizedBox(height: spacing.md),
        ],

        // Attention Areas
        if (insight.attentionAreas.isNotEmpty) ...[
          Text(
            'Attention Required',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
          SizedBox(height: spacing.xs),
          ...insight.attentionAreas.map((area) => _buildBulletPoint(area, theme, spacing, isWarning: true)),
          SizedBox(height: spacing.md),
        ],

        // Suggested Actions
        if (insight.suggestedActions.isNotEmpty) ...[
          Text(
            'Recommended Teacher Actions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal[800],
            ),
          ),
          SizedBox(height: spacing.xs),
          ...insight.suggestedActions.asMap().entries.map((entry) =>
              _buildNumberedPoint(entry.key + 1, entry.value, theme, spacing)),
        ],
      ],
    );
  }

  Widget _buildErrorView(String message, ThemeData theme, AppSpacing spacing, WidgetRef ref) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 36),
        SizedBox(height: spacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        SizedBox(height: spacing.md),
        ElevatedButton(
          onPressed: () {
            ref.read(studentInsightNotifierProvider(studentId).notifier)
                .fetchStudentInsight(studentId: studentId);
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildTrendChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required AppSpacing spacing,
    required AppRadius radius,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: spacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, ThemeData theme, AppSpacing spacing, {bool isWarning = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.fiber_manual_record,
            size: isWarning ? 14 : 8,
            color: isWarning ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint(int number, String text, ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
