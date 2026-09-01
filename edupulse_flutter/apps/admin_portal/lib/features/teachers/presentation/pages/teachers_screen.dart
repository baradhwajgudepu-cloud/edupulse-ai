import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../widgets/teacher_form_dialog.dart';
import '../../../../core/routing/routes.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(teachersListProvider.notifier).fetchTeachers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    ref.read(teachersListProvider.notifier).fetchTeachers();
  }

  void _showFormDialog(BuildContext context, [TeacherDto? teacher]) {
    showDialog(
      context: context,
      builder: (context) => TeacherFormDialog(teacher: teacher),
    ).then((updated) {
      if (updated == true) {
        _refreshData();
      }
    });
  }

  Future<void> _toggleTeacherStatus(TeacherDto teacher) async {
    final newStatus = teacher.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus == 'ACTIVE' ? 'Activate Teacher' : 'Deactivate Teacher'),
        content: Text('Are you sure you want to change the status of ${teacher.fullName} to $newStatus?'),
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
      );
      if (success) {
        _refreshData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final listState = ref.watch(teachersListProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Handle school context listener
    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        _searchController.clear();
        ref.read(teachersListProvider.notifier).updateFilters(search: '');
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teachers & Staff')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers & Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              key: const Key('add_teacher_fab'),
              onPressed: () => _showFormDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Panel Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search box
                    SizedBox(
                      width: 250,
                      child: TextField(
                        key: const Key('teacher_search_field'),
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, code...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(teachersListProvider.notifier).updateFilters(search: '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (val) {
                          ref.read(teachersListProvider.notifier).updateFilters(search: val.trim());
                        },
                      ),
                    ),

                    // Dropdown: Status
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        key: const Key('status_filter_dropdown'),
                        isExpanded: true,
                        value: listState.status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Statuses')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                          DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                          DropdownMenuItem(value: 'ON_LEAVE', child: Text('ON_LEAVE')),
                          DropdownMenuItem(value: 'RETIRED', child: Text('RETIRED')),
                        ],
                        onChanged: (val) {
                          ref.read(teachersListProvider.notifier).updateFilters(status: val);
                        },
                      ),
                    ),

                    // Dropdown: Department (Fuzzy filters or text filters. Let's make basic dropdown options)
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        key: const Key('dept_filter_dropdown'),
                        isExpanded: true,
                        value: listState.department,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Departments')),
                          DropdownMenuItem(value: 'Science', child: Text('Science')),
                          DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                          DropdownMenuItem(value: 'English', child: Text('English')),
                          DropdownMenuItem(value: 'Social Science', child: Text('Social Science')),
                          DropdownMenuItem(value: 'Arts & Sports', child: Text('Arts & Sports')),
                        ],
                        onChanged: (val) {
                          ref.read(teachersListProvider.notifier).updateFilters(department: val);
                        },
                      ),
                    ),

                    // Dropdown: Designation
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        key: const Key('desg_filter_dropdown'),
                        isExpanded: true,
                        value: listState.designation,
                        decoration: const InputDecoration(
                          labelText: 'Designation',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Designations')),
                          DropdownMenuItem(value: 'TGT', child: Text('TGT')),
                          DropdownMenuItem(value: 'PGT', child: Text('PGT')),
                          DropdownMenuItem(value: 'PRT', child: Text('PRT')),
                          DropdownMenuItem(value: 'HOD', child: Text('HOD')),
                          DropdownMenuItem(value: 'Coordinator', child: Text('Coordinator')),
                        ],
                        onChanged: (val) {
                          ref.read(teachersListProvider.notifier).updateFilters(designation: val);
                        },
                      ),
                    ),

                    // Action buttons
                    if (!isMobile)
                      ElevatedButton.icon(
                        key: const Key('add_teacher_button'),
                        onPressed: () => _showFormDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Teacher'),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Main Listing Grid / List View
          Expanded(
            child: _buildRosterBody(context, listState, isMobile, theme, schoolId),
          ),

          // Paged controller footer bar
          _buildPaginationFooter(listState),
        ],
      ),
    );
  }

  Widget _buildRosterBody(
    BuildContext context,
    TeacherListState state,
    bool isMobile,
    ThemeData theme,
    String schoolId,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load teachers: ${state.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.teachers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No teacher profiles found matching filters.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.teachers.length,
        itemBuilder: (context, index) {
          final t = state.teachers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Code: ${t.employeeCode} | Dept: ${t.department ?? "N/A"}\nDesignation: ${t.designation ?? "N/A"}',
              ),
              trailing: _buildStatusChip(t.status, theme),
              onTap: () {
                context.push('${AppRoutes.teachers}/${t.id}?school_id=$schoolId');
              },
            ),
          );
        },
      );
    }

    // Desktop: Renders clean DataTable
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employee Code')),
                  DataColumn(label: Text('Staff Code')),
                  DataColumn(label: Text('Teacher Name')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Designation')),
                  DataColumn(label: Text('Employment Type')),
                  DataColumn(label: Text('Mobile')),
                  DataColumn(label: Text('Official Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: state.teachers.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.employeeCode)),
                      DataCell(Text(t.staffCode)),
                      DataCell(
                        Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataCell(Text(t.department ?? 'N/A')),
                      DataCell(Text(t.designation ?? 'N/A')),
                      DataCell(Text(t.employmentType)),
                      DataCell(Text(t.mobile)),
                      DataCell(Text(t.officialEmail)),
                      DataCell(_buildStatusChip(t.status, theme)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('view_teacher_${t.employeeCode}'),
                              icon: const Icon(Icons.visibility_outlined, size: 20),
                              tooltip: 'View Profile',
                              onPressed: () {
                                context.push('${AppRoutes.teachers}/${t.id}?school_id=$schoolId');
                              },
                            ),
                            IconButton(
                              key: Key('edit_teacher_${t.employeeCode}'),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit Profile',
                              onPressed: t.status == 'RETIRED' ? null : () => _showFormDialog(context, t),
                            ),
                            IconButton(
                              key: Key('toggle_status_${t.employeeCode}'),
                              icon: Icon(
                                t.status == 'ACTIVE' ? Icons.block : Icons.check_circle_outline,
                                size: 20,
                              ),
                              tooltip: t.status == 'ACTIVE' ? 'Deactivate' : 'Activate',
                              onPressed: t.status == 'RETIRED' ? null : () => _toggleTeacherStatus(t),
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
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaginationFooter(TeacherListState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Total: ${state.total}'),
          const SizedBox(width: 24),
          Text(
            '${state.skip + 1} - ${(state.skip + state.limit).clamp(0, state.total)}',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: state.skip > 0
                ? () => ref.read(teachersListProvider.notifier).prevPage()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: state.hasMore
                ? () => ref.read(teachersListProvider.notifier).nextPage()
                : null,
          ),
        ],
      ),
    );
  }
}
