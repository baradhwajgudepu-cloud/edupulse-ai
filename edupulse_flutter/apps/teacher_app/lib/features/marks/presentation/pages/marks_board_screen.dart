import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../domain/entities/student_mark_entity.dart';
import '../../domain/repositories/marks_repository.dart';
import '../providers/marks_providers.dart';
import '../widgets/student_score_row.dart';
import '../widgets/marks_summary_card.dart';
import '../widgets/marks_validation_banner.dart';
import '../../../../core/router/routes.dart';

class MarksBoardScreen extends ConsumerStatefulWidget {
  final String examScheduleId;
  final String examName;
  final String subjectName;
  final String className;
  final int maxMarks;
  final int passMarks;
  final String teacherSubjectAssignmentId;

  const MarksBoardScreen({
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
  ConsumerState<MarksBoardScreen> createState() => _MarksBoardScreenState();
}

class _MarksBoardScreenState extends ConsumerState<MarksBoardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final state = ref.watch(marksWizardProvider(widget.examScheduleId));
    final remarksTemplatesAsync = ref.watch(remarksTemplatesProvider);

    final remarksTemplates = remarksTemplatesAsync.value ?? [];

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.examName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.examName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${state.errorMessage}', style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(marksWizardProvider(widget.examScheduleId).notifier).loadWizardData(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter and Sort entries
    final entries = state.wizardData?.entries ?? [];
    final filteredEntries = entries.where((entry) {
      final q = state.searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return entry.student.fullName.toLowerCase().contains(q) ||
          entry.student.rollNumber.toLowerCase().contains(q);
    }).toList();

    filteredEntries.sort((a, b) {
      final rollA = int.tryParse(a.student.rollNumber) ?? 999999;
      final rollB = int.tryParse(b.student.rollNumber) ?? 999999;
      return rollA.compareTo(rollB);
    });

    // Check if locked
    final isLocked = entries.isNotEmpty &&
        entries.any((e) => e.markRecord != null && e.markRecord!.status == MarksStatus.LOCKED);

    // Calculate live summary stats from localDrafts
    final drafts = state.localDrafts;
    final total = drafts.length;
    var entered = 0;
    var present = 0;
    var absent = 0;
    var exempt = 0;
    var malp = 0;
    var scoreSum = 0.0;
    var presentWithScoreCount = 0;

    drafts.forEach((studentId, mark) {
      if (mark.resultStatus != ExamResult.PRESENT || mark.marksObtained != null) {
        entered++;
      }
      switch (mark.resultStatus) {
        case ExamResult.PRESENT:
          present++;
          if (mark.marksObtained != null) {
            scoreSum += mark.marksObtained!;
            presentWithScoreCount++;
          }
          break;
        case ExamResult.ABSENT:
          absent++;
          break;
        case ExamResult.EXEMPTED:
          exempt++;
          break;
        case ExamResult.MALPRACTICE:
          malp++;
          break;
      }
    });

    final missing = total - entered;
    final average = presentWithScoreCount > 0 ? (scoreSum / presentWithScoreCount) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.examName} - ${widget.subjectName}'),
        actions: [
          if (state.saveStatusText != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  state.saveStatusText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: state.hasSaveError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header details
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.className,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Max Marks: ${widget.maxMarks}  |  Pass Marks: ${widget.passMarks}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LOCKED',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EDITABLE',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

          // Validation banner
          MarksValidationBanner(validationErrors: state.validationErrors),

          // Summary Card
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: MarksSummaryCard(
              totalStudents: total,
              enteredCount: entered,
              missingCount: missing,
              presentCount: present,
              absentCount: absent,
              malpracticeCount: malp,
              exemptedCount: exempt,
              averageScore: average,
              maxMarks: widget.maxMarks,
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search student by name or roll number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(marksWizardProvider(widget.examScheduleId).notifier).updateSearchQuery('');
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                ref.read(marksWizardProvider(widget.examScheduleId).notifier).updateSearchQuery(val);
                setState(() {});
              },
            ),
          ),

          // Student Rows List
          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final studentId = entry.student.id;
                      final currentInput = state.localDrafts[studentId] ??
                          SingleMarkInput(
                            studentId: studentId,
                            resultStatus: ExamResult.PRESENT,
                          );

                      return StudentScoreRow(
                        student: entry.student,
                        currentInput: currentInput,
                        errorMessage: state.validationErrors[studentId],
                        maxMarks: widget.maxMarks,
                        isLocked: isLocked,
                        remarksTemplates: remarksTemplates,
                        onChanged: (newInput) {
                          ref
                              .read(marksWizardProvider(widget.examScheduleId).notifier)
                              .updateMark(
                                studentId,
                                marksObtained: newInput.marksObtained,
                                resultStatus: newInput.resultStatus,
                                remarks: newInput.remarks,
                                maxMarks: widget.maxMarks,
                              );
                        },
                      );
                    },
                  ),
          ),

          // Bottom actions bar
          if (!isLocked)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Draft'),
                        onPressed: state.isSaving
                            ? null
                            : () => ref
                                .read(marksWizardProvider(widget.examScheduleId).notifier)
                                .saveDraft(
                                  teacherSubjectAssignmentId: widget.teacherSubjectAssignmentId,
                                  autosave: false,
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Review & Publish'),
                        onPressed: state.validationErrors.isNotEmpty
                            ? null
                            : () {
                                context.push(
                                  '${AppRoutes.marksReview}?examScheduleId=${widget.examScheduleId}&examName=${Uri.encodeComponent(widget.examName)}&subjectName=${Uri.encodeComponent(widget.subjectName)}&className=${Uri.encodeComponent(widget.className)}&maxMarks=${widget.maxMarks}&passMarks=${widget.passMarks}&teacherSubjectAssignmentId=${widget.teacherSubjectAssignmentId}',
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
