import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../domain/entities/result_summary_entity.dart';

class ResultSummaryCard extends StatelessWidget {
  final ResultSummaryEntity summary;

  const ResultSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Examination Performance Statistics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: spacing.md,
              mainAxisSpacing: spacing.md,
              children: [
                _buildStatItem(
                  theme,
                  spacing,
                  'Class Average',
                  '${summary.classAverage.toStringAsFixed(1)}%',
                  Icons.analytics_rounded,
                  theme.colorScheme.primary,
                ),
                _buildStatItem(
                  theme,
                  spacing,
                  'Pass Rate',
                  '${summary.passPercentage.toStringAsFixed(1)}%',
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
                _buildStatItem(
                  theme,
                  spacing,
                  'Highest Score',
                  summary.highestScore.toStringAsFixed(1),
                  Icons.trending_up_rounded,
                  Colors.purple,
                ),
                _buildStatItem(
                  theme,
                  spacing,
                  'Lowest Score',
                  summary.lowestScore.toStringAsFixed(1),
                  Icons.trending_down_rounded,
                  Colors.red,
                ),
                _buildStatItem(
                  theme,
                  spacing,
                  'Missing Marks',
                  summary.missingCount.toString(),
                  Icons.pending_actions_rounded,
                  Colors.orange,
                ),
                _buildStatItem(
                  theme,
                  spacing,
                  'Absent Students',
                  summary.absentCount.toString(),
                  Icons.person_off_rounded,
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    AppSpacing spacing,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
