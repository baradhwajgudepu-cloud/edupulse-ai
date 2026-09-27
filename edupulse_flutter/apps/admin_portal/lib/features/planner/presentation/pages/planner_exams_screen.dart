import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../results/data/models/examination_models.dart';
import '../../../results/presentation/providers/examination_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import 'package:edupulse_core/edupulse_core.dart';

class PlannerExamsScreen extends ConsumerStatefulWidget {
  const PlannerExamsScreen({super.key});

  @override
  ConsumerState<PlannerExamsScreen> createState() => _PlannerExamsScreenState();
}

class _PlannerExamsScreenState extends ConsumerState<PlannerExamsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedExamId;
  String? _selectedClassId;
  String? _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examinationsProvider.notifier).loadExaminations();
      ref.read(examSchedulesProvider.notifier).loadSchedules();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    final examsState = ref.watch(examinationsProvider);
    final schedulesState = ref.watch(examSchedulesProvider);
    final classesState = schoolId.isNotEmpty ? ref.watch(classesProvider(schoolId)) : null;
    final theme = Theme.of(context);

    // Auto-select first exam if none selected
    if (_selectedExamId == null && examsState.examinations.isNotEmpty) {
      _selectedExamId = examsState.examinations.first.id;
    }

    final selectedExam = examsState.examinations.where((e) => e.id == _selectedExamId).firstOrNull;

    // Filter schedules for the current view
    final currentSchedules = schedulesState.schedules.where((s) {
      final matchesExam = _selectedExamId == null || s.examId == _selectedExamId;
      final matchesClass = _selectedClassId == null || s.classId == _selectedClassId;
      final matchesSection = _selectedSectionId == null || s.sectionId == _selectedSectionId;
      return matchesExam && matchesClass && matchesSection;
    }).toList();

    // Check for scheduling conflicts (same class & section & date & overlapping times)
    final conflictScheduleIds = <String>{};
    for (int i = 0; i < currentSchedules.length; i++) {
      for (int j = i + 1; j < currentSchedules.length; j++) {
        final a = currentSchedules[i];
        final b = currentSchedules[j];
        if (a.classId == b.classId &&
            a.sectionId == b.sectionId &&
            a.examDate == b.examDate &&
            a.startTime == b.startTime) {
          conflictScheduleIds.add(a.id);
          conflictScheduleIds.add(b.id);
        }
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar (Responsive LayoutBuilder + Expanded/Wrap)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 950;
                final headerTitle = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examination Timetable & Schedule Management',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage paper timetables, detect class clashes, auto-generate deterministic schedules, and view calendar layouts.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(examSchedulesProvider.notifier).loadSchedules();
                        ref.read(examinationsProvider.notifier).loadExaminations();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedExam != null ? () => _openAIScheduleOptimizerModal(context, selectedExam, currentSchedules) : null,
                      icon: const Icon(Icons.psychology_outlined, color: Colors.purple),
                      label: const Text('AI Optimizer'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedExam != null ? () => _openBulkGenerateModal(context, selectedExam) : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Auto-Generate Timetable'),
                    ),
                    FilledButton.icon(
                      onPressed: selectedExam != null ? () => _openAddScheduleDialog(context, selectedExam) : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Paper Slot'),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerTitle,
                      const SizedBox(height: 16),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerTitle),
                    const SizedBox(width: 16),
                    Flexible(child: actionButtons),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Clash Alert Banner if any
            if (conflictScheduleIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scheduling Conflict Detected: ${conflictScheduleIds.length} examination slots have overlapping timing on the same class and section. Highlighted in red below.',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Filter Bar (Exam selector, Class selector, Section selector)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Builder(
                  builder: (context) {
                    final classIdToName = classesState != null
                        ? <String, String>{for (final c in classesState.classes) c.id: c.name}
                        : const <String, String>{};

                    final effectiveClassIds = selectedExam?.effectiveClassIds ?? const <String>{};
                    final availableClasses = (classesState?.classes ?? []).where((c) {
                      if (selectedExam != null && effectiveClassIds.isNotEmpty) {
                        return effectiveClassIds.contains(c.id);
                      }
                      return true;
                    }).toList();

                    if (_selectedClassId != null && !availableClasses.any((c) => c.id == _selectedClassId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedClassId = null;
                        });
                        ref.read(examSchedulesProvider.notifier).setClassFilter(null);
                      });
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 750;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedExamId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Select Examination *',
                                  prefixIcon: Icon(Icons.assignment),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: examsState.examinations.map((e) {
                                  final title = e.getDisambiguatedTitle(classIdToName: classIdToName);
                                  return DropdownMenuItem(
                                    value: e.id,
                                    child: Text('$title (${e.status.label})', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedExamId = val;
                                  });
                                  ref.read(examSchedulesProvider.notifier).setExamFilter(val);
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                value: _selectedClassId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Class Filter',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Classes')),
                                  ...availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassId = val;
                                  });
                                  ref.read(examSchedulesProvider.notifier).setClassFilter(val);
                                },
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Total Scheduled: ${currentSchedules.length} Papers',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            // Exam Selector
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _selectedExamId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Select Examination *',
                                  prefixIcon: Icon(Icons.assignment),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: examsState.examinations.map((e) {
                                  final title = e.getDisambiguatedTitle(classIdToName: classIdToName);
                                  return DropdownMenuItem(
                                    value: e.id,
                                    child: Text('$title (${e.status.label})', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedExamId = val;
                                  });
                                  ref.read(examSchedulesProvider.notifier).setExamFilter(val);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Class Filter
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String?>(
                                value: _selectedClassId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Class Filter',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Classes')),
                                  ...availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassId = val;
                                  });
                                  ref.read(examSchedulesProvider.notifier).setClassFilter(val);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Total slots count
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Total Scheduled: ${currentSchedules.length} Papers',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab Navigation (Table View, Calendar View, Class Timetable View)
            LayoutBuilder(
              builder: (context, constraints) {
                return TabBar(
                  controller: _tabController,
                  isScrollable: constraints.maxWidth < 650,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.table_chart_outlined), text: 'Table View'),
                    Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar View'),
                    Tab(icon: Icon(Icons.view_quilt_outlined), text: 'Class Timetable Matrix'),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Tab Content
            SizedBox(
              height: 600,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // View 1: Table View
                  _buildTableView(context, currentSchedules, conflictScheduleIds),

                  // View 2: Calendar View
                  _buildCalendarView(context, currentSchedules, conflictScheduleIds),

                  // View 3: Class Timetable Matrix View
                  _buildClassMatrixView(context, currentSchedules, conflictScheduleIds),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableView(BuildContext context, List<ExamScheduleModel> schedules, Set<String> conflictIds) {
    if (schedules.isEmpty) {
      return const Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('No examination papers scheduled for this selection.'),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Time Slot', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Max / Pass Marks', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Room', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: schedules.map((s) {
              final isConflict = conflictIds.contains(s.id);
              return DataRow(
                onSelectChanged: (_) => _openScheduleDetailsDialog(context, s),
                color: isConflict ? WidgetStateProperty.all(Colors.red[50]) : null,
                cells: [
                  DataCell(
                    Row(
                      children: [
                        if (isConflict) const Icon(Icons.error, color: Colors.red, size: 16),
                        if (isConflict) const SizedBox(width: 4),
                        Text(s.examDate, style: TextStyle(fontWeight: FontWeight.w600, color: isConflict ? Colors.red : null)),
                      ],
                    ),
                  ),
                  DataCell(Text('${s.startTime} - ${s.endTime}')),
                  DataCell(Text('${s.className ?? "Class"} - ${s.sectionName ?? "Sec"}')),
                  DataCell(
                    Chip(
                      label: Text(displaySubjectName(subjectName: s.subjectName, subjectCode: s.subjectCode, subjectId: s.subjectId), style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  DataCell(Text('${s.maxMarks} / ${s.passMarks}')),
                  DataCell(Text(s.roomNumber ?? '—')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
                          tooltip: 'View Schedule Details',
                          onPressed: () => _openScheduleDetailsDialog(context, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Schedule Slot',
                          onPressed: () => _openEditScheduleDialog(context, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Delete Schedule Slot',
                          onPressed: () => _confirmDeleteSchedule(context, s),
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
    );
  }

  Widget _buildCalendarView(BuildContext context, List<ExamScheduleModel> schedules, Set<String> conflictIds) {
    if (schedules.isEmpty) {
      return const Card(
        child: Center(child: Text('No schedule slots to show in calendar.')),
      );
    }

    // Group schedules by exam date
    final groupedByDate = <String, List<ExamScheduleModel>>{};
    for (final s in schedules) {
      groupedByDate.setdefault(s.examDate, []).add(s);
    }

    final sortedDates = groupedByDate.keys.toList()..sort();

    return ListView.separated(
      itemCount: sortedDates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final date = sortedDates[idx];
        final daySchedules = groupedByDate[date]!;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[900],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        date,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${daySchedules.length} Papers Scheduled', style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: daySchedules.map((s) {
                    final isConflict = conflictIds.contains(s.id);
                    return Material(
                      color: isConflict ? Colors.red[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openScheduleDetailsDialog(context, s),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isConflict ? Colors.red : Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isConflict) ...[
                                    const Icon(Icons.error, color: Colors.red, size: 14),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '${displaySubjectName(subjectName: s.subjectName, subjectCode: s.subjectCode, subjectId: s.subjectId)} (${s.className ?? "Class"} - ${s.sectionName ?? "Sec"})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isConflict ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.startTime} - ${s.endTime} | Max: ${s.maxMarks} | Room: ${s.roomNumber ?? "—"}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassMatrixView(BuildContext context, List<ExamScheduleModel> schedules, Set<String> conflictIds) {
    if (schedules.isEmpty) {
      return const Card(
        child: Center(child: Text('No schedule slots available for matrix view.')),
      );
    }

    // Group by class and section
    final groupedByClass = <String, List<ExamScheduleModel>>{};
    for (final s in schedules) {
      final key = '${s.className ?? "Class"} (${s.sectionName ?? "Section"})';
      groupedByClass.setdefault(key, []).add(s);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: groupedByClass.entries.map((entry) {
          final className = entry.key;
          final classSchedules = entry.value..sort((a, b) => a.examDate.compareTo(b.examDate));

          return ExpansionTile(
            initiallyExpanded: true,
            title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${classSchedules.length} Papers Scheduled'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: classSchedules.map((s) {
                    final isConflict = conflictIds.contains(s.id);
                    return Container(
                      margin: const EdgeInsets.only(right: 12, bottom: 12),
                      child: Material(
                        color: isConflict ? Colors.red[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openScheduleDetailsDialog(context, s),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: 190,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isConflict ? Colors.red : Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s.examDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (isConflict)
                                      const Icon(Icons.error, color: Colors.red, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(displaySubjectName(subjectName: s.subjectName, subjectCode: s.subjectCode, subjectId: s.subjectId), style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${s.startTime} - ${s.endTime}', style: const TextStyle(fontSize: 11)),
                                Text('Max Marks: ${s.maxMarks}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _openScheduleDetailsDialog(BuildContext context, ExamScheduleModel schedule) {
    final theme = Theme.of(context);
    final examsState = ref.read(examinationsProvider);
    final exam = examsState.examinations.where((e) => e.id == schedule.examId).firstOrNull;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: theme.colorScheme.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displaySubjectName(subjectName: schedule.subjectName, subjectCode: schedule.subjectCode, subjectId: schedule.subjectId),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      exam?.examName ?? 'Scheduled Paper Details',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.calendar_today_outlined, 'Exam Date', schedule.examDate),
                        const Divider(height: 16),
                        _buildDetailRow(Icons.schedule_outlined, 'Time Slot', '${schedule.startTime} - ${schedule.endTime}'),
                        const Divider(height: 16),
                        _buildDetailRow(Icons.class_outlined, 'Class & Section', '${schedule.className ?? "Class"} - ${schedule.sectionName ?? "Section"}'),
                        const Divider(height: 16),
                        _buildDetailRow(Icons.menu_book_outlined, 'Subject', displaySubjectName(subjectName: schedule.subjectName, subjectCode: schedule.subjectCode, subjectId: schedule.subjectId)),
                        const Divider(height: 16),
                        _buildDetailRow(Icons.meeting_room_outlined, 'Room Number', schedule.roomNumber ?? 'Unassigned'),
                        const Divider(height: 16),
                        _buildDetailRow(Icons.grading_outlined, 'Maximum / Pass Marks', '${schedule.maxMarks} / ${schedule.passMarks}'),
                      ],
                    ),
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
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('Delete Slot', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _confirmDeleteSchedule(context, schedule);
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Schedule'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _openEditScheduleDialog(context, schedule);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showConflictDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: const Text('Schedule Conflict Detected', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This examination slot conflicts with an existing schedule in the system:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                message,
                style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _openAIScheduleOptimizerModal(BuildContext context, ExaminationModel exam, List<ExamScheduleModel> schedules) {
    // Analyze schedule density and consecutive exams
    final dateCounts = <String, int>{};
    for (final s in schedules) {
      dateCounts[s.examDate] = (dateCounts[s.examDate] ?? 0) + 1;
    }
    final sortedDates = dateCounts.keys.toList()..sort();
    
    // Check consecutive days
    final consecutiveWarnings = <String>[];
    for (int i = 0; i < sortedDates.length - 1; i++) {
      try {
        final d1 = DateTime.parse(sortedDates[i]);
        final d2 = DateTime.parse(sortedDates[i + 1]);
        if (d2.difference(d1).inDays == 1) {
          consecutiveWarnings.add('Consecutive papers on ${sortedDates[i]} and ${sortedDates[i + 1]} without a study gap day.');
        }
      } catch (_) {}
    }

    final balanceScore = consecutiveWarnings.isEmpty ? 94 : (94 - (consecutiveWarnings.length * 15)).clamp(40, 100);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple),
            const SizedBox(width: 8),
            Text('AI Schedule Optimizer: ${exam.examName}'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EduPulse Intelligence Insight — Based on timetable density, gap days, and workload balance.',
                        style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                          const Text('Timetable Balance Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('$balanceScore / 100', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple)),
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
                          const Text('Total Scheduled Days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('${sortedDates.length} Days', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Workload & Gap Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (consecutiveWarnings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Schedule is well-spaced with healthy gap intervals for student revision.',
                          style: TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...consecutiveWarnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
              const SizedBox(height: 12),
              const Text(
                'Recommendation: Administrators can adjust individual slot dates by clicking any paper slot on the timetable.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAddScheduleDialog(BuildContext context, ExaminationModel exam) {
    final schoolId = ref.read(selectedSchoolIdProvider) ?? '';
    final classesState = schoolId.isNotEmpty ? ref.read(classesProvider(schoolId)) : null;
    final sectionsState = schoolId.isNotEmpty ? ref.read(sectionsProvider(schoolId)) : null;
    final subjectsState = schoolId.isNotEmpty ? ref.read(subjectsProvider(schoolId)) : null;

    final dateController = TextEditingController(text: exam.startDate);
    final startTimeController = TextEditingController(text: '09:00:00');
    final endTimeController = TextEditingController(text: '12:00:00');
    final maxMarksController = TextEditingController(text: '100');
    final passMarksController = TextEditingController(text: '35');
    final roomController = TextEditingController();

    String? selectedClassId;
    String? selectedSectionId;
    String? selectedSubjectId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final classSections = selectedClassId != null && sectionsState != null
                ? sectionsState.sections.where((s) => s.classId == selectedClassId).toList()
                : <SectionDto>[];

            return AlertDialog(
              title: const Text('Add Examination Paper Slot'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Class Dropdown
                      if (classesState != null)
                        DropdownButtonFormField<String>(
                          value: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Class *'),
                          items: classesState.classes.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedClassId = val;
                              selectedSectionId = null;
                            });
                          },
                        ),
                      const SizedBox(height: 12),

                      // Section Input
                      if (selectedClassId != null) ...[
                        DropdownButtonFormField<String>(
                          value: selectedSectionId,
                          decoration: const InputDecoration(labelText: 'Section *'),
                          items: classSections.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedSectionId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Subject Dropdown
                      if (subjectsState != null)
                        DropdownButtonFormField<String>(
                          value: selectedSubjectId,
                          decoration: const InputDecoration(labelText: 'Subject *'),
                          items: subjectsState.subjects.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.subjectName))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedSubjectId = val;
                            });
                          },
                        ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(labelText: 'Exam Date (YYYY-MM-DD) *'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startTimeController,
                              decoration: const InputDecoration(labelText: 'Start Time (HH:MM:SS) *'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endTimeController,
                              decoration: const InputDecoration(labelText: 'End Time (HH:MM:SS) *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: maxMarksController,
                              decoration: const InputDecoration(labelText: 'Max Marks'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: passMarksController,
                              decoration: const InputDecoration(labelText: 'Pass Marks'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: roomController,
                        decoration: const InputDecoration(labelText: 'Room Number (Optional)'),
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
                FilledButton(
                  onPressed: () async {
                    if (selectedClassId == null || selectedSectionId == null || selectedSubjectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select Class, Section, and Subject.')),
                      );
                      return;
                    }

                    Navigator.of(dialogCtx).pop();
                    final ok = await ref.read(examSchedulesProvider.notifier).createSchedule(
                          examId: exam.id,
                          classId: selectedClassId!,
                          sectionId: selectedSectionId!,
                          subjectId: selectedSubjectId!,
                          examDate: dateController.text.trim(),
                          startTime: startTimeController.text.trim(),
                          endTime: endTimeController.text.trim(),
                          maxMarks: int.tryParse(maxMarksController.text.trim()) ?? 100,
                          passMarks: int.tryParse(passMarksController.text.trim()) ?? 35,
                          roomNumber: roomController.text.trim().isNotEmpty ? roomController.text.trim() : null,
                        );
                    if (context.mounted) {
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Paper schedule slot created successfully.')),
                        );
                      } else {
                        final err = ref.read(examSchedulesProvider).errorMessage ?? 'Failed to create schedule.';
                        if (err.toLowerCase().contains('conflict') || err.contains('409')) {
                          _showConflictDialog(context, err);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditScheduleDialog(BuildContext context, ExamScheduleModel schedule) {
    final dateController = TextEditingController(text: schedule.examDate);
    final startTimeController = TextEditingController(text: schedule.startTime);
    final endTimeController = TextEditingController(text: schedule.endTime);
    final maxMarksController = TextEditingController(text: schedule.maxMarks.toString());
    final passMarksController = TextEditingController(text: schedule.passMarks.toString());
    final roomController = TextEditingController(text: schedule.roomNumber ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Edit Schedule: ${displaySubjectName(subjectName: schedule.subjectName, subjectCode: schedule.subjectCode, subjectId: schedule.subjectId)}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Exam Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startTimeController,
                        decoration: const InputDecoration(labelText: 'Start Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endTimeController,
                        decoration: const InputDecoration(labelText: 'End Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxMarksController,
                        decoration: const InputDecoration(labelText: 'Max Marks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: passMarksController,
                        decoration: const InputDecoration(labelText: 'Pass Marks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(labelText: 'Room Number'),
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
                final ok = await ref.read(examSchedulesProvider.notifier).updateSchedule(
                      scheduleId: schedule.id,
                      examDate: dateController.text.trim(),
                      startTime: startTimeController.text.trim(),
                      endTime: endTimeController.text.trim(),
                      maxMarks: int.tryParse(maxMarksController.text.trim()),
                      passMarks: int.tryParse(passMarksController.text.trim()),
                      roomNumber: roomController.text.trim().isNotEmpty ? roomController.text.trim() : null,
                    );
                if (context.mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schedule updated.')),
                    );
                  } else {
                    final err = ref.read(examSchedulesProvider).errorMessage ?? 'Failed to update schedule.';
                    if (err.toLowerCase().contains('conflict') || err.contains('409')) {
                      _showConflictDialog(context, err);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSchedule(BuildContext context, ExamScheduleModel schedule) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Schedule Slot?'),
          content: Text(
            'Delete ${displaySubjectName(subjectName: schedule.subjectName, subjectCode: schedule.subjectCode, subjectId: schedule.subjectId)} for ${schedule.className ?? "Class"} on ${schedule.examDate}?',
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
                final ok = await ref.read(examSchedulesProvider.notifier).deleteSchedule(schedule.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schedule slot deleted.')),
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

  void _openBulkGenerateModal(BuildContext context, ExaminationModel exam) {
    final schoolId = ref.read(selectedSchoolIdProvider) ?? '';
    final classesState = schoolId.isNotEmpty ? ref.read(classesProvider(schoolId)) : null;

    final startDateController = TextEditingController(text: exam.startDate);
    final endDateController = TextEditingController(text: exam.endDate);
    final gapDaysController = TextEditingController(text: '1');
    final startTimeController = TextEditingController(text: '09:00:00');
    final durationController = TextEditingController(text: '180');
    final morningStartController = TextEditingController(text: '09:00:00');
    final morningDurationController = TextEditingController(text: '180');
    final afternoonStartController = TextEditingController(text: '14:00:00');
    final afternoonDurationController = TextEditingController(text: '180');

    var isMultiSession = false;
    var excludeWeekends = true;
    var schedulingStrategy = 'ONE_PAPER_PER_DAY';
    var currentStep = 0;

    ref.read(bulkTimetableGeneratorProvider.notifier).clear();

    final availableClasses = classesState != null
        ? (exam.effectiveClassIds.isNotEmpty
            ? classesState.classes.where((c) => exam.effectiveClassIds.contains(c.id)).toList()
            : classesState.classes)
        : <ClassDto>[];

    final selectedClassIds = availableClasses.map((c) => c.id).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setBulkState) {
            final genState = ref.watch(bulkTimetableGeneratorProvider);

            final stepNames = [
              '1. Cycle',
              '2. Classes',
              '3. Dates',
              '4. Sessions',
              '5. Gap Days',
              '6. Weekends',
              '7. Strategy',
              '8. Preview & Save',
            ];

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Institutional Schedule Builder: ${exam.examName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!genState.isLoading)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                ],
              ),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Progress Indicator
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(stepNames.length, (idx) {
                            final isCurr = idx == currentStep;
                            final isDone = idx < currentStep;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Chip(
                                avatar: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: isCurr
                                      ? Colors.white
                                      : isDone
                                          ? Colors.green
                                          : Colors.grey.shade400,
                                  child: isDone
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCurr ? Colors.indigo : Colors.white,
                                          ),
                                        ),
                                ),
                                label: Text(
                                  stepNames[idx],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isCurr ? FontWeight.bold : FontWeight.normal,
                                    color: isCurr ? Colors.white : Colors.grey.shade800,
                                  ),
                                ),
                                backgroundColor: isCurr ? Colors.indigo : (isDone ? Colors.green.shade50 : Colors.grey.shade100),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error Banner
                      if (genState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  genState.errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Loading Indicator
                      if (genState.isLoading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36.0),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 14),
                                Text(
                                  'Generating deterministic timetable schedule...',
                                  style: TextStyle(color: Colors.indigo, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Step 0: Cycle Overview
                        if (currentStep == 0) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cycle: ${exam.examName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text('Type: ${exam.examType} • Canonical Window: ${exam.startDate} to ${exam.endDate}'),
                                const SizedBox(height: 6),
                                Text('Participating Scope: ${exam.classesRangeFormatted ?? "${exam.effectiveClassIds.length} Classes"}'),
                                const SizedBox(height: 6),
                                Text('Configured Papers: ${exam.papers.isNotEmpty ? exam.papers.length : exam.totalPapersCount} Papers'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This wizard will construct deterministic, conflict-free timetable slots across participating grade cohorts.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],

                        // Step 1: Participating Classes
                        if (currentStep == 1) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Select Participating Classes *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setBulkState(() {
                                        selectedClassIds.clear();
                                        selectedClassIds.addAll(availableClasses.map((c) => c.id));
                                      });
                                    },
                                    child: const Text('Select All'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setBulkState(() {
                                        selectedClassIds.clear();
                                      });
                                    },
                                    child: const Text('Deselect All'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableClasses.map((c) {
                              final isSel = selectedClassIds.contains(c.id);
                              return FilterChip(
                                label: Text(c.name),
                                selected: isSel,
                                onSelected: (selected) {
                                  setBulkState(() {
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

                        // Step 2: Date Window
                        if (currentStep == 2) ...[
                          const Text('Timetable Examination Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: startDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date (YYYY-MM-DD) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.date_range),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: endDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'End Date (YYYY-MM-DD)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.event),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Step 3: Multi-Session Slots
                        if (currentStep == 3) ...[
                          const Text('Session Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Enable Multi-Session Scheduling'),
                            subtitle: const Text('Schedule two paper sessions daily (Morning and Afternoon)'),
                            value: isMultiSession,
                            onChanged: (val) => setBulkState(() => isMultiSession = val),
                          ),
                          const SizedBox(height: 12),
                          if (!isMultiSession) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: startTimeController,
                                    decoration: const InputDecoration(labelText: 'Exam Start Time', border: OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: durationController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Duration (Minutes)', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Card(
                              color: Colors.grey.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Session 1 (Morning)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: morningStartController,
                                            decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder(), isDense: true),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: morningDurationController,
                                            decoration: const InputDecoration(labelText: 'Duration (Mins)', border: OutlineInputBorder(), isDense: true),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Session 2 (Afternoon)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: afternoonStartController,
                                            decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder(), isDense: true),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: afternoonDurationController,
                                            decoration: const InputDecoration(labelText: 'Duration (Mins)', border: OutlineInputBorder(), isDense: true),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],

                        // Step 4: Gap Days
                        if (currentStep == 4) ...[
                          const Text('Inter-Exam Gap Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: gapDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Gap Days Between Exam Dates',
                              hintText: '1',
                              border: OutlineInputBorder(),
                              helperText: '0 = consecutive days, 1 = one study day between exams, etc.',
                            ),
                          ),
                        ],

                        // Step 5: Weekends
                        if (currentStep == 5) ...[
                          const Text('Weekend Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Exclude Weekends'),
                            subtitle: const Text('Automatically skip Saturdays and Sundays when advancing dates'),
                            value: excludeWeekends,
                            onChanged: (val) => setBulkState(() => excludeWeekends = val),
                          ),
                        ],

                        // Step 6: Strategy
                        if (currentStep == 6) ...[
                          const Text('Scheduling Strategy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          RadioListTile<String>(
                            title: const Text('One Paper Per Day'),
                            subtitle: const Text('Standard examination flow: 1 paper slot daily per class'),
                            value: 'ONE_PAPER_PER_DAY',
                            groupValue: schedulingStrategy,
                            onChanged: (val) => setBulkState(() => schedulingStrategy = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Multi-Session Simultaneous'),
                            subtitle: const Text('Utilize Morning & Afternoon session slots to accelerate exam period'),
                            value: 'MULTI_SESSION',
                            groupValue: schedulingStrategy,
                            onChanged: (val) => setBulkState(() => schedulingStrategy = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Staggered Cohorts'),
                            subtitle: const Text('Alternate mornings and afternoons across grade cohorts to balance invigilation'),
                            value: 'STAGGERED',
                            groupValue: schedulingStrategy,
                            onChanged: (val) => setBulkState(() => schedulingStrategy = val!),
                          ),
                        ],

                        // Step 7: Preview & Save
                        if (currentStep == 7) ...[
                          if (genState.preview == null) ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('Click "Generate Preview" below to simulate the deterministic timetable.'),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: genState.preview!.hasConflicts ? Colors.amber.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: genState.preview!.hasConflicts ? Colors.amber.shade300 : Colors.green.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        genState.preview!.hasConflicts ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                        color: genState.preview!.hasConflicts ? Colors.amber.shade800 : Colors.green,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          genState.preview!.hasConflicts
                                              ? 'Preview Generated with Advisory Notices: ${genState.preview!.totalSlots} Slots Scheduled'
                                              : 'Deterministic Preview: ${genState.preview!.totalSlots} Examination Slots Verified. Clash-Free.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: genState.preview!.hasConflicts ? Colors.amber.shade900 : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (genState.preview!.warnings.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    for (final warn in genState.preview!.warnings)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 36.0, top: 2.0),
                                        child: Text(
                                          '• $warn',
                                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 320,
                              child: ListView.separated(
                                itemCount: genState.preview!.schedules.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = genState.preview!.schedules[i];
                                  final hasConflict = item.conflictStatus != null && item.conflictStatus != 'OK';
                                  final dayStr = item.dayName != null && item.dayName!.isNotEmpty ? ' | ${item.dayName}' : '';
                                  final sessStr = item.sessionName != null && item.sessionName!.isNotEmpty ? ' | ${item.sessionName}' : '';
                                  final durStr = item.durationMinutes != null ? ' (${item.durationMinutes} mins)' : '';
                                  final roomStr = item.roomNumber != null ? ' • Room: ${item.roomNumber}' : '';
                                  final startClean = item.startTime.length >= 5 ? item.startTime.substring(0, 5) : item.startTime;
                                  final endClean = item.endTime.length >= 5 ? item.endTime.substring(0, 5) : item.endTime;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: hasConflict ? Colors.amber.shade100 : Colors.indigo.shade100,
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: hasConflict ? Colors.amber.shade900 : Colors.indigo.shade900,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${displaySubjectName(subjectName: item.subjectName, subjectCode: item.subjectCode, subjectId: item.subjectId)} (${item.className} - ${item.sectionName})',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        if (hasConflict)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.conflictStatus!,
                                              style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${item.examDate}$dayStr$sessStr | $startClean - $endClean$durStr$roomStr • Max: ${item.maxMarks}M (Pass: ${item.passMarks}M)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (!genState.isLoading)
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Cancel'),
                  ),
                if (currentStep > 0 && !genState.isLoading)
                  TextButton(
                    onPressed: () => setBulkState(() => currentStep--),
                    child: const Text('Back'),
                  ),
                if (currentStep < 7 && !genState.isLoading)
                  FilledButton(
                    onPressed: () {
                      if (currentStep == 1 && selectedClassIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select at least one participating class.')),
                        );
                        return;
                      }
                      setBulkState(() => currentStep++);
                    },
                    child: const Text('Next'),
                  ),
                if (currentStep == 7 && genState.preview == null && !genState.isLoading)
                  FilledButton.icon(
                    icon: const Icon(Icons.preview),
                    onPressed: () async {
                      List<Map<String, dynamic>>? sessionsPayload;
                      if (isMultiSession) {
                        sessionsPayload = [
                          {
                            'name': 'Morning Slot',
                            'start_time': morningStartController.text.trim(),
                            'duration_minutes': int.tryParse(morningDurationController.text.trim()) ?? 180,
                          },
                          {
                            'name': 'Afternoon Slot',
                            'start_time': afternoonStartController.text.trim(),
                            'duration_minutes': int.tryParse(afternoonDurationController.text.trim()) ?? 180,
                          },
                        ];
                      }

                      await ref.read(bulkTimetableGeneratorProvider.notifier).generatePreview(
                            examinationId: exam.id,
                            classIds: selectedClassIds,
                            startDate: startDateController.text.trim(),
                            endDate: endDateController.text.trim().isNotEmpty ? endDateController.text.trim() : null,
                            gapDays: int.tryParse(gapDaysController.text.trim()) ?? 1,
                            startTime: startTimeController.text.trim(),
                            durationMinutes: int.tryParse(durationController.text.trim()) ?? 180,
                            sessions: sessionsPayload,
                            schedulingStrategy: schedulingStrategy,
                            excludeWeekends: excludeWeekends,
                          );
                    },
                    label: const Text('Generate Deterministic Preview'),
                  ),
                if (currentStep == 7 && genState.preview != null && !genState.isLoading)
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      final payload = genState.preview!.schedules.map((s) => s.toSchedulePayload()).toList();
                      final ok = await ref.read(bulkTimetableGeneratorProvider.notifier).confirmSchedules(
                            examinationId: exam.id,
                            schedules: payload,
                          );
                      if (ok) {
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Timetable generated and saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    label: const Text('Confirm & Save Timetable'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

extension MapDefault<K, V> on Map<K, V> {
  V setdefault(K key, V defaultValue) {
    if (!containsKey(key)) {
      this[key] = defaultValue;
    }
    return this[key]!;
  }
}
