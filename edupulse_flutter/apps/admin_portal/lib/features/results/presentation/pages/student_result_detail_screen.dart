import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/widgets/school_logo_widget.dart';
import 'package:edupulse_core/edupulse_core.dart';

class StudentResultDetailScreen extends ConsumerWidget {
  final String studentId;

  const StudentResultDetailScreen({
    super.key,
    required this.studentId,
  });

  void _showAddRemarkDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String studentId,
    required String schoolId,
    required String studentName,
    required String? currentRemark,
    required String? academicYearId,
    required String? examinationId,
  }) {
    final textController = TextEditingController(text: currentRemark ?? '');
    final templates = [
      'Demonstrates excellent conceptual understanding and consistent academic focus.',
      'Active participant in class with strong subject interest. Continues to make steady progress.',
      'Capable student with great potential. Regular revision and problem practice recommended.',
      'Consistent effort and diligent work ethic demonstrated throughout the academic term.',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Teacher Remark: $studentName', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Template Suggestions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: templates.map((tmpl) {
                      return ActionChip(
                        label: Text(
                          tmpl.length > 40 ? '${tmpl.substring(0, 40)}...' : tmpl,
                          style: const TextStyle(fontSize: 11),
                        ),
                        tooltip: tmpl,
                        onPressed: () {
                          setDialogState(() {
                            textController.text = tmpl;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Teacher Remarks',
                      hintText: 'Enter student observation and feedback...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('save_remark_and_regenerate_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save & Regenerate Report Card'),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final success = await ref
                    .read(reportCardOperationsProvider.notifier)
                    .generateSingle(
                      studentId: studentId,
                      schoolId: schoolId,
                      remarks: textController.text.trim(),
                      academicYearId: academicYearId,
                      examinationId: examinationId,
                    );
                ref.invalidate(studentResultDetailProvider(studentId));
                ref.invalidate(resultsReportCardsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Remark saved and report card regenerated!' : 'Failed to save remark.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.amber.shade800;
      case 'D':
        return Colors.orange;
      case 'E':
        return Colors.deepOrange;
      case 'N/A':
        return Colors.blueGrey;
      case 'F':
      default:
        return Colors.red;
    }
  }

  Color _getPromotionColor(String status) {
    switch (status.toUpperCase()) {
      case 'PROMOTED':
        return Colors.green;
      case 'CONDITIONALLY_PROMOTED':
        return Colors.blue;
      case 'PROMOTION_UNDER_REVIEW':
        return Colors.amber.shade800;
      case 'NOT_CONFIGURED':
        return Colors.blueGrey;
      case 'DETAINED':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(studentResultDetailProvider(studentId));
    final historyAsync = ref.watch(studentAcademicHistoryProvider(studentId));
    final reportCardsState = ref.watch(resultsReportCardsProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final schoolsState = ref.watch(schoolsListProvider);
    final SchoolDto? activeSchool = schoolsState.schools.isEmpty
        ? null
        : schoolsState.schools.firstWhere(
            (school) => school.id == selectedSchoolId,
            orElse: () => schoolsState.schools.first,
          );

    final filters = ref.watch(resultsFiltersProvider);
    final operationsState = ref.watch(reportCardOperationsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Result Details', overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          detailAsync.maybeWhen(
            data: (preview) {
              final reportCardList = reportCardsState.maybeWhen(
                data: (cards) => cards,
                orElse: () => const <ReportCardDto>[],
              );
              final hasReportCard = reportCardList.any((c) => c.studentId == studentId);
              final card = reportCardList.firstWhere(
                (c) => c.studentId == studentId,
                orElse: () => const ReportCardDto(
                  id: '',
                  verificationUuid: '',
                  status: 'NOT GENERATED',
                  pdfHistory: [],
                  tenantId: '',
                  schoolId: '',
                  academicYearId: '',
                  studentId: '',
                  aiMetrics: {},
                ),
              );

              if (isMobile) {
                if (selectedSchoolId == null) return const SizedBox.shrink();
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions',
                  onSelected: (val) async {
                    if (val == 'remark') {
                      _showAddRemarkDialog(
                        context: context,
                        ref: ref,
                        studentId: studentId,
                        schoolId: selectedSchoolId,
                        studentName: preview.studentName,
                        currentRemark: preview.teacherRemarks,
                        academicYearId: filters.academicYearId,
                        examinationId: filters.examinationId,
                      );
                    } else if (val == 'generate') {
                      final success = await ref
                          .read(reportCardOperationsProvider.notifier)
                          .generateSingle(
                            studentId: studentId,
                            schoolId: selectedSchoolId,
                            remarks: preview.teacherRemarks,
                            academicYearId: filters.academicYearId,
                            examinationId: filters.examinationId,
                          );
                      ref.invalidate(studentResultDetailProvider(studentId));
                      ref.invalidate(resultsReportCardsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Report card generated successfully!' : 'Generation failed.'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    } else if (val == 'download') {
                      await ref
                          .read(reportCardOperationsProvider.notifier)
                          .downloadPdf(
                            studentId: studentId,
                            schoolId: selectedSchoolId,
                            studentName: preview.studentName,
                          );
                    } else if (val == 'publish') {
                      if (filters.classId != null && filters.sectionId != null) {
                        final success = await ref
                            .read(reportCardOperationsProvider.notifier)
                            .publish(
                              classId: filters.classId!,
                              sectionId: filters.sectionId!,
                              schoolId: selectedSchoolId,
                            );
                        ref.invalidate(resultsReportCardsProvider);
                        ref.invalidate(studentResultDetailProvider(studentId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Report card published!' : 'Publish failed.'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'remark',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note, size: 18),
                          const SizedBox(width: 8),
                          Text(preview.teacherRemarks != null && preview.teacherRemarks!.isNotEmpty ? 'Edit Remark' : 'Add Remark'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'generate',
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          Text(hasReportCard ? 'Regenerate Card' : 'Generate Card'),
                        ],
                      ),
                    ),
                    if (hasReportCard || preview.isValid)
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 18),
                            SizedBox(width: 8),
                            Text('Download PDF'),
                          ],
                        ),
                      ),
                    if (hasReportCard && card.status != 'PUBLISHED' && filters.classId != null && filters.sectionId != null)
                      const PopupMenuItem(
                        value: 'publish',
                        child: Row(
                          children: [
                            Icon(Icons.publish, size: 18),
                            SizedBox(width: 8),
                            Text('Publish Card'),
                          ],
                        ),
                      ),
                  ],
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedSchoolId != null) ...[
                    OutlinedButton.icon(
                      key: const Key('detail_add_edit_remark_btn'),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: Text(preview.teacherRemarks != null && preview.teacherRemarks!.isNotEmpty ? 'Edit Remark' : 'Add Remark'),
                      onPressed: () => _showAddRemarkDialog(
                        context: context,
                        ref: ref,
                        studentId: studentId,
                        schoolId: selectedSchoolId,
                        studentName: preview.studentName,
                        currentRemark: preview.teacherRemarks,
                        academicYearId: filters.academicYearId,
                        examinationId: filters.examinationId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('detail_generate_report_card_btn'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                      icon: operationsState.isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(hasReportCard ? 'Regenerate Card' : 'Generate Card'),
                      onPressed: operationsState.isLoading
                          ? null
                          : () async {
                              final success = await ref
                                  .read(reportCardOperationsProvider.notifier)
                                  .generateSingle(
                                    studentId: studentId,
                                    schoolId: selectedSchoolId,
                                    remarks: preview.teacherRemarks,
                                    academicYearId: filters.academicYearId,
                                    examinationId: filters.examinationId,
                                  );
                              ref.invalidate(studentResultDetailProvider(studentId));
                              ref.invalidate(resultsReportCardsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Report card generated successfully!' : 'Generation failed.'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    if (hasReportCard || preview.isValid) ...[
                      OutlinedButton.icon(
                        key: const Key('detail_download_pdf_btn'),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download PDF'),
                        onPressed: operationsState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(reportCardOperationsProvider.notifier)
                                    .downloadPdf(
                                      studentId: studentId,
                                      schoolId: selectedSchoolId,
                                      studentName: preview.studentName,
                                    );
                              },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (hasReportCard && card.status != 'PUBLISHED' && filters.classId != null && filters.sectionId != null) ...[
                      FilledButton.icon(
                        key: const Key('detail_publish_report_card_btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.publish, size: 16),
                        label: const Text('Publish Card'),
                        onPressed: operationsState.isLoading
                            ? null
                            : () async {
                                final success = await ref
                                    .read(reportCardOperationsProvider.notifier)
                                    .publish(
                                      classId: filters.classId!,
                                      sectionId: filters.sectionId!,
                                      schoolId: selectedSchoolId,
                                    );
                                ref.invalidate(resultsReportCardsProvider);
                                ref.invalidate(studentResultDetailProvider(studentId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? 'Report card published!' : 'Publish failed.'),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(studentResultDetailProvider(studentId));
              ref.invalidate(studentAcademicHistoryProvider(studentId));
              ref.invalidate(resultsReportCardsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
        data: (preview) {
          final reportCardList = reportCardsState.maybeWhen(
            data: (cards) => cards,
            orElse: () => const <ReportCardDto>[],
          );
          ReportCardDto? reportCard;
          for (final card in reportCardList) {
            if (card.studentId == studentId) {
              reportCard = card;
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Validation Banner
                if (!preview.isValid && preview.missingReasons.isNotEmpty) ...[
                  Card(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Incomplete or Invalid Report Card Data',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...preview.missingReasons.map((reason) {
                            final lower = reason.toLowerCase();
                            final isRemark = lower.contains('remark');
                            final isSchedule = lower.contains('schedule') || lower.contains('exam');
                            final isMarks = lower.contains('mark') || lower.contains('score') || lower.contains('missing');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (isRemark && selectedSchoolId != null) ...[
                                    FilledButton.tonalIcon(
                                      key: const Key('action_add_remark_btn'),
                                      icon: const Icon(Icons.edit_note, size: 16),
                                      label: const Text('Add Remark'),
                                      onPressed: () => _showAddRemarkDialog(
                                        context: context,
                                        ref: ref,
                                        studentId: studentId,
                                        schoolId: selectedSchoolId,
                                        studentName: preview.studentName,
                                        currentRemark: preview.teacherRemarks,
                                        academicYearId: filters.academicYearId,
                                        examinationId: filters.examinationId,
                                      ),
                                    ),
                                  ] else if (isSchedule) ...[
                                    FilledButton.tonalIcon(
                                      key: const Key('action_configure_exam_btn'),
                                      icon: const Icon(Icons.settings, size: 16),
                                      label: const Text('Configure Exam'),
                                      onPressed: () => context.push(AppRoutes.examinations),
                                    ),
                                  ] else if (isMarks) ...[
                                    FilledButton.tonalIcon(
                                      key: const Key('action_manage_marks_btn'),
                                      icon: const Icon(Icons.edit_calendar, size: 16),
                                      label: const Text('Manage Marks'),
                                      onPressed: () {
                                        final qParams = <String, String>{
                                          if (filters.examinationId != null) 'exam_id': filters.examinationId!,
                                          if (filters.classId != null) 'class_id': filters.classId!,
                                          if (filters.sectionId != null) 'section_id': filters.sectionId!,
                                          if (filters.academicYearId != null) 'ay_id': filters.academicYearId!,
                                        };
                                        context.push(Uri(path: AppRoutes.marksManagement, queryParameters: qParams).toString());
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Official School Branding Header Banner
                if (activeSchool != null) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: SchoolLogoWidget(
                              schoolId: activeSchool.id,
                              logoUrl: activeSchool.logoUrl,
                              logoUpdatedAt: activeSchool.logoUpdatedAt,
                              size: 56,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        activeSchool.name,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        activeSchool.board.isNotEmpty ? activeSchool.board : 'CBSE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (activeSchool.address != null && activeSchool.address!.isNotEmpty) activeSchool.address,
                                    if (activeSchool.city != null && activeSchool.city!.isNotEmpty) activeSchool.city,
                                    if (activeSchool.state != null && activeSchool.state!.isNotEmpty) activeSchool.state,
                                  ].join(', '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (activeSchool.email.isNotEmpty || (activeSchool.phone != null && activeSchool.phone!.isNotEmpty)) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (activeSchool.email.isNotEmpty) 'Email: ${activeSchool.email}',
                                      if (activeSchool.phone != null && activeSchool.phone!.isNotEmpty) 'Phone: ${activeSchool.phone}',
                                    ].join('  |  '),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double parentWidth = constraints.maxWidth;
                    final isWide = parentWidth > 800;

                    final infoWidget = Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.face, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Student Details',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow('Student Name', preview.studentName, theme),
                            _buildInfoRow('Admission No', preview.admissionNumber, theme),
                            _buildInfoRow('Roll Number', preview.rollNumber, theme),
                            _buildInfoRow('Class Name', preview.className, theme),
                            _buildInfoRow('Section Name', preview.sectionName, theme),
                            if (preview.sectionRank != null)
                              _buildInfoRow('Section Rank', preview.sectionRank!, theme),
                            if (preview.classRank != null)
                              _buildInfoRow('Class Rank', preview.classRank!, theme),
                          ],
                        ),
                      ),
                    );

                    final isNotConfigured = preview.subjectMarks.isEmpty || preview.promotionStatus == 'NOT_CONFIGURED';

                    final summaryWidget = Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Academic Summary',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            LayoutBuilder(
                              builder: (context, boxConstraints) {
                                final double cardWidth = boxConstraints.maxWidth > 520
                                    ? (boxConstraints.maxWidth - 32) / 3
                                    : (boxConstraints.maxWidth > 320
                                        ? (boxConstraints.maxWidth - 16) / 2
                                        : boxConstraints.maxWidth);
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Percentage',
                                        value: isNotConfigured ? 'N/A' : '${preview.overallPercentage}%',
                                        icon: Icons.percent,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Overall Grade',
                                        value: isNotConfigured ? 'N/A' : preview.overallGrade,
                                        icon: Icons.grade,
                                        color: _getGradeColor(isNotConfigured ? 'N/A' : preview.overallGrade),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Attendance',
                                        value: '${preview.attendancePresent}/${preview.attendanceTotal} (${preview.attendancePercentage}%)',
                                        icon: Icons.calendar_today,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    if (preview.sectionRank != null)
                                      SizedBox(
                                        width: cardWidth,
                                        child: _buildSummaryCard(
                                          context,
                                          label: 'Section Rank',
                                          value: preview.sectionRank!,
                                          icon: Icons.military_tech,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    if (preview.classRank != null)
                                      SizedBox(
                                        width: cardWidth,
                                        child: _buildSummaryCard(
                                          context,
                                          label: 'Class Rank',
                                          value: preview.classRank!,
                                          icon: Icons.emoji_events,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text('Promotion Status:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getPromotionColor(preview.promotionStatus).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _getPromotionColor(preview.promotionStatus)),
                                  ),
                                  child: Text(
                                    preview.promotionStatus == 'NOT_CONFIGURED'
                                        ? 'NOT CONFIGURED'
                                        : preview.promotionStatus.replaceAll('_', ' '),
                                    style: TextStyle(
                                      color: _getPromotionColor(preview.promotionStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: infoWidget),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: summaryWidget),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          infoWidget,
                          const SizedBox(height: 16),
                          summaryWidget,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Chronological History & Trends & Progression Sections from history API
                historyAsync.when(
                  data: (history) {
                    if (history.examinations.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Performance History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text('No historical examination records found for this academic year.'),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Build cross-exam subject performance mapping
                    final Map<String, Map<String, String>> subjectProgress = {};
                    final List<String> examNames = history.examinations.map((e) => e.examinationName).toList();

                    for (final exam in history.examinations) {
                      for (final sub in exam.subjectMarks) {
                        final resolvedSubj = displaySubjectName(
                          subjectName: sub.subjectName,
                          subjectCode: sub.subjectCode,
                          subjectId: sub.subjectId,
                        );
                        subjectProgress.putIfAbsent(resolvedSubj, () => {});
                        subjectProgress[resolvedSubj]![exam.examinationName] = '${sub.marksObtained?.toStringAsFixed(0) ?? 'ABS'} (${sub.grade})';
                      }
                    }
                    final List<String> subjects = subjectProgress.keys.toList()..sort();

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Trend Section
                            Text(
                              'Academic Performance Trend',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: history.examinations.map((exam) {
                                    final isNarrow = constraints.maxWidth < 520;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: isNarrow
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  exam.examinationName,
                                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(6),
                                                        child: LinearProgressIndicator(
                                                          value: exam.percentage / 100.0,
                                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                          color: theme.colorScheme.primary,
                                                          minHeight: 10,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      '${exam.percentage.toStringAsFixed(1)}%',
                                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _getGradeColor(exam.grade).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        exam.grade,
                                                        style: TextStyle(
                                                          color: _getGradeColor(exam.grade),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                SizedBox(
                                                  width: 180,
                                                  child: Text(
                                                    exam.examinationName,
                                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: LinearProgressIndicator(
                                                      value: exam.percentage / 100.0,
                                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                      color: theme.colorScheme.primary,
                                                      minHeight: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  '${exam.percentage.toStringAsFixed(1)}%',
                                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getGradeColor(exam.grade).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    exam.grade,
                                                    style: TextStyle(
                                                      color: _getGradeColor(exam.grade),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Subject Performance Matrix
                            Text(
                              'Subject Performance',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth > 32 ? constraints.maxWidth - 32 : 300),
                                    child: DataTable(
                                      columnSpacing: 24,
                                      horizontalMargin: 12,
                                      columns: [
                                        const DataColumn(
                                          label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        ...examNames.map((name) => DataColumn(
                                          label: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 160),
                                            child: Tooltip(
                                              message: name,
                                              child: Text(
                                                name,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        )),
                                      ],
                                      rows: subjects.map((subName) {
                                        final progress = subjectProgress[subName]!;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(subName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                            ...examNames.map((name) {
                                              final val = progress[name] ?? '-';
                                              return DataCell(Text(val));
                                            }),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Expandable Examination summaries
                            Text(
                              'Academic Performance History',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ...history.examinations.map((exam) {
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ExpansionTile(
                                  title: Text(
                                    exam.examinationName,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  subtitle: Text(
                                    'Total: ${exam.totalObtainedMarks.toStringAsFixed(0)} / ${exam.totalMaxMarks}  |  Percentage: ${exam.percentage}%  |  Grade: ${exam.grade}',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minWidth: constraints.maxWidth > 32 ? constraints.maxWidth - 32 : 300),
                                          child: DataTable(
                                            columnSpacing: 20,
                                            horizontalMargin: 12,
                                            columns: const [
                                              DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Max Marks', style: TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Marks Obtained', style: TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                            rows: exam.subjectMarks.map((sub) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(Text(displaySubjectName(
                                                    subjectName: sub.subjectName,
                                                    subjectCode: sub.subjectCode,
                                                    subjectId: sub.subjectId,
                                                  ))),
                                                  DataCell(Text(sub.maxMarks.toString())),
                                                  DataCell(Text(sub.marksObtained?.toString() ?? 'ABSENT')),
                                                  DataCell(Text(
                                                    sub.grade,
                                                    style: TextStyle(
                                                      color: _getGradeColor(sub.grade),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )),
                                                  DataCell(Text(sub.status)),
                                                  DataCell(Text(sub.remarks ?? '')),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Failed to load academic history', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('$err', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(studentAcademicHistoryProvider(studentId));
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Auditor Remarks Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment_outlined, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Signatures & Remarks',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          'Teacher Remarks',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.teacherRemarks ?? 'No remarks provided.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Principal Remarks',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.principalRemarks ?? 'No remarks provided.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // AI Analytics & Predictions Card
                if (reportCard != null && reportCard.aiMetrics.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI Predictive Analytics',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Risk Level', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(
                                      reportCard.aiMetrics['risk_level'] ?? 'LOW',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: (reportCard.aiMetrics['risk_level'] == 'HIGH') ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Academic Trend', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(
                                      reportCard.aiMetrics['overall_trend'] ?? 'STABLE',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: (reportCard.aiMetrics['overall_trend'] == 'IMPROVING') 
                                            ? Colors.green 
                                            : ((reportCard.aiMetrics['overall_trend'] == 'DECLINING') ? Colors.red : Colors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('AI Performance Insights', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            reportCard.aiMetrics['ai_narrative'] ?? 'Insights not computed yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading results detail: $err', style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(studentResultDetailProvider(studentId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
