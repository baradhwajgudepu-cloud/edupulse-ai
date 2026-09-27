import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../widgets/assignment_form_dialog.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../../core/routing/routes.dart';

T? _findFirst<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends ConsumerState<TeacherAssignmentsScreen> {
  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedTeacherId;
  String? _selectedSubjectId;
  String? _selectedStatus;
  String? _selectedType;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
        ref.read(teachersListProvider.notifier).fetchTeachers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAssignmentDialog({
    TeacherSubjectAssignmentDto? assignment,
    bool isClassTeacher = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AssignmentFormDialog(
        assignment: assignment,
        teacherId: assignment?.teacherId,
        initialAcademicYearId: _selectedAyId,
        initialClassId: _selectedClassId,
        initialSectionId: _selectedSectionId,
        initialSubjectId: _selectedSubjectId,
        isClassTeacherDefault: isClassTeacher,
      ),
    );

    if (res == true && mounted) {
      ref.invalidate(allTeacherAssignmentsProvider);
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(teachersListProvider.notifier).fetchTeachers();
      }
    }
  }

  Future<void> _deleteAssignment(TeacherSubjectAssignmentDto assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Assignment?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove this academic assignment?'),
            SizedBox(height: 8),
            Text(
              'Existing timetable period slots mapped to this assignment will be archived.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId == null) return;

      final success = await ref.read(assignmentActionProvider.notifier).execute(
        method: 'DELETE',
        path: '/teacher-subject-assignments/${assignment.id}?school_id=$schoolId',
        teacherId: assignment.teacherId,
        successMsg: 'Assignment removed successfully.',
      );

      if (success && mounted) {
        ref.invalidate(allTeacherAssignmentsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() {
          _selectedAyId = null;
          _selectedClassId = null;
          _selectedSectionId = null;
          _selectedTeacherId = null;
          _selectedSubjectId = null;
        });
        _initData();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Assignments')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top bar selector to manage its teacher assignments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));
    final subjectsState = ref.watch(subjectsProvider(schoolId));
    final teachersState = ref.watch(teachersListProvider);

    // Default to current academic year if none selected
    if (ayState.years.isNotEmpty && _selectedAyId == null) {
      final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      _selectedAyId = current.id;
    }

    final assignmentsAsync = ref.watch(allTeacherAssignmentsProvider((
      schoolId: schoolId,
      academicYearId: _selectedAyId,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      teacherId: _selectedTeacherId,
      subjectId: _selectedSubjectId,
      status: _selectedStatus,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    )));

    // Filter sections for dropdown by class
    final availableSections = _selectedClassId == null
        ? sectionsState.sections
        : sectionsState.sections.where((s) => s.classId == _selectedClassId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Teacher Assignments'),
            Text('Assign and manage academic workload across classes and subjects', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Assignments',
            onPressed: () {
              ref.invalidate(allTeacherAssignmentsProvider);
              _initData();
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('assign_class_teacher_button'),
            icon: const Icon(Icons.stars_outlined, size: 18),
            label: const Text('Assign Class Teacher'),
            onPressed: () => _openAssignmentDialog(isClassTeacher: true),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            key: const Key('add_assignment_button'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Assignment'),
            onPressed: () => _openAssignmentDialog(isClassTeacher: false),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(
            context,
            theme,
            ayState,
            classesState,
            availableSections,
            subjectsState,
            teachersState,
          ),

          // Assignments Content
          Expanded(
            child: assignmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load assignments: $err',
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(allTeacherAssignmentsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (assignments) {
                // Client-side type filter if set
                final filtered = _selectedType == null
                    ? assignments
                    : assignments.where((a) => a.assignmentType == _selectedType).toList();

                return _buildAssignmentsView(
                  context,
                  theme,
                  filtered,
                  isMobile,
                  ayState,
                  classesState,
                  sectionsState,
                  subjectsState,
                  teachersState,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ThemeData theme,
    dynamic ayState,
    dynamic classesState,
    List<dynamic> availableSections,
    dynamic subjectsState,
    dynamic teachersState,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Academic Year
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedAyId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final y in ayState.years)
                        DropdownMenuItem<String>(
                          value: y.id,
                          child: Text('${y.name}${y.isCurrent ? " *" : ""}'),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedAyId = val),
                  ),
                ),

                // Class Filter
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                      for (final c in classesState.classes)
                        DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedClassId = val;
                        _selectedSectionId = null;
                      });
                    },
                  ),
                ),

                // Section Filter
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                      for (final s in availableSections)
                        DropdownMenuItem<String>(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (val) => setState(() => _selectedSectionId = val),
                  ),
                ),

                // Teacher Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Filter Teacher',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('All Teachers')),
                      for (final t in teachersState.teachers)
                        DropdownMenuItem<String>(
                          value: t.id,
                          child: Text('${t.firstName} ${t.lastName}'),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedTeacherId = val),
                  ),
                ),

                // Status Filter
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<String>(value: null, child: Text('All Statuses')),
                      DropdownMenuItem<String>(value: 'ACTIVE', child: Text('ACTIVE')),
                      DropdownMenuItem<String>(value: 'INACTIVE', child: Text('INACTIVE')),
                      DropdownMenuItem<String>(value: 'TRANSFERRED', child: Text('TRANSFERRED')),
                    ],
                    onChanged: (val) => setState(() => _selectedStatus = val),
                  ),
                ),

                // Search field
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search mappings',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),

                // Reset Filters Button
                if (_selectedClassId != null ||
                    _selectedSectionId != null ||
                    _selectedTeacherId != null ||
                    _selectedStatus != null ||
                    _searchController.text.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Reset'),
                    onPressed: () {
                      setState(() {
                        _selectedClassId = null;
                        _selectedSectionId = null;
                        _selectedTeacherId = null;
                        _selectedStatus = null;
                        _searchController.clear();
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsView(
    BuildContext context,
    ThemeData theme,
    List<TeacherSubjectAssignmentDto> assignments,
    bool isMobile,
    dynamic ayState,
    dynamic classesState,
    dynamic sectionsState,
    dynamic subjectsState,
    dynamic teachersState,
  ) {
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_ind_outlined, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No Teacher Assignments Found',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No academic subject mappings match the currently selected filters.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Assign Teacher Now'),
                onPressed: () => _openAssignmentDialog(isClassTeacher: false),
              ),
            ],
          ),
        ),
      );
    }

    // Compute stats
    final totalMappings = assignments.length;
    final classTeachersCount = assignments.where((a) => a.isClassTeacher).length;
    final totalWeeklyPeriods = assignments.fold<int>(0, (sum, a) => sum + a.weeklyPeriods);
    final activeTeachersCount = assignments.map((a) => a.teacherId).toSet().length;

    // Check if a section is selected and identify its class teacher
    final selectedSection = _selectedSectionId != null
        ? _findFirst<SectionDto>(sectionsState.sections as List<SectionDto>, (s) => s.id == _selectedSectionId)
        : null;
    final sectionClassTeacher = selectedSection != null
        ? _findFirst<TeacherSubjectAssignmentDto>(assignments, (a) => a.sectionId == selectedSection.id && a.isClassTeacher)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Class Teacher Banner if Section Filtered
          if (selectedSection != null)
            _buildSectionClassTeacherBanner(context, theme, selectedSection, sectionClassTeacher, teachersState),

          // Statistics Banner
          _buildStatsRow(theme, totalMappings, classTeachersCount, activeTeachersCount, totalWeeklyPeriods),
          const SizedBox(height: 16),

          // Table / Mobile Cards
          if (isMobile)
            _buildMobileCardsList(context, theme, assignments, ayState, classesState, sectionsState, subjectsState, teachersState)
          else
            _buildDesktopTable(context, theme, assignments, ayState, classesState, sectionsState, subjectsState, teachersState),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionClassTeacherBanner(
    BuildContext context,
    ThemeData theme,
    dynamic section,
    TeacherSubjectAssignmentDto? ctAssignment,
    dynamic teachersState,
  ) {
    TeacherDto? teacher;
    if (ctAssignment != null) {
      teacher = _findFirst(teachersState.teachers, (t) => t.id == ctAssignment.teacherId);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: ctAssignment != null ? Colors.blue.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ctAssignment != null ? Colors.blue.shade300 : Colors.amber.shade400,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ctAssignment != null ? Icons.stars : Icons.warning_amber_rounded,
            color: ctAssignment != null ? Colors.blue.shade700 : Colors.amber.shade800,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctAssignment != null
                      ? 'Class Teacher: ${teacher != null ? "${teacher.firstName} ${teacher.lastName} (${teacher.employeeCode})" : "Assigned"}'
                      : 'No Class Teacher Assigned for ${section.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ctAssignment != null ? Colors.blue.shade900 : Colors.amber.shade900,
                  ),
                ),
                Text(
                  ctAssignment != null
                      ? 'Directs academic sessions and daily attendance for ${section.name}.'
                      : 'Every section should have an assigned class teacher for attendance and pastoral oversight.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ctAssignment != null ? Colors.blue.shade700 : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
          if (ctAssignment != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Change Class Teacher'),
              onPressed: () => _openAssignmentDialog(assignment: ctAssignment, isClassTeacher: true),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Assign Class Teacher'),
              onPressed: () => _openAssignmentDialog(isClassTeacher: true),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    ThemeData theme,
    int totalMappings,
    int classTeachersCount,
    int activeTeachersCount,
    int totalWeeklyPeriods,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        if (isNarrow) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatChip(theme, 'Total Mappings', totalMappings.toString(), Icons.assignment_ind_outlined),
              _buildStatChip(theme, 'Class Teachers', classTeachersCount.toString(), Icons.stars_outlined),
              _buildStatChip(theme, 'Active Teachers', activeTeachersCount.toString(), Icons.people_outline),
              _buildStatChip(theme, 'Weekly Periods', '$totalWeeklyPeriods periods', Icons.timer_outlined),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildStatChip(theme, 'Total Mappings', totalMappings.toString(), Icons.assignment_ind_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatChip(theme, 'Class Teachers', classTeachersCount.toString(), Icons.stars_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatChip(theme, 'Active Teachers', activeTeachersCount.toString(), Icons.people_outline)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatChip(theme, 'Weekly Periods', '$totalWeeklyPeriods periods', Icons.timer_outlined)),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(ThemeData theme, String label, String value, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    ThemeData theme,
    List<TeacherSubjectAssignmentDto> assignments,
    dynamic ayState,
    dynamic classesState,
    dynamic sectionsState,
    dynamic subjectsState,
    dynamic teachersState,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              horizontalMargin: 12,
              headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
              columns: const [
                DataColumn(label: Text('Teacher')),
                DataColumn(label: Text('Academic Year')),
                DataColumn(label: Text('Class & Section')),
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Role / Type')),
                DataColumn(label: Text('Periods')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: assignments.map((a) {
                // Resolving display names
                final teacher = _findFirst<TeacherDto>(teachersState.teachers as List<TeacherDto>, (t) => t.id == a.teacherId);
                final teacherName = teacher != null ? '${teacher.firstName} ${teacher.lastName}' : 'Unknown Teacher';
                final teacherCode = teacher?.employeeCode ?? '';

                final ayName = _findFirst<AcademicYearDto>(ayState.years as List<AcademicYearDto>, (y) => y.id == a.academicYearId)?.name ?? 'N/A';
                final className = _findFirst<ClassDto>(classesState.classes as List<ClassDto>, (c) => c.id == a.classId)?.name ?? 'N/A';
                final sectionName = _findFirst<SectionDto>(sectionsState.sections as List<SectionDto>, (s) => s.id == a.sectionId)?.name ?? 'N/A';
                final subject = _findFirst<SubjectDto>(subjectsState.subjects as List<SubjectDto>, (s) => s.id == a.subjectId);
                final subjectName = subject?.subjectName ?? 'N/A';
                final subjectCode = subject?.subjectCode ?? '';

                return DataRow(
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () => context.push('${AppRoutes.teachers}/${a.teacherId}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  teacherName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                if (teacherCode.isNotEmpty)
                                  Text(teacherCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(ayName)),
                    DataCell(
                      InkWell(
                        onTap: () => context.push('${AppRoutes.sections}/${a.sectionId}?school_id=${a.schoolId}'),
                        child: Text(
                          '$className - $sectionName',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    DataCell(Text(subjectCode.isNotEmpty ? '$subjectName ($subjectCode)' : subjectName)),
                    DataCell(
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (a.isClassTeacher)
                            Chip(
                              avatar: const Icon(Icons.stars, size: 14, color: Colors.white),
                              label: const Text('Class Teacher', style: TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: theme.colorScheme.primary,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          Text(a.assignmentType),
                        ],
                      ),
                    ),
                    DataCell(Text('${a.weeklyPeriods} / wk')),
                    DataCell(_buildStatusChip(a.status, theme)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('edit_assignment_${a.id}'),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit Assignment',
                            onPressed: () => _openAssignmentDialog(assignment: a),
                          ),
                          IconButton(
                            key: Key('delete_assignment_${a.id}'),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Remove Assignment',
                            onPressed: () => _deleteAssignment(a),
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
    );
  }

  Widget _buildMobileCardsList(
    BuildContext context,
    ThemeData theme,
    List<TeacherSubjectAssignmentDto> assignments,
    dynamic ayState,
    dynamic classesState,
    dynamic sectionsState,
    dynamic subjectsState,
    dynamic teachersState,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final a = assignments[index];
        final teacher = _findFirst<TeacherDto>(teachersState.teachers as List<TeacherDto>, (t) => t.id == a.teacherId);
        final teacherName = teacher != null ? '${teacher.firstName} ${teacher.lastName}' : 'Teacher (${a.teacherId})';
        final teacherCode = teacher?.employeeCode ?? '';

        final className = _findFirst<ClassDto>(classesState.classes as List<ClassDto>, (c) => c.id == a.classId)?.name ?? 'N/A';
        final sectionName = _findFirst<SectionDto>(sectionsState.sections as List<SectionDto>, (s) => s.id == a.sectionId)?.name ?? 'N/A';
        final subject = _findFirst<SubjectDto>(subjectsState.subjects as List<SubjectDto>, (s) => s.id == a.subjectId);
        final subjectName = subject?.subjectName ?? 'Subject';

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        teacherName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStatusChip(a.status, theme),
                  ],
                ),
                if (teacherCode.isNotEmpty) Text('Code: $teacherCode', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 16),
                Text('Class & Section: $className - $sectionName', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('Subject: $subjectName', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (a.isClassTeacher)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('Class Teacher', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text('${a.weeklyPeriods} periods / wk • ${a.assignmentType}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      onPressed: () => _openAssignmentDialog(assignment: a),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: Key('delete_assignment_${a.id}'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                      onPressed: () => _deleteAssignment(a),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color bg;
    Color text;
    switch (status) {
      case 'ACTIVE':
        bg = Colors.green.shade50;
        text = Colors.green.shade700;
        break;
      case 'INACTIVE':
        bg = Colors.red.shade50;
        text = Colors.red.shade700;
        break;
      case 'TRANSFERRED':
        bg = Colors.orange.shade50;
        text = Colors.orange.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
