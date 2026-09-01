import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../providers/marks_providers.dart';
import '../../../../core/router/routes.dart';

class MarksReviewScreen extends ConsumerStatefulWidget {
  final String examScheduleId;
  final String examName;
  final String subjectName;
  final String className;
  final int maxMarks;
  final int passMarks;
  final String teacherSubjectAssignmentId;

  const MarksReviewScreen({
    super.key,
    required this.examScheduleId,
    required this.examName,
    required this.subjectName,
    required this.className,
    required this.maxMarks,
    required this.passMarks,
    required this.teacherSubjectAssignmentId,
  });

  @override
  ConsumerState<MarksReviewScreen> createState() => _MarksReviewScreenState();
}

class _MarksReviewScreenState extends ConsumerState<MarksReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marksWizardProvider(widget.examScheduleId).notifier).fetchPublishSummary();
    });
  }

  Future<void> _handlePublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Publish Marks?'),
          content: const Text(
            'Publishing marks will make the result available to parents and may send configured notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish Marks'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await ref
          .read(marksWizardProvider(widget.examScheduleId).notifier)
          .publishMarks();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marks published successfully!')),
          );
          // Go back to selection screen
          context.go(AppRoutes.marks);
        } else {
          final err = ref.read(marksWizardProvider(widget.examScheduleId)).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err != null && err.isNotEmpty ? err : 'Failed to publish marks. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final state = ref.watch(marksWizardProvider(widget.examScheduleId));
    final summary = state.publishSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Assessment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.marks);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.sm),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.examName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Subject: ${widget.subjectName}', style: theme.textTheme.bodyMedium),
                      Text('Class: ${widget.className}', style: theme.textTheme.bodyMedium),
                      Text('Max Marks: ${widget.maxMarks}  |  Pass Marks: ${widget.passMarks}',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              Text(
                'Publish Summary Validation',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing.sm),

              if (summary == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Summary Stats Table/Rows
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius.sm),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      children: [
                        _buildSummaryRow('Total Students', summary.totalStudents.toString(), theme),
                        const Divider(),
                        _buildSummaryRow('Entered Marks', summary.enteredCount.toString(), theme),
                        const Divider(),
                        _buildSummaryRow(
                          'Missing Marks',
                          summary.missingCount.toString(),
                          theme,
                          color: summary.missingCount > 0 ? Colors.red : Colors.green,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'Pass Percentage',
                          '${summary.passPercentage.toStringAsFixed(1)}%',
                          theme,
                          color: summary.passPercentage >= 35.0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.lg),

                // Warning message if missing marks exist
                if (summary.missingCount > 0) ...[
                  Container(
                    padding: EdgeInsets.all(spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(radius.sm),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Warning: There are ${summary.missingCount} student(s) with missing marks. You can publish, but these will be displayed as incomplete.',
                            style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Back to Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state.isPublishing ? null : _handlePublish,
                        child: state.isPublishing
                            ? const CircularProgressIndicator()
                            : const Text('Publish Marks'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
