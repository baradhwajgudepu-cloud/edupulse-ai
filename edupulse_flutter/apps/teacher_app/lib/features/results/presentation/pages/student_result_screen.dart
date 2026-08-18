import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

import '../../domain/entities/report_card_entity.dart';
import '../../domain/entities/report_card_preview_entity.dart';
import '../providers/results_providers.dart';
import '../../../marks/presentation/providers/marks_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/grade_badge.dart';
import '../widgets/result_status_badge.dart';

class StudentResultScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String classId;
  final String sectionId;

  const StudentResultScreen({
    super.key,
    required this.studentId,
    required this.classId,
    required this.sectionId,
  });

  @override
  ConsumerState<StudentResultScreen> createState() => _StudentResultScreenState();
}

class _StudentResultScreenState extends ConsumerState<StudentResultScreen> {
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull ?? '' : '';
      ref
          .read(studentResultPreviewProvider(widget.studentId).notifier)
          .fetchPreviewAndReportCard(
            studentId: widget.studentId,
            schoolId: schoolId,
            classId: widget.classId,
            sectionId: widget.sectionId,
          )
          .then((_) {
        final state = ref.read(studentResultPreviewProvider(widget.studentId));
        if (state.preview != null) {
          _remarksController.text = state.teacherRemarks ?? '';
        }
      });
    });
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final authState = ref.watch(authStateProvider);
    final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull ?? '' : '';

    final state = ref.watch(studentResultPreviewProvider(widget.studentId));
    final remarksTemplatesAsync = ref.watch(remarksTemplatesProvider);
    final remarksTemplates = remarksTemplatesAsync.value ?? [];

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Result')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.preview == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Result')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading results: ${state.error}', style: TextStyle(color: theme.colorScheme.error)),
              SizedBox(height: spacing.md),
              ElevatedButton(
                onPressed: () {
                  ref.read(studentResultPreviewProvider(widget.studentId).notifier).fetchPreviewAndReportCard(
                        studentId: widget.studentId,
                        schoolId: schoolId,
                        classId: widget.classId,
                        sectionId: widget.sectionId,
                      );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final preview = state.preview!;
    final card = state.reportCard;
    final isLocked = card != null &&
        (card.status == ReportCardStatus.UNDER_REVIEW ||
            card.status == ReportCardStatus.APPROVED ||
            card.status == ReportCardStatus.PUBLISHED ||
            card.status == ReportCardStatus.LOCKED ||
            card.status == ReportCardStatus.ARCHIVED);

    return Scaffold(
      appBar: AppBar(
        title: Text(preview.studentName),
        actions: [
          if (card != null && card.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _handlePDFDownload(preview.studentName, card.pdfUrl!),
              tooltip: 'Download PDF Report Card',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Profile details
            _buildProfileCard(preview, card, theme, spacing, radius),
            SizedBox(height: spacing.md),

            // Incomplete/missing reasons banner
            if (!preview.isValid) _buildValidationBanner(preview.missingReasons, theme, spacing, radius),
            if (!preview.isValid) SizedBox(height: spacing.md),

            // Subject marks grid list
            _buildMarksTable(preview.subjectMarks, theme, spacing, radius),
            SizedBox(height: spacing.lg),

            // Teacher Remarks editing card
            _buildRemarksCard(isLocked, remarksTemplates, theme, spacing, radius),
            SizedBox(height: spacing.lg),

            // Action triggers
            if (!isLocked) ...[
              ElevatedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () => _handleGenerateDraft(schoolId, widget.classId, widget.sectionId),
                icon: const Icon(Icons.save_rounded),
                label: Text(card == null ? 'Generate Report Card' : 'Save Remarks / Update Draft'),
              ),
              SizedBox(height: spacing.sm),
              if (card != null)
                OutlinedButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => _handleSubmitForReview(schoolId, widget.classId, widget.sectionId),
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Text('Submit Report Card for Review'),
                ),
            ] else
              Container(
                padding: EdgeInsets.all(spacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(radius.sm),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: theme.colorScheme.primary),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        'This report card status is currently ${card.status.name}. It has been frozen and is read-only.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    ReportCardPreviewEntity preview,
    ReportCardEntity? card,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Roll No: ${preview.rollNumber}', style: theme.textTheme.labelMedium),
                    Text(
                      preview.studentName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text('Adm: ${preview.admissionNumber} • Grade ${preview.className} (${preview.sectionName})',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
                if (card != null) ResultStatusBadge(status: card.status.name),
              ],
            ),
            Divider(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(theme, 'Overall', '${preview.overallPercentage.toStringAsFixed(1)}%'),
                _buildSummaryStat(theme, 'Grade', preview.overallGrade),
                _buildSummaryStat(theme, 'Attendance', '${preview.attendancePercentage.toStringAsFixed(1)}%'),
                _buildSummaryStat(theme, 'Promotion', preview.promotionStatus.replaceAll('_', ' ')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildValidationBanner(
    List<String> missingReasons,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              SizedBox(width: spacing.sm),
              Text(
                'Missing Data Warnings',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          ...missingReasons.map(
            (reason) => Text(
              '• $reason',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTable(
    List<ReportCardSubjectMarkRowEntity> subjectMarks,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Text(
              'Subject Performance',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          DataTable(
            columnSpacing: spacing.sm,
            horizontalMargin: spacing.md,
            columns: const [
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Max')),
              DataColumn(label: Text('Marks')),
              DataColumn(label: Text('Grade')),
              DataColumn(label: Text('Status')),
            ],
            rows: subjectMarks.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(row.maximumMarks.toString())),
                  DataCell(Text(row.marksObtained != null ? row.marksObtained!.toStringAsFixed(1) : '-')),
                  DataCell(GradeBadge(grade: row.grade)),
                  DataCell(ResultStatusBadge(status: row.resultStatus)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksCard(
    bool isLocked,
    List<String> templates,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
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
            Text('Teacher Remarks', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.sm),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                hintText: 'Enter student overall comments...',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              readOnly: isLocked,
              onChanged: (val) {
                ref.read(studentResultPreviewProvider(widget.studentId).notifier).updateRemarks(val);
              },
            ),
            if (!isLocked && templates.isNotEmpty) ...[
              SizedBox(height: spacing.sm),
              Text('Suggestions:', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final temp = templates[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text(temp),
                        onPressed: () {
                          setState(() {
                            _remarksController.text = temp;
                          });
                          ref.read(studentResultPreviewProvider(widget.studentId).notifier).updateRemarks(temp);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerateDraft(String schoolId, String classId, String sectionId) async {
    final success = await ref.read(studentResultPreviewProvider(widget.studentId).notifier).generateDraft(
          studentId: widget.studentId,
          schoolId: schoolId,
          classId: classId,
          sectionId: sectionId,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report card draft updated successfully!')),
        );
      } else {
        final state = ref.read(studentResultPreviewProvider(widget.studentId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${state.error ?? "Please ensure all subject marks are entered."}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmitForReview(String schoolId, String classId, String sectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit for Review?'),
          content: const Text(
            'Once submitted, you will not be able to edit this report card unless it is unlocked by the administrator.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await ref.read(studentResultPreviewProvider(widget.studentId).notifier).submitReview(
            schoolId: schoolId,
            classId: classId,
            sectionId: sectionId,
          );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report card submitted for review!')),
          );
        } else {
          final state = ref.read(studentResultPreviewProvider(widget.studentId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit: ${state.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _handlePDFDownload(String studentName, String pdfUrl) {
    // Construct base client url using baseline configurations or window location
    final fullUrl = 'http://127.0.0.1:8000$pdfUrl';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Card PDF ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF document for $studentName has been compiled.'),
            const SizedBox(height: 8),
            const Text('Download Link:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(
              fullUrl,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
