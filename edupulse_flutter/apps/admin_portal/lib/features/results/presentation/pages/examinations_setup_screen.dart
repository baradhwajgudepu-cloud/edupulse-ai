import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/examination_models.dart';
import '../providers/examination_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class ExaminationsSetupScreen extends ConsumerStatefulWidget {
  const ExaminationsSetupScreen({super.key});

  @override
  ConsumerState<ExaminationsSetupScreen> createState() => _ExaminationsSetupScreenState();
}

class _ExaminationsSetupScreenState extends ConsumerState<ExaminationsSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null && schoolId.isNotEmpty) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(examinationsProvider.notifier).loadExaminations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
      if (prev != next && next != null && next.isNotEmpty) {
        ref.read(academicYearsProvider(next).notifier).fetchYears();
        ref.read(examinationsProvider.notifier).loadExaminations();
      }
    });

    final state = ref.watch(examinationsProvider);
    final academicYearsState = schoolId.isNotEmpty ? ref.watch(academicYearsProvider(schoolId)) : null;
    final theme = Theme.of(context);

    // Compute KPIs
    final totalExams = state.examinations.length;
    final scheduledCount = state.examinations.where((e) => e.status == ExamStatusEnum.scheduled).length;
    final ongoingCount = state.examinations.where((e) => e.status == ExamStatusEnum.ongoing).length;
    final marksEntryCount = state.examinations.where((e) => e.status == ExamStatusEnum.marksEntry || e.status == ExamStatusEnum.underReview).length;
    final publishedCount = state.examinations.where((e) => e.status == ExamStatusEnum.published).length;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examinations Master Setup',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure institutional examinations, map participating classes, and control lifecycle progression.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.read(examinationsProvider.notifier).loadExaminations(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _openCreationWizard(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New Exam Wizard'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Metrics Row
            Row(
              children: [
                _buildKpiCard(
                  context,
                  title: 'Total Examinations',
                  value: totalExams.toString(),
                  icon: Icons.assignment_outlined,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Scheduled',
                  value: scheduledCount.toString(),
                  icon: Icons.calendar_month_outlined,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Ongoing',
                  value: ongoingCount.toString(),
                  icon: Icons.play_circle_outline,
                  color: Colors.amber[800]!,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Marks Entry / Review',
                  value: marksEntryCount.toString(),
                  icon: Icons.rate_review_outlined,
                  color: Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Published',
                  value: publishedCount.toString(),
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error Banner
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => ref.read(examinationsProvider.notifier).loadExaminations(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Filters and Search Toolbar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by exam name or description...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          ref.read(examinationsProvider.notifier).setSearchQuery(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Academic Year Filter
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        value: state.selectedAcademicYearId,
                        decoration: InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Academic Years')),
                          if (academicYearsState != null)
                            ...academicYearsState.years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.name))),
                        ],
                        onChanged: (val) {
                          ref.read(examinationsProvider.notifier).setAcademicYearFilter(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Status Filter
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        value: state.selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status Filter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Statuses')),
                          ...ExamStatusEnum.values.map(
                            (s) => DropdownMenuItem(value: s.code, child: Text(s.label)),
                          ),
                        ],
                        onChanged: (val) {
                          ref.read(examinationsProvider.notifier).setStatusFilter(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Examinations Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : state.examinations.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No examinations configured matching filters.'),
                              ],
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                            columns: const [
                              DataColumn(label: Text('Examination', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Exam Type', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Classes', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Schedules', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Lifecycle Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: state.examinations.map((exam) {
                              return DataRow(
                                onSelectChanged: (_) => _openExamDetailsModal(context, exam),
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(exam.examName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (exam.description != null && exam.description!.isNotEmpty)
                                          Text(
                                            exam.description!,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(exam.examType, style: const TextStyle(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  DataCell(Text('${exam.startDate} → ${exam.endDate}')),
                                  DataCell(
                                    exam.participatingClassIds.isEmpty
                                        ? const Text('All Classes')
                                        : Chip(
                                            label: Text('${exam.participatingClassIds.length} Classes', style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text('${exam.schedules.length} Papers', style: const TextStyle(fontSize: 11)),
                                      backgroundColor: exam.schedules.isEmpty ? Colors.amber[50] : Colors.blue[50],
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        exam.status.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: exam.status.color.darken(),
                                        ),
                                      ),
                                      backgroundColor: exam.status.color.withAlpha(40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
                                          tooltip: 'View Examination Details',
                                          onPressed: () => _openExamDetailsModal(context, exam),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.calendar_month, size: 18),
                                          tooltip: 'Manage Timetable',
                                          onPressed: () {
                                            context.push('${AppRoutes.plannerExams}?examId=${exam.id}');
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.sync_alt, size: 18, color: Colors.indigo),
                                          tooltip: 'Transition Status',
                                          onPressed: () => _openStatusTransitionDialog(context, exam),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_outlined, size: 18),
                                          tooltip: 'Duplicate Examination',
                                          onPressed: () => _openCopyExamDialog(context, exam),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Delete Examination',
                                          onPressed: () => _confirmDeleteExam(context, exam),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openExamDetailsModal(BuildContext context, ExaminationModel exam) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: exam.status.color.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.school, color: exam.status.color.darken(), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.examName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${exam.examType} • ${exam.startDate} to ${exam.endDate}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(
                exam.status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: exam.status.color.darken(),
                ),
              ),
              backgroundColor: exam.status.color.withAlpha(40),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Examination Readiness Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: Colors.purple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EduPulse Intelligence Insight — Examination Readiness',
                              style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              exam.schedules.isEmpty
                                  ? 'No paper schedules configured. Timetable needs to be generated before lifecycle can progress.'
                                  : '${exam.schedules.length} examination paper slots scheduled. Ready for ongoing supervision and marks management.',
                              style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Overview
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Schedules / Papers', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${exam.schedules.length} Papers', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Participating Classes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              exam.participatingClassIds.isEmpty ? 'All School Classes' : '${exam.participatingClassIds.length} Classes',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Navigation Shortcuts
                const Text('Functional Action Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('View Timetable'),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('${AppRoutes.plannerExams}?examId=${exam.id}');
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.grading, size: 16),
                      label: const Text('Manage Marks'),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('${AppRoutes.marksManagement}?examId=${exam.id}');
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('View Results'),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('${AppRoutes.results}?examId=${exam.id}');
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Report Cards'),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('${AppRoutes.reportCards}?examId=${exam.id}');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.sync_alt, size: 16, color: Colors.indigo),
            label: const Text('Change Status'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _openStatusTransitionDialog(context, exam);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text('Open Timetable'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.push('${AppRoutes.plannerExams}?examId=${exam.id}');
            },
          ),
        ],
      ),
    );
  }

  void _openCreationWizard(BuildContext context) {
    final examTypesState = ref.read(examTypesProvider);
    final schoolId = ref.read(selectedSchoolIdProvider) ?? '';
    final classesState = schoolId.isNotEmpty ? ref.read(classesProvider(schoolId)) : null;

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final startDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 7)).toString().split(' ')[0]);
    final endDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 14)).toString().split(' ')[0]);
    var selectedTypeCode = examTypesState.types.isNotEmpty ? examTypesState.types.first.code : 'UNIT_TEST';
    var targetScope = 'ALL_CLASSES';
    final selectedClassIds = <String>[];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        var currentStep = 0;

        return StatefulBuilder(
          builder: (ctx, setWizardState) {
            return AlertDialog(
              title: Text('Examination Creation Wizard (Step ${currentStep + 1} of 3)'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stepper progress header
                      Row(
                        children: [
                          _buildStepIndicator(0, '1. Basic Info', currentStep),
                          const Expanded(child: Divider()),
                          _buildStepIndicator(1, '2. Classes', currentStep),
                          const Expanded(child: Divider()),
                          _buildStepIndicator(2, '3. Review', currentStep),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Step 1 Content
                      if (currentStep == 0) ...[
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Examination Name *',
                            hintText: 'e.g. Term 1 Assessment 2026',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedTypeCode,
                          decoration: const InputDecoration(labelText: 'Exam Type *'),
                          items: examTypesState.types.map(
                            (t) => DropdownMenuItem(
                              value: t.code,
                              child: Text('${t.name} (${t.code})'),
                            ),
                          ).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setWizardState(() {
                                selectedTypeCode = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startDateController,
                                decoration: const InputDecoration(
                                  labelText: 'Start Date (YYYY-MM-DD) *',
                                  prefixIcon: Icon(Icons.date_range),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: endDateController,
                                decoration: const InputDecoration(
                                  labelText: 'End Date (YYYY-MM-DD) *',
                                  prefixIcon: Icon(Icons.date_range),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description / Instructions',
                            hintText: 'Instructions for teachers and invigilators...',
                          ),
                        ),
                      ],

                      // Step 2 Content
                      if (currentStep == 1) ...[
                        DropdownButtonFormField<String>(
                          value: targetScope,
                          decoration: const InputDecoration(labelText: 'Target Scope'),
                          items: const [
                            DropdownMenuItem(value: 'ALL_CLASSES', child: Text('All Classes in School')),
                            DropdownMenuItem(value: 'SPECIFIC_CLASSES', child: Text('Specific Participating Classes')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setWizardState(() {
                                targetScope = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        if (targetScope == 'SPECIFIC_CLASSES') ...[
                          if (classesState != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Select Participating Classes:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: classesState.classes.map((c) {
                                    final isSelected = selectedClassIds.contains(c.id);
                                    return FilterChip(
                                      label: Text(c.name),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setWizardState(() {
                                          if (selected) {
                                            selectedClassIds.add(c.id);
                                          } else {
                                            selectedClassIds.remove(c.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                        ],
                      ],

                      // Step 3 Content (Review)
                      if (currentStep == 2) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam Name: ${nameController.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Type: $selectedTypeCode'),
                              const SizedBox(height: 6),
                              Text('Period: ${startDateController.text} to ${endDateController.text}'),
                              const SizedBox(height: 6),
                              Text('Scope: $targetScope (${targetScope == 'ALL_CLASSES' ? 'All Classes' : '${selectedClassIds.length} Selected Classes'})'),
                              const SizedBox(height: 12),
                              const Divider(),
                              const Text(
                                'Next Step: After creation, you will manage timetable schedules and papers in the Timetable Management view.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (currentStep > 0)
                  TextButton(
                    onPressed: () {
                      setWizardState(() {
                        currentStep--;
                      });
                    },
                    child: const Text('Back'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                if (currentStep < 2)
                  FilledButton(
                    onPressed: () {
                      if (currentStep == 0 && nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide an examination name.')),
                        );
                        return;
                      }
                      setWizardState(() {
                        currentStep++;
                      });
                    },
                    child: const Text('Next'),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(dialogCtx).pop();
                      final ok = await ref.read(examinationsProvider.notifier).createExaminationWizard(
                            examName: nameController.text.trim(),
                            examType: selectedTypeCode,
                            startDate: startDateController.text.trim(),
                            endDate: endDateController.text.trim(),
                            description: descController.text.trim(),
                            targetScope: targetScope,
                            classIds: targetScope == 'SPECIFIC_CLASSES' ? selectedClassIds : null,
                          );
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Examination created successfully!')),
                        );
                      }
                    },
                    child: const Text('Create Examination'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, int currentStep) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isDone ? Colors.green : (isActive ? Colors.blue : Colors.grey[300]),
          child: Text(
            '${stepIndex + 1}',
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.blue[900] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _openStatusTransitionDialog(BuildContext context, ExaminationModel exam) {
    final allowedNext = exam.status.allowedNextStatuses;
    var selectedStatus = allowedNext.isNotEmpty ? allowedNext.first : exam.status;
    var isOverride = false;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Transition Status: ${exam.examName}'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Status: ${exam.status.label}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (!isOverride) ...[
                      if (allowedNext.isEmpty)
                        const Text('No standard forward transitions available for this state.')
                      else
                        DropdownButtonFormField<ExamStatusEnum>(
                          value: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Next Target Status'),
                          items: allowedNext.map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          ).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedStatus = val;
                              });
                            }
                          },
                        ),
                    ] else ...[
                      DropdownButtonFormField<ExamStatusEnum>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Force Target Status (Override)'),
                        items: ExamStatusEnum.values.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          ),
                        ).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mandatory Override Justification *',
                          hintText: 'Provide reason for skipping state machine validation...',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Administrative Override Mode'),
                      subtitle: const Text('Bypass state machine with audited justification'),
                      value: isOverride,
                      onChanged: (val) {
                        setDialogState(() {
                          isOverride = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (isOverride && reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Override justification reason is mandatory.')),
                      );
                      return;
                    }

                    Navigator.of(dialogCtx).pop();
                    final ok = await ref.read(examinationsProvider.notifier).transitionStatus(
                          examId: exam.id,
                          newStatus: selectedStatus,
                          reason: isOverride ? reasonController.text.trim() : null,
                          isAdministrativeOverride: isOverride,
                        );
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status updated to ${selectedStatus.label}')),
                      );
                    }
                  },
                  child: const Text('Apply Transition'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCopyExamDialog(BuildContext context, ExaminationModel exam) {
    final nameController = TextEditingController(text: '${exam.examName} (Copy)');
    final startDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0]);
    final endDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 40)).toString().split(' ')[0]);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Duplicate Examination'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'New Examination Name *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startDateController,
                        decoration: const InputDecoration(labelText: 'New Start Date'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endDateController,
                        decoration: const InputDecoration(labelText: 'New End Date'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Note: All paper schedules will be duplicated and shifted proportionally based on the new start date.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final ok = await ref.read(examinationsProvider.notifier).copyExamination(
                      sourceExamId: exam.id,
                      newExamName: nameController.text.trim(),
                      newStartDate: startDateController.text.trim(),
                      newEndDate: endDateController.text.trim(),
                    );
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Examination duplicated successfully!')),
                  );
                }
              },
              child: const Text('Duplicate'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteExam(BuildContext context, ExaminationModel exam) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Examination?'),
          content: Text(
            'Are you sure you want to delete "${exam.examName}"?\n\n'
            'All associated timetable schedules will also be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final ok = await ref.read(examinationsProvider.notifier).deleteExamination(exam.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Examination deleted.')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

extension ColorDarken on Color {
  Color darken([double amount = .3]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
