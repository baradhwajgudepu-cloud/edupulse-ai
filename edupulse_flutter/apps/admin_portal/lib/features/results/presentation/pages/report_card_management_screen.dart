import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

enum ReportCardLifecycleFilter {
  all('All Students'),
  notGenerated('Not Generated'),
  draft('Draft'),
  underReview('Under Review'),
  approved('Approved'),
  published('Published'),
  locked('Locked');

  final String label;
  const ReportCardLifecycleFilter(this.label);
}

class ReportCardManagementScreen extends ConsumerStatefulWidget {
  const ReportCardManagementScreen({super.key});

  @override
  ConsumerState<ReportCardManagementScreen> createState() => _ReportCardManagementScreenState();
}

class _ReportCardManagementScreenState extends ConsumerState<ReportCardManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ReportCardLifecycleFilter _activeFilter = ReportCardLifecycleFilter.all;
  final Set<String> _selectedStudentIds = {};

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  Widget _buildCountMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      }
    });
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ReportCardLifecycleFilter filterKey,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: isSelected ? 3 : 0,
        color: isSelected ? color.withValues(alpha: 0.08) : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isSelected ? color : theme.colorScheme.outlineVariant,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withValues(alpha: 0.05),
          splashColor: color.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotGeneratedDiagnosticsDialog(StudentDto s, String className, String secName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, ref, _) {
          final detailAsync = ref.watch(studentResultDetailProvider(s.id));

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.assignment_late_outlined, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text('Report Card Status – ${s.firstName} ${s.lastName}'),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: detailAsync.when(
                data: (preview) {
                  final missingList = preview.missingReasons;
                  final hasMarks = preview.subjectMarks.isNotEmpty;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student info banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Roll No: ${s.rollNumber}  |  Adm No: ${s.admissionNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  _buildStatusBadge('NOT GENERATED'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Class: $className  •  Section: $secName',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (missingList.isNotEmpty) ...[
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Missing Examination Data:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The report card cannot be compiled until marks are entered and published for all subjects.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          ...missingList.map((reason) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.orange.shade50.withAlpha(100),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.orange.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.error_outline, color: Colors.deepOrange, size: 20),
                                title: Text(reason, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                trailing: TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.edit_note, size: 16),
                                  label: const Text('Fix in Marks →', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    context.push(AppRoutes.marksManagement);
                                  },
                                ),
                              ),
                            );
                          }),
                        ] else if (!hasMarks) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No examination marks recorded yet for this student. Please enter and publish marks in Marks Management.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'All examination marks are published and ready for report card generation!',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 28),
                      const SizedBox(height: 8),
                      Text('Unable to fetch eligibility: $err', style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Marks Management'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.push(AppRoutes.marksManagement);
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('Generate Report Card'),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final schoolId = ref.read(selectedSchoolIdProvider);
                  if (schoolId != null) {
                    final res = await ref.read(reportCardOperationsProvider.notifier).generateSingle(
                          studentId: s.id,
                          schoolId: schoolId,
                        );
                    if (res) {
                      _showActionFeedback('Report card generated successfully.');
                    } else {
                      final state = ref.read(reportCardOperationsProvider);
                      _showActionFeedback(state.error ?? 'Generation failed', isError: true);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleStudentClick(StudentDto s, ReportCardDto card, String className, String secName) {
    if (card.id.isNotEmpty && card.status.toUpperCase() != 'NOT GENERATED') {
      context.push('/results/report-cards/${s.id}');
    } else {
      _showNotGeneratedDiagnosticsDialog(s, className, secName);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'LOCKED':
        color = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        break;
      case 'PUBLISHED':
        color = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'APPROVED':
        color = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'UNDER_REVIEW':
        color = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        break;
      case 'DRAFT':
        color = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'NOT GENERATED':
      default:
        color = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showActionFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showBulkActionResultDialog(
    String title,
    dynamic result, {
    String? academicYearId,
    String? classId,
    String? sectionId,
  }) {
    final int totalCount = (result is BulkClassGenerateResponseDto)
        ? result.totalStudents
        : (result is BulkReportCardActionResponseDto ? result.totalRequested : 0);
    final int successCount = (result is BulkClassGenerateResponseDto)
        ? result.generatedCount
        : (result is BulkReportCardActionResponseDto ? result.successCount : 0);
    final int failedCount = (result is BulkClassGenerateResponseDto)
        ? result.failedCount
        : (result is BulkReportCardActionResponseDto ? result.failedCount : 0);
    final List<StudentFailureDetailDto> failures = (result is BulkClassGenerateResponseDto)
        ? result.failures
        : (result is BulkReportCardActionResponseDto ? result.failures : []);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assessment_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: failedCount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: failedCount > 0 ? Colors.amber.shade300 : Colors.green.shade300,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildCountMetric('Total Checked', '$totalCount', Colors.blueGrey),
                      _buildCountMetric('Successfully Generated: $successCount', '$successCount', Colors.green),
                      _buildCountMetric('Failed: $failedCount', '$failedCount', failedCount > 0 ? Colors.red : Colors.grey),
                    ],
                  ),
                ),
                if (failures.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.deepOrange, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Actionable Failure Details (${failures.length} Students):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...failures.map((f) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      color: Colors.red.shade50.withAlpha(120),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: Colors.black87),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${f.studentName}: ${f.reasons.join(", ")}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Colors.indigo,
                                  ),
                                  icon: const Icon(Icons.edit_note, size: 16),
                                  label: const Text('Fix in Marks →', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    final params = <String>[];
                                    if (academicYearId != null) params.add('academicYearId=$academicYearId');
                                    if (classId != null) params.add('classId=$classId');
                                    if (sectionId != null) params.add('sectionId=$sectionId');
                                    final query = params.isNotEmpty ? '?${params.join("&")}' : '';
                                    context.push('${AppRoutes.marksManagement}$query');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: f.reasons.map((reason) {
                                return Chip(
                                  avatar: const Icon(Icons.warning_amber, size: 13, color: Colors.red),
                                  label: Text(reason, style: const TextStyle(fontSize: 11, color: Colors.red)),
                                  backgroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: Colors.red.shade200),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkGenerate(String classId, String sectionId, String schoolId) async {
    final filters = ref.read(resultsFiltersProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Generate Report Cards'),
        content: const Text(
          'Are you sure you want to bulk generate report cards for the selected class and section? '
          'This will compile student grades and attendance details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(reportCardOperationsProvider.notifier);
    final success = await notifier.bulkGenerate(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
      academicYearId: filters.academicYearId,
    );

    if (success) {
      final state = ref.read(reportCardOperationsProvider);
      final result = state.bulkGenerateResult;
      _clearSelection();
      if (result != null) {
        if (!mounted) return;
        _showBulkActionResultDialog(
          'Bulk Generation Result',
          result,
          academicYearId: filters.academicYearId,
          classId: classId,
          sectionId: sectionId,
        );
      }
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk generation failed', isError: true);
    }
  }

  Future<void> _handleBulkApproveSelected(List<ReportCardDto> cards, String schoolId) async {
    final selectedCards = cards.where((c) => _selectedStudentIds.contains(c.studentId) && c.id.isNotEmpty).toList();
    if (selectedCards.isEmpty) {
      _showActionFeedback('No generated report cards selected for approval.', isError: true);
      return;
    }

    final underReviewCards = selectedCards.where((c) => c.status.toUpperCase() == 'UNDER_REVIEW').toList();
    final count = underReviewCards.isNotEmpty ? underReviewCards.length : selectedCards.length;
    final cardIds = (underReviewCards.isNotEmpty ? underReviewCards : selectedCards).map((c) => c.id).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Report Cards?'),
        content: Text(
          'You are about to approve $count report card${count == 1 ? "" : "s"}.\n\n'
          'This action will mark them as approved and ready for publishing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve $count Card${count == 1 ? "" : "s"}'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final filters = ref.read(resultsFiltersProvider);
    final notifier = ref.read(reportCardOperationsProvider.notifier);
    final success = await notifier.bulkApprove(
      reportCardIds: cardIds,
      schoolId: schoolId,
    );

    if (success) {
      final state = ref.read(reportCardOperationsProvider);
      final result = state.bulkActionResult;
      _clearSelection();
      if (result != null && result.failedCount > 0) {
        if (!mounted) return;
        _showBulkActionResultDialog(
          'Bulk Approval Result',
          result,
          academicYearId: filters.academicYearId,
          classId: filters.classId,
          sectionId: filters.sectionId,
        );
      } else {
        _showActionFeedback('$count report cards approved successfully.');
      }
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk approval failed.', isError: true);
    }
  }

  Future<void> _handleBulkPublishSelected(List<ReportCardDto> cards, String schoolId) async {
    final selectedCards = cards.where((c) => _selectedStudentIds.contains(c.studentId) && c.id.isNotEmpty).toList();
    if (selectedCards.isEmpty) {
      _showActionFeedback('No generated report cards selected for publishing.', isError: true);
      return;
    }

    final approvedCards = selectedCards.where((c) => c.status.toUpperCase() == 'APPROVED').toList();
    final count = approvedCards.isNotEmpty ? approvedCards.length : selectedCards.length;
    final cardIds = (approvedCards.isNotEmpty ? approvedCards : selectedCards).map((c) => c.id).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Report Cards?'),
        content: Text(
          'You are about to publish $count report card${count == 1 ? "" : "s"}.\n\n'
          'Once published, they will become visible to parents and students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Publish $count Card${count == 1 ? "" : "s"}'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final filters = ref.read(resultsFiltersProvider);
    final notifier = ref.read(reportCardOperationsProvider.notifier);
    final success = await notifier.bulkPublish(
      reportCardIds: cardIds,
      schoolId: schoolId,
    );

    if (success) {
      final state = ref.read(reportCardOperationsProvider);
      final result = state.bulkActionResult;
      _clearSelection();
      if (result != null && result.failedCount > 0) {
        if (!mounted) return;
        _showBulkActionResultDialog(
          'Bulk Publish Result',
          result,
          academicYearId: filters.academicYearId,
          classId: filters.classId,
          sectionId: filters.sectionId,
        );
      } else {
        _showActionFeedback('$count report cards published successfully.');
      }
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk publish failed.', isError: true);
    }
  }

  Future<void> _handleBulkPublish(String classId, String sectionId, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Publish Report Cards'),
        content: const Text(
          'Are you sure you want to publish all APPROVED report cards for this class and section? '
          'Once published, they will become visible to parents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(reportCardOperationsProvider.notifier).publish(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
    );

    if (success) {
      _showActionFeedback('Approved report cards published successfully.');
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk publication failed', isError: true);
    }
  }

  Future<void> _showVerificationDialog(String uuid) async {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final verifyAsync = ref.watch(reportCardVerificationProvider(uuid));
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text('Signature Verification'),
              ],
            ),
            content: verifyAsync.when(
              data: (data) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✓ Digitally Signed & Authenticated',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text('Student: ${data.studentName} (Roll: ${data.rollNumber})'),
                  Text('Class & Section: ${data.className} - ${data.sectionName}'),
                  Text('Academic Year: ${data.academicYear}'),
                  Text('Status: ${data.status.toUpperCase()}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Verification UUID:\n$uuid',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  if (data.generatedAt != null)
                    Text('Signed Date: ${data.generatedAt}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text(
                'Failed to verify signature authenticity: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Card Management')),
        body: const Center(child: Text('Please select a school to proceed.')),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));
    final filters = ref.watch(resultsFiltersProvider);
    final filtersNotifier = ref.read(resultsFiltersProvider.notifier);

    // Deduplicate Academic Years
    final uniqueYearsMap = <String, AcademicYearDto>{};
    for (final y in ayState.years) {
      if (y.id.isNotEmpty) {
        if (uniqueYearsMap.containsKey(y.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Academic Year ID duplicate detected: ${y.id}');
        } else {
          uniqueYearsMap[y.id] = y;
        }
      }
    }
    final uniqueYears = uniqueYearsMap.values.toList();
    final validAyId = uniqueYears.any((y) => y.id == filters.academicYearId)
        ? filters.academicYearId
        : null;

    // Deduplicate Classes
    final uniqueClassesMap = <String, ClassDto>{};
    for (final c in classState.classes) {
      if (c.id.isNotEmpty) {
        if (uniqueClassesMap.containsKey(c.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Class ID duplicate detected: ${c.id}');
        } else {
          uniqueClassesMap[c.id] = c;
        }
      }
    }
    final uniqueClasses = uniqueClassesMap.values.toList();
    final validClassId = uniqueClasses.any((c) => c.id == filters.classId)
        ? filters.classId
        : null;

    // Deduplicate Sections
    final filteredSections = sectionState.sections
        .where((s) => s.classId == validClassId)
        .toList();
    final uniqueSectionsMap = <String, SectionDto>{};
    for (final s in filteredSections) {
      if (s.id.isNotEmpty) {
        if (uniqueSectionsMap.containsKey(s.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Section ID duplicate detected: ${s.id}');
        } else {
          uniqueSectionsMap[s.id] = s;
        }
      }
    }
    final uniqueSections = uniqueSectionsMap.values.toList();
    final validSectionId = uniqueSections.any((s) => s.id == filters.sectionId)
        ? filters.sectionId
        : null;

    // Schedule asynchronous reset of invalid filter states after UI frame
    if ((filters.academicYearId != null && validAyId == null) ||
        (filters.classId != null && validClassId == null) ||
        (filters.sectionId != null && validSectionId == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (filters.academicYearId != null && validAyId == null) {
          filtersNotifier.setAcademicYear(null);
        }
        if (filters.classId != null && validClassId == null) {
          filtersNotifier.setClass(null);
        }
        if (filters.sectionId != null && validSectionId == null) {
          filtersNotifier.setSection(null);
        }
      });
    }

    final studentsAsync = ref.watch(resultsStudentsProvider);
    final cardsAsync = ref.watch(resultsReportCardsProvider);
    final opsState = ref.watch(reportCardOperationsProvider);

    // Filter defaults fallback if empty or invalid
    if (uniqueYears.isNotEmpty && validAyId == null) {
      final current = uniqueYears.firstWhere((y) => y.isCurrent, orElse: () => uniqueYears.first);
      Future.microtask(() => filtersNotifier.setAcademicYear(current.id));
    }
    if (uniqueClasses.isNotEmpty && validClassId == null) {
      Future.microtask(() => filtersNotifier.setClass(uniqueClasses.first.id));
    }
    if (uniqueSections.isNotEmpty && validClassId != null && validSectionId == null) {
      Future.microtask(() => filtersNotifier.setSection(uniqueSections.first.id));
    }

    // Derive summary metrics from rosters list
    int totalCount = 0;
    int notGeneratedCount = 0;
    int draftCount = 0;
    int underReviewCount = 0;
    int approvedCount = 0;
    int publishedCount = 0;
    int lockedCount = 0;

    if (studentsAsync.hasValue && cardsAsync.hasValue) {
      final students = studentsAsync.value ?? const [];
      final cards = cardsAsync.value ?? const [];
      totalCount = students.length;

      for (final s in students) {
        final card = cards.firstWhere((c) => c.studentId == s.id, orElse: () => const ReportCardDto(
          id: '',
          verificationUuid: '',
          status: 'NOT GENERATED',
          pdfHistory: [],
          tenantId: '',
          schoolId: '',
          academicYearId: '',
          studentId: '',
          aiMetrics: {},
        ));

        if (card.id.isEmpty) {
          notGeneratedCount++;
        } else {
          switch (card.status.toUpperCase()) {
            case 'DRAFT':
              draftCount++;
              break;
            case 'UNDER_REVIEW':
              underReviewCount++;
              break;
            case 'APPROVED':
              approvedCount++;
              break;
            case 'PUBLISHED':
              publishedCount++;
              break;
            case 'LOCKED':
              lockedCount++;
              break;
          }
        }
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Card Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(resultsStudentsProvider);
              ref.invalidate(resultsReportCardsProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top filter card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.filter_list, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select Class & Roster View',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final colCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
                            final itemWidth = width / colCount - 16;

                            final dropdowns = [
                              DropdownButtonFormField<String>(
                                key: const Key('filter_academic_year'),
                                value: validAyId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Academic Year',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                items: uniqueYears.map((y) {
                                  return DropdownMenuItem(
                                    value: y.id,
                                    child: Text('${y.name} ${y.isCurrent ? "(Current)" : ""}'),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  filtersNotifier.setAcademicYear(v);
                                  ref.invalidate(resultsExaminationsProvider);
                                },
                              ),
                              DropdownButtonFormField<String>(
                                key: const Key('filter_class'),
                                value: validClassId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                items: uniqueClasses.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  filtersNotifier.setClass(v);
                                  ref.invalidate(resultsStudentsProvider);
                                  ref.invalidate(resultsReportCardsProvider);
                                },
                              ),
                              DropdownButtonFormField<String>(
                                key: const Key('filter_section'),
                                value: validSectionId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                items: uniqueSections.map((s) {
                                  return DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  filtersNotifier.setSection(v);
                                  ref.invalidate(resultsStudentsProvider);
                                  ref.invalidate(resultsReportCardsProvider);
                                },
                              ),
                            ];

                            if (colCount == 1) {
                              return Column(
                                children: dropdowns
                                    .map((e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0),
                                          child: e,
                                        ))
                                    .toList(),
                              );
                            } else {
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: dropdowns
                                    .map((e) => SizedBox(
                                          width: itemWidth,
                                          child: e,
                                        ))
                                    .toList(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Operational summaries section
                if (studentsAsync.hasValue && cardsAsync.hasValue) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final double childWidth = width > 1200
                          ? (width - 64) / 5
                          : (width > 800 ? (width - 32) / 3 : (width > 600 ? (width - 16) / 2 : width));

                      final statsCards = [
                        _buildStatCard(
                          context,
                          title: 'Total Students',
                          value: totalCount.toString(),
                          icon: Icons.people_outline,
                          color: theme.colorScheme.primary,
                          filterKey: ReportCardLifecycleFilter.all,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.all,
                          onTap: () => setState(() => _activeFilter = ReportCardLifecycleFilter.all),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Not Generated (Derived)',
                          value: notGeneratedCount.toString(),
                          icon: Icons.assignment_late_outlined,
                          color: Colors.red,
                          filterKey: ReportCardLifecycleFilter.notGenerated,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.notGenerated,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.notGenerated
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.notGenerated;
                          }),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Draft (Derived)',
                          value: draftCount.toString(),
                          icon: Icons.edit_note,
                          color: Colors.orange,
                          filterKey: ReportCardLifecycleFilter.draft,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.draft,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.draft
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.draft;
                          }),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Under Review (Derived)',
                          value: underReviewCount.toString(),
                          icon: Icons.rate_review_outlined,
                          color: Colors.amber,
                          filterKey: ReportCardLifecycleFilter.underReview,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.underReview,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.underReview
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.underReview;
                          }),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Approved (Derived)',
                          value: approvedCount.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.blue,
                          filterKey: ReportCardLifecycleFilter.approved,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.approved,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.approved
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.approved;
                          }),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Published (Derived)',
                          value: publishedCount.toString(),
                          icon: Icons.publish_outlined,
                          color: Colors.green,
                          filterKey: ReportCardLifecycleFilter.published,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.published,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.published
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.published;
                          }),
                        ),
                        _buildStatCard(
                          context,
                          title: 'Locked (Derived)',
                          value: lockedCount.toString(),
                          icon: Icons.lock_outline,
                          color: Colors.purple,
                          filterKey: ReportCardLifecycleFilter.locked,
                          isSelected: _activeFilter == ReportCardLifecycleFilter.locked,
                          onTap: () => setState(() {
                            _activeFilter = _activeFilter == ReportCardLifecycleFilter.locked
                                ? ReportCardLifecycleFilter.all
                                : ReportCardLifecycleFilter.locked;
                          }),
                        ),
                      ];

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: statsCards
                            .map((e) => SizedBox(
                                  width: childWidth,
                                  child: e,
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Action panel & DataTable
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bulk operation actions buttons row
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bulk Operations',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (filters.academicYearId == null || filters.classId == null || filters.sectionId == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Please select Academic Year, Class and Section to enable generation.',
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                    ),
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ElevatedButton.icon(
                                  key: const Key('btn_bulk_generate'),
                                  onPressed: (filters.academicYearId != null && filters.classId != null && filters.sectionId != null && !opsState.isLoading)
                                      ? () => _handleBulkGenerate(
                                            filters.classId!,
                                            filters.sectionId!,
                                            schoolId,
                                          )
                                      : null,
                                  icon: opsState.isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.flash_on),
                                  label: Text(opsState.isLoading ? 'Generating Report Cards...' : 'Generate Class Cards'),
                                ),
                                ElevatedButton.icon(
                                  key: const Key('btn_bulk_publish_all'),
                                  onPressed: (approvedCount > 0 && filters.classId != null && filters.sectionId != null && !opsState.isLoading)
                                      ? () => _handleBulkPublish(
                                            filters.classId!,
                                            filters.sectionId!,
                                            schoolId,
                                          )
                                      : null,
                                  icon: const Icon(Icons.publish),
                                  label: Text('Publish All Approved ($approvedCount)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Search Bar & Filter Indicator Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('search_bar_input'),
                                decoration: const InputDecoration(
                                  hintText: 'Search student roll, name or admission number...',
                                  prefixIcon: Icon(Icons.search),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onChanged: (v) => setState(() => _searchQuery = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Active Filter Indicator Banner
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _activeFilter == ReportCardLifecycleFilter.all
                                      ? Icons.people
                                      : Icons.filter_alt,
                                  size: 16,
                                  color: _activeFilter == ReportCardLifecycleFilter.all
                                      ? Colors.grey.shade700
                                      : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _activeFilter == ReportCardLifecycleFilter.all
                                      ? 'Showing: All Students ($totalCount)'
                                      : _activeFilter == ReportCardLifecycleFilter.notGenerated
                                          ? 'Showing: Students Without Generated Report Cards ($notGeneratedCount)'
                                          : 'Showing: ${_activeFilter.label} Report Cards (${_activeFilter == ReportCardLifecycleFilter.draft ? draftCount : _activeFilter == ReportCardLifecycleFilter.underReview ? underReviewCount : _activeFilter == ReportCardLifecycleFilter.approved ? approvedCount : _activeFilter == ReportCardLifecycleFilter.published ? publishedCount : lockedCount})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _activeFilter == ReportCardLifecycleFilter.all
                                        ? Colors.black87
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (_activeFilter != ReportCardLifecycleFilter.all)
                              ActionChip(
                                avatar: const Icon(Icons.close, size: 14),
                                label: const Text('Reset Filter', style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() => _activeFilter = ReportCardLifecycleFilter.all),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Students Roster table listing
                        studentsAsync.when(
                          data: (List<StudentDto> students) {
                            if (students.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text('No students found for this class and section selection.'),
                                ),
                              );
                            }

                            return cardsAsync.when(
                              data: (List<ReportCardDto> cards) {
                                // 1. Apply Lifecycle Filter
                                final filteredByLifecycle = students.where((st) {
                                  final card = cards.firstWhere(
                                    (c) => c.studentId == st.id,
                                    orElse: () => ReportCardDto(
                                      id: '',
                                      verificationUuid: '',
                                      status: 'NOT GENERATED',
                                      pdfHistory: const [],
                                      tenantId: '',
                                      schoolId: '',
                                      academicYearId: '',
                                      studentId: st.id,
                                      aiMetrics: const {},
                                    ),
                                  );

                                  final cardStatus = card.id.isEmpty ? 'NOT GENERATED' : card.status.toUpperCase();

                                  switch (_activeFilter) {
                                    case ReportCardLifecycleFilter.all:
                                      return true;
                                    case ReportCardLifecycleFilter.notGenerated:
                                      return card.id.isEmpty || cardStatus == 'NOT GENERATED';
                                    case ReportCardLifecycleFilter.draft:
                                      return card.id.isNotEmpty && cardStatus == 'DRAFT';
                                    case ReportCardLifecycleFilter.underReview:
                                      return card.id.isNotEmpty && cardStatus == 'UNDER_REVIEW';
                                    case ReportCardLifecycleFilter.approved:
                                      return card.id.isNotEmpty && cardStatus == 'APPROVED';
                                    case ReportCardLifecycleFilter.published:
                                      return card.id.isNotEmpty && cardStatus == 'PUBLISHED';
                                    case ReportCardLifecycleFilter.locked:
                                      return card.id.isNotEmpty && cardStatus == 'LOCKED';
                                  }
                                }).toList();

                                // 2. Apply Search Filter
                                final filtered = filteredByLifecycle.where((st) {
                                  final name = '${st.firstName} ${st.lastName}'.toLowerCase();
                                  final roll = st.rollNumber.toLowerCase();
                                  final adm = st.admissionNumber.toLowerCase();
                                  final query = _searchQuery.toLowerCase();
                                  return name.contains(query) || roll.contains(query) || adm.contains(query);
                                }).toList();

                                final matchingClasses = classState.classes.where((c) => c.id == filters.classId).toList();
                                final currentClassName = matchingClasses.isNotEmpty ? matchingClasses.first.name : 'Class';

                                final matchingSections = sectionState.sections.where((sec) => sec.id == filters.sectionId).toList();
                                final currentSecName = matchingSections.isNotEmpty ? matchingSections.first.name : 'Section';

                                final selectedCards = cards.where((c) => _selectedStudentIds.contains(c.studentId) && c.id.isNotEmpty).toList();
                                final selectedUnderReviewCount = selectedCards.where((c) => c.status.toUpperCase() == 'UNDER_REVIEW').length;
                                final selectedApprovedCount = selectedCards.where((c) => c.status.toUpperCase() == 'APPROVED').length;

                                if (filtered.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No students match "$_searchQuery"'
                                                : 'No ${_activeFilter.label} Report Cards',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'Try searching with a different name, roll number, or admission number.'
                                                : 'There are currently no ${_activeFilter.label.toLowerCase()} report cards for $currentClassName - $currentSecName.',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (_activeFilter != ReportCardLifecycleFilter.all) ...[
                                            const SizedBox(height: 14),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.people_outline, size: 16),
                                              label: const Text('Show All Students'),
                                              onPressed: () => setState(() => _activeFilter = ReportCardLifecycleFilter.all),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Selection Context Action Toolbar
                                    if (_selectedStudentIds.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.indigo.shade200),
                                        ),
                                        child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.indigo.shade700, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${_selectedStudentIds.length} student${_selectedStudentIds.length == 1 ? "" : "s"} selected',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.indigo.shade900,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                // Bulk operation actions buttons
                                                ElevatedButton.icon(
                                                  key: const Key('btn_bulk_approve_selected'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.teal,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                                  label: Text(selectedUnderReviewCount > 0
                                                      ? 'Approve Selected ($selectedUnderReviewCount)'
                                                      : 'Approve Selected (${_selectedStudentIds.length})'),
                                                  onPressed: (opsState.isLoading || selectedCards.isEmpty)
                                                      ? null
                                                      : () => _handleBulkApproveSelected(cards, schoolId),
                                                ),
                                                ElevatedButton.icon(
                                                  key: const Key('btn_bulk_publish_selected'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.indigo,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.publish, size: 16),
                                                  label: Text(selectedApprovedCount > 0
                                                      ? 'Publish Selected ($selectedApprovedCount)'
                                                      : 'Publish Selected (${_selectedStudentIds.length})'),
                                                  onPressed: (opsState.isLoading || selectedCards.isEmpty)
                                                      ? null
                                                      : () => _handleBulkPublishSelected(cards, schoolId),
                                                ),
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.clear, size: 16),
                                                  label: const Text('Clear Selection'),
                                                  onPressed: _clearSelection,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                    if (isMobile)
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) => const Divider(),
                                        itemBuilder: (context, idx) {
                                          final s = filtered[idx];
                                          final card = cards.firstWhere(
                                            (c) => c.studentId == s.id,
                                            orElse: () => ReportCardDto(
                                              id: '',
                                              verificationUuid: '',
                                              status: 'NOT GENERATED',
                                              pdfHistory: const [],
                                              tenantId: '',
                                              schoolId: '',
                                              academicYearId: '',
                                              studentId: s.id,
                                              aiMetrics: const {},
                                            ),
                                          );

                                          final className = classState.classes
                                              .firstWhere((c) => c.id == s.classId,
                                                  orElse: () => classState.classes.first)
                                              .name;
                                          final secName = sectionState.sections
                                              .firstWhere((sec) => sec.id == s.sectionId,
                                                  orElse: () => sectionState.sections.first)
                                              .name;

                                          return MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: ListTile(
                                              leading: Checkbox(
                                                value: _selectedStudentIds.contains(s.id),
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedStudentIds.add(s.id);
                                                    } else {
                                                      _selectedStudentIds.remove(s.id);
                                                    }
                                                  });
                                                },
                                              ),
                                              title: Text('${s.rollNumber}. ${s.firstName} ${s.lastName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Adm No: ${s.admissionNumber}  •  $className-$secName'),
                                                  const SizedBox(height: 4),
                                                  _buildStatusBadge(card.status),
                                                ],
                                              ),
                                              onTap: () => _handleStudentClick(s, card, className, secName),
                                              trailing: _buildPopupMenuButton(card, s, schoolId),
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          showCheckboxColumn: false,
                                          columns: [
                                            DataColumn(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Checkbox(
                                                    tristate: true,
                                                    value: filtered.isEmpty
                                                        ? false
                                                        : (filtered.every((st) => _selectedStudentIds.contains(st.id))
                                                            ? true
                                                            : (filtered.any((st) => _selectedStudentIds.contains(st.id))
                                                                ? null
                                                                : false)),
                                                    onChanged: filtered.isEmpty
                                                        ? null
                                                        : (val) {
                                                            setState(() {
                                                              if (filtered.every((st) => _selectedStudentIds.contains(st.id))) {
                                                                for (final st in filtered) {
                                                                  _selectedStudentIds.remove(st.id);
                                                                }
                                                              } else {
                                                                for (final st in filtered) {
                                                                  _selectedStudentIds.add(st.id);
                                                                }
                                                              }
                                                            });
                                                          },
                                                  ),
                                                  const Text('Roll No'),
                                                ],
                                              ),
                                            ),
                                            const DataColumn(label: Text('Admission No')),
                                            const DataColumn(label: Text('Student Name')),
                                            const DataColumn(label: Text('Class & Section')),
                                            const DataColumn(label: Text('Report Card Status')),
                                            const DataColumn(label: Text('Actions')),
                                          ],
                                          rows: filtered.map((s) {
                                            final card = cards.firstWhere(
                                              (c) => c.studentId == s.id,
                                              orElse: () => ReportCardDto(
                                                id: '',
                                                verificationUuid: '',
                                                status: 'NOT GENERATED',
                                                pdfHistory: const [],
                                                tenantId: '',
                                                schoolId: '',
                                                academicYearId: '',
                                                studentId: s.id,
                                                aiMetrics: const {},
                                              ),
                                            );

                                            final className = classState.classes
                                                .firstWhere((c) => c.id == s.classId,
                                                    orElse: () => classState.classes.first)
                                                .name;
                                            final secName = sectionState.sections
                                                .firstWhere((sec) => sec.id == s.sectionId,
                                                    orElse: () => sectionState.sections.first)
                                                .name;

                                            final isSelected = _selectedStudentIds.contains(s.id);

                                            return DataRow(
                                              selected: isSelected,
                                              onSelectChanged: (_) => _handleStudentClick(s, card, className, secName),
                                              cells: [
                                                DataCell(
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Checkbox(
                                                        value: isSelected,
                                                        onChanged: (val) {
                                                          setState(() {
                                                            if (val == true) {
                                                              _selectedStudentIds.add(s.id);
                                                            } else {
                                                              _selectedStudentIds.remove(s.id);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                      Text(s.rollNumber),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(Text(s.admissionNumber)),
                                                DataCell(
                                                  Text(
                                                    '${s.firstName} ${s.lastName}',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                DataCell(Text('$className - $secName')),
                                                DataCell(_buildStatusBadge(card.status)),
                                                DataCell(
                                                  _buildPopupMenuButton(card, s, schoolId),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Text('Error loading cards: $err'),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Column(
                            children: [
                              Text('Error: $err'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  ref.invalidate(resultsStudentsProvider);
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (opsState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopupMenuButton(ReportCardDto card, StudentDto s, String schoolId) {
    final status = card.status.toUpperCase();
    final hasCard = card.id.isNotEmpty;

    return PopupMenuButton<String>(
      key: Key('actions_menu_${s.id}'),
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        final ops = ref.read(reportCardOperationsProvider.notifier);
        bool res = false;
        String successText = '';

        if (value == 'view') {
          context.push('/results/report-cards/${s.id}');
          return;
        }

        switch (value) {
          case 'generate':
            res = await ops.generateSingle(studentId: s.id, schoolId: schoolId);
            successText = 'Report card generated successfully.';
            break;
          case 'submit_review':
            res = await ops.submitForReview(id: card.id, schoolId: schoolId);
            successText = 'Report card submitted for review.';
            break;
          case 'approve':
            res = await ops.approve(id: card.id, schoolId: schoolId);
            successText = 'Report card approved successfully.';
            break;
          case 'publish':
            final filters = ref.read(resultsFiltersProvider);
            if (filters.classId != null && filters.sectionId != null) {
              res = await ops.publish(
                classId: filters.classId!,
                sectionId: filters.sectionId!,
                schoolId: schoolId,
              );
              successText = 'Approved report cards published.';
            }
            break;
          case 'lock':
            res = await ops.lock(id: card.id, schoolId: schoolId);
            successText = 'Report card frozen successfully.';
            break;
          case 'unlock':
            res = await ops.unlock(id: card.id, schoolId: schoolId);
            successText = 'Report card unlocked.';
            break;
          case 'download_pdf':
            res = await ops.downloadPdf(
              studentId: s.id,
              schoolId: schoolId,
              studentName: '${s.firstName} ${s.lastName}',
            );
            successText = 'PDF downloaded.';
            break;
          case 'view_pdf':
            res = await ops.viewPdf(studentId: s.id, schoolId: schoolId);
            successText = 'PDF loaded in viewer.';
            break;
          case 'verify':
            if (card.verificationUuid.isNotEmpty) {
              await _showVerificationDialog(card.verificationUuid);
            }
            return;
        }

        if (res) {
          _showActionFeedback(successText);
        } else {
          final state = ref.read(reportCardOperationsProvider);
          _showActionFeedback(state.error ?? 'Action execution failed', isError: true);
        }
      },
      itemBuilder: (context) {
        return [
          // View details is always available if card is generated
          if (hasCard)
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View Details'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!hasCard)
            const PopupMenuItem(
              value: 'generate',
              child: ListTile(
                leading: Icon(Icons.flash_on),
                title: Text('Generate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'DRAFT') ...[
            const PopupMenuItem(
              value: 'submit_review',
              child: ListTile(
                leading: Icon(Icons.rate_review),
                title: Text('Submit Review'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'generate',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Regenerate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (status == 'UNDER_REVIEW')
            const PopupMenuItem(
              value: 'approve',
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Approve'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'APPROVED')
            const PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: Icon(Icons.publish),
                title: Text('Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'PUBLISHED') ...[
            const PopupMenuItem(
              value: 'lock',
              child: ListTile(
                leading: Icon(Icons.lock),
                title: Text('Lock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'download_pdf',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('View PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'verify',
              child: ListTile(
                leading: Icon(Icons.verified),
                title: Text('Verify Signature'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (status == 'LOCKED') ...[
            const PopupMenuItem(
              value: 'unlock',
              child: ListTile(
                leading: Icon(Icons.lock_open),
                title: Text('Unlock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'download_pdf',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('View PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'verify',
              child: ListTile(
                leading: Icon(Icons.verified),
                title: Text('Verify Signature'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ];
      },
    );
  }
}
