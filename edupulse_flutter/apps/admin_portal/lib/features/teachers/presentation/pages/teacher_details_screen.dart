import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../widgets/teacher_form_dialog.dart';
import '../widgets/assignment_form_dialog.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

class TeacherDetailsScreen extends ConsumerStatefulWidget {
  final String teacherId;

  const TeacherDetailsScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends ConsumerState<TeacherDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshDetails() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.invalidate(teacherDetailProvider(widget.teacherId));
        ref.invalidate(teacherAssignmentsProvider(widget.teacherId));
        
        // Also pre-fetch routing catalogs for mapping labels
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
      }
    });
  }

  Future<void> _deleteTeacher(TeacherDto teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Teacher Profile'),
        content: Text('Are you sure you want to soft-delete ${teacher.fullName}? This will also disable their linked user identity.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      final notifier = ref.read(teacherActionProvider.notifier);
      final success = await notifier.execute(
        method: 'DELETE',
        path: '/teachers/${teacher.id}?school_id=$schoolId',
        successMsg: 'Teacher soft-deleted successfully.',
      );
      if (success && mounted) {
        context.pop(); // Go back to list
      }
    }
  }

  Future<void> _toggleTeacherStatus(TeacherDto teacher) async {
    final newStatus = teacher.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus == 'ACTIVE' ? 'Activate Teacher' : 'Deactivate Teacher'),
        content: Text('Are you sure you want to change status to $newStatus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      final notifier = ref.read(teacherActionProvider.notifier);
      final success = await notifier.execute(
        method: 'PUT',
        path: '/teachers/${teacher.id}?school_id=$schoolId',
        data: {'status': newStatus},
        successMsg: 'Teacher status updated successfully.',
        invalidationId: teacher.id,
      );
      if (success) {
        _refreshDetails();
      }
    }
  }

  void _showFormDialog(BuildContext context, TeacherDto teacher) {
    showDialog(
      context: context,
      builder: (context) => TeacherFormDialog(teacher: teacher),
    ).then((updated) {
      if (updated == true) {
        _refreshDetails();
      }
    });
  }

  void _showAssignmentDialog(BuildContext context, [TeacherSubjectAssignmentDto? assignment]) {
    showDialog(
      context: context,
      builder: (context) => AssignmentFormDialog(
        teacherId: widget.teacherId,
        assignment: assignment,
      ),
    ).then((updated) {
      if (updated == true) {
        _refreshDetails();
      }
    });
  }

  Future<void> _deleteAssignment(TeacherSubjectAssignmentDto assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subject Mapping'),
        content: const Text('Are you sure you want to remove this subject mapping assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      final notifier = ref.read(assignmentActionProvider.notifier);
      final success = await notifier.execute(
        method: 'DELETE',
        path: '/teacher-subject-assignments/${assignment.id}?school_id=$schoolId',
        teacherId: widget.teacherId,
        successMsg: 'Assignment removed successfully.',
      );
      if (success) {
        _refreshDetails();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Details')),
        body: const Center(child: Text('No school campus selected.')),
      );
    }

    final detailAsync = ref.watch(teacherDetailProvider(widget.teacherId));
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider(widget.teacherId));

    // Watch references for labels mapping
    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));
    final subjectsState = ref.watch(subjectsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile & Setup'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Profile Overview'),
            Tab(icon: Icon(Icons.class_outlined), text: 'Subject Mappings'),
          ],
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load details: $err',
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _refreshDetails, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        data: (teacher) {
          final isRetired = teacher.status == 'RETIRED';
          final isActive = teacher.status == 'ACTIVE';

          return assignmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Failed to load assignments: $err')),
            data: (assignments) {
              // Calculate weekly periods sum
              final totalPeriods = assignments.where((a) => a.status == 'ACTIVE').fold<int>(0, (sum, a) => sum + a.weeklyPeriods);

              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Profile Overview
                  _buildOverviewTab(context, teacher, theme, isRetired, isActive),

                  // Tab 2: Subject Assignments & Workloads
                  _buildAssignmentsTab(context, teacher, assignments, totalPeriods, ayState, classesState, sectionsState, subjectsState, theme, isRetired),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    TeacherDto teacher,
    ThemeData theme,
    bool isRetired,
    bool isActive,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Summary Row (Responsive Wrap)
          Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      teacher.firstName.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(teacher.fullName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Designation: ${teacher.designation ?? "N/A"} | Department: ${teacher.department ?? "N/A"}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusIndicator(teacher.status, theme),
                    ],
                  ),
                ],
              ),
              // Profile toolbar commands
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    key: const Key('edit_teacher_profile_button'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                    onPressed: isRetired ? null : () => _showFormDialog(context, teacher),
                  ),
                  OutlinedButton.icon(
                    key: const Key('deactivate_teacher_profile_button'),
                    icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                    label: Text(isActive ? 'Deactivate' : 'Activate'),
                    onPressed: isRetired ? null : () => _toggleTeacherStatus(teacher),
                  ),
                  OutlinedButton.icon(
                    key: const Key('delete_teacher_profile_button'),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () => _deleteTeacher(teacher),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Detail Section Columns
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildDetailCard(
                theme: theme,
                title: 'Employment & Office Information',
                width: 350,
                details: {
                  'Employee Code': teacher.employeeCode,
                  'Staff Code': teacher.staffCode,
                  'Employment Type': teacher.employmentType,
                  'Department': teacher.department ?? 'N/A',
                  'Designation': teacher.designation ?? 'N/A',
                  'Salary (Monthly)': teacher.salary != null ? '\$${teacher.salary!.toStringAsFixed(2)}' : 'N/A',
                  'Joining Date': teacher.joiningDate,
                  'Confirmation Date': teacher.dateOfConfirmation ?? 'N/A',
                  'Resignation Date': teacher.dateOfResignation ?? 'N/A',
                  'Retirement Date': teacher.dateOfRetirement ?? 'N/A',
                },
              ),
              _buildDetailCard(
                theme: theme,
                title: 'Personal & Contact Information',
                width: 350,
                details: {
                  'Official Email': teacher.officialEmail,
                  'Personal Email': teacher.personalEmail ?? 'N/A',
                  'Mobile Number': teacher.mobile,
                  'Alternate Mobile': teacher.alternateMobile ?? 'N/A',
                  'Gender': teacher.gender,
                  'Date of Birth': teacher.dateOfBirth,
                  'Blood Group': teacher.bloodGroup ?? 'N/A',
                  'Aadhaar Number': teacher.aadhaarNumber ?? 'N/A',
                  'PAN Number': teacher.panNumber ?? 'N/A',
                },
              ),
              _buildDetailCard(
                theme: theme,
                title: 'Qualification & Background',
                width: 350,
                details: {
                  'Highest Qualification': teacher.qualification ?? 'N/A',
                  'Area of Specialization': teacher.specialization ?? 'N/A',
                  'Experience (Years)': teacher.experienceYears?.toString() ?? 'N/A',
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(
    BuildContext context,
    TeacherDto teacher,
    List<TeacherSubjectAssignmentDto> assignments,
    int totalPeriods,
    AcademicYearsState ayState,
    ClassesState classesState,
    SectionsState sectionsState,
    SubjectsState subjectsState,
    ThemeData theme,
    bool isRetired,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workload Alert card
          Card(
            color: totalPeriods > 40 ? Colors.red.shade50 : theme.colorScheme.primaryContainer.withOpacity(0.2),
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: totalPeriods > 40 ? Colors.red.shade300 : theme.colorScheme.primary.withOpacity(0.2)),
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
                      Text(
                        'Weekly Period Workload Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                      ),
                      Text(
                        '$totalPeriods / 40 Periods',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: totalPeriods > 40 ? Colors.red.shade700 : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (totalPeriods / 40.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    color: totalPeriods > 40 ? Colors.red : theme.colorScheme.primary,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalPeriods > 40
                        ? 'Warning: Weekly workload periods exceed the max threshold limit of 40 periods.'
                        : 'Workload limits are green and optimal.',
                    style: TextStyle(fontSize: 12, color: totalPeriods > 40 ? Colors.red.shade700 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title & Assign Button Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Academic Assignments Catalog', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                key: const Key('assign_subject_button'),
                icon: const Icon(Icons.add_link),
                label: const Text('Assign Subject'),
                onPressed: isRetired ? null : () => _showAssignmentDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Assignments Roster table
          if (assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text('No subject or class assignments mapped yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Card(
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
                      columns: const [
                        DataColumn(label: Text('Academic Year')),
                        DataColumn(label: Text('Class & Section')),
                        DataColumn(label: Text('Subject')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Periods')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: assignments.map((a) {
                        // Map labels
                        final ayName = ayState.years.firstWhere((y) => y.id == a.academicYearId, orElse: () => const AcademicYearDto(id: '', tenantId: '', schoolId: '', name: 'N/A', code: '', startDate: '', endDate: '', status: '', isCurrent: false, version: 1)).name;
                        final className = classesState.classes.firstWhere((c) => c.id == a.classId, orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: 'N/A', code: '', level: 1, category: 'CORE', capacity: 40, status: '', isActive: true, version: 1)).name;
                        final sectionName = sectionsState.sections.firstWhere((s) => s.id == a.sectionId, orElse: () => const SectionDto(id: '', tenantId: '', schoolId: '', academicYearId: '', classId: '', name: 'N/A', code: '', capacity: 40, sortOrder: 1, status: '', isActive: true, version: 1)).name;
                        final sub = subjectsState.subjects.firstWhere((s) => s.id == a.subjectId, orElse: () => const SubjectDto(id: '', tenantId: '', schoolId: '', academicYearId: '', subjectCode: '', subjectName: 'N/A', category: 'CORE', subjectType: 'THEORY', theoryMarks: 100, practicalMarks: 0, passMarks: 40, status: 'ACTIVE', isActive: true, version: 1));

                        return DataRow(
                          cells: [
                            DataCell(Text(ayName)),
                            DataCell(Text('$className - $sectionName')),
                            DataCell(Text('${sub.subjectName} (${sub.subjectCode})')),
                            DataCell(Text(a.assignmentType)),
                            DataCell(Text('${a.weeklyPeriods} / wk')),
                            DataCell(
                              Text(
                                a.isClassTeacher ? 'Class Teacher' : 'Teacher',
                                style: TextStyle(
                                  color: a.isClassTeacher ? theme.colorScheme.primary : Colors.black,
                                  fontWeight: a.isClassTeacher ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            DataCell(_buildStatusChip(a.status, theme)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: Key('edit_assignment_${a.id}'),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit Assignment',
                                    onPressed: isRetired ? null : () => _showAssignmentDialog(context, a),
                                  ),
                                  IconButton(
                                    key: Key('remove_assignment_${a.id}'),
                                    icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
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
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required ThemeData theme,
    required String title,
    required double width,
    required Map<String, String> details,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const Divider(height: 24),
            ...details.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                    ),
                    Expanded(
                      child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'ACTIVE':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'INACTIVE':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'ON_LEAVE':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'RETIRED':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      case 'ARCHIVED':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      case 'TRANSFERRED':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      default:
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, ThemeData theme) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.red;
        break;
      case 'ON_LEAVE':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fiber_manual_record, color: color, size: 14),
        const SizedBox(width: 6),
        Text(status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
