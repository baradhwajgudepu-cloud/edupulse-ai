import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../widgets/teacher_form_dialog.dart';
import '../widgets/teacher_360_modal.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../bulk_import/presentation/widgets/flexible_import_wizard_modal.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  final _searchController = TextEditingController();
  final _hScrollController = ScrollController();
  final _vScrollController = ScrollController();

  bool _isCardView = true;
  String _personnelType = 'all'; // 'all', 'teaching', 'non-teaching'

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
    _hScrollController.dispose();
    _vScrollController.dispose();
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

  Future<void> _resetTeacherPassword(TeacherDto teacher, String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Are you sure you want to reset credentials for ${teacher.fullName} (${teacher.officialEmail})? A temporary password will be generated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      String? tempPassword;

      if (teacher.userId != null) {
        final res = await apiClient.post(
          '/identity/users/${teacher.userId}/reset-password',
          mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
        );
        res.when(
          onSuccess: (data) => tempPassword = data?['temporary_password'] as String?,
          onFailure: (err) => throw Exception(err.message),
        );
      } else {
        final provRes = await apiClient.post(
          '/identity/provision/staff/${teacher.id}?school_id=$schoolId',
          mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
        );
        String? newUserId;
        provRes.when(
          onSuccess: (data) => newUserId = data?['id'] as String?,
          onFailure: (err) => throw Exception(err.message),
        );
        if (newUserId != null) {
          final res = await apiClient.post(
            '/identity/users/$newUserId/reset-password',
            mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
          );
          res.when(
            onSuccess: (data) => tempPassword = data?['temporary_password'] as String?,
            onFailure: (err) => throw Exception(err.message),
          );
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Password Reset Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staff: ${teacher.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Email: ${teacher.officialEmail}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        tempPassword ?? 'EduPulse@123',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tempPassword ?? 'EduPulse@123'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Temporary password copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share this temporary password with the teacher. They must update it on first sign-in.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openStaff360(TeacherDto teacher, String schoolId) {
    _openTeacher360(teacher, schoolId);
  }

  void _openTeacher360(TeacherDto teacher, String schoolId) {
    Teacher360Modal.show(
      context,
      teacher: teacher,
      schoolId: schoolId,
      onEdit: teacher.status == 'RETIRED'
          ? null
          : () {
              Navigator.of(context).pop();
              _showFormDialog(context, teacher);
            },
      onToggleStatus: teacher.status == 'RETIRED'
          ? null
          : () {
              Navigator.of(context).pop();
              _toggleTeacherStatus(teacher);
            },
      onResetPassword: teacher.status == 'RETIRED'
          ? null
          : () {
              Navigator.of(context).pop();
              _resetTeacherPassword(teacher, schoolId);
            },
    );
  }

  String _formatINR(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final listState = ref.watch(teachersListProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

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

    // Apply client-side personnel type filter if selected
    final filteredTeachers = listState.teachers.where((t) {
      if (_personnelType == 'teaching') {
        final d = (t.designation ?? '').toUpperCase();
        final dept = (t.department ?? '').toUpperCase();
        return d.contains('TGT') ||
            d.contains('PGT') ||
            d.contains('PRT') ||
            d.contains('TEACHER') ||
            d.contains('FACULTY') ||
            d.contains('HOD') ||
            d.contains('PROFESSOR') ||
            dept.contains('SCIENCE') ||
            dept.contains('MATH') ||
            dept.contains('ENGLISH') ||
            dept.contains('SOCIAL');
      } else if (_personnelType == 'non-teaching') {
        final d = (t.designation ?? '').toUpperCase();
        final dept = (t.department ?? '').toUpperCase();
        final isTeaching = d.contains('TGT') ||
            d.contains('PGT') ||
            d.contains('PRT') ||
            d.contains('TEACHER') ||
            d.contains('FACULTY') ||
            d.contains('HOD') ||
            d.contains('PROFESSOR') ||
            dept.contains('SCIENCE') ||
            dept.contains('MATH') ||
            dept.contains('ENGLISH') ||
            dept.contains('SOCIAL');
        return !isTeaching;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers & Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'import_teacher_fab',
                  tooltip: 'Import Staff',
                  onPressed: () => FlexibleImportWizardModal.show(context, importEntity: 'teachers'),
                  child: const Icon(Icons.upload_file_outlined),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'add_teacher_fab',
                  key: const Key('add_teacher_fab'),
                  onPressed: () => _showFormDialog(context),
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Directory Header Card matching Gemini AI Studio Prototype
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teachers & Staff Directory',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 18 : 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Teaching faculty, administrative personnel, laboratory officers, and attendance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    key: const Key('import_teacher_button'),
                    onPressed: () => FlexibleImportWizardModal.show(context, importEntity: 'teachers'),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import Staff'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('add_teacher_button'),
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Staff Member'),
                  ),
                ],
              ],
            ),
          ),

          // 2. Filter Toolbar matching Gemini AI Studio Prototype
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search box
                        Expanded(
                          child: TextField(
                            key: const Key('teacher_search_field'),
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by faculty name, subject, department...',
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (val) {
                              ref.read(teachersListProvider.notifier).updateFilters(search: val.trim());
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        // View mode toggle (Cards / Table)
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.grid_view_outlined, size: 18),
                              tooltip: 'Card Grid View',
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.table_rows_outlined, size: 18),
                              tooltip: 'Compact Table View',
                            ),
                          ],
                          selected: {_isCardView},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isCardView = newSelection.first;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Filter Pills & Dropdowns
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Personnel Type Pills
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPersonnelPill('all', 'All Personnel'),
                            const SizedBox(width: 6),
                            _buildPersonnelPill('teaching', 'Teaching'),
                            const SizedBox(width: 6),
                            _buildPersonnelPill('non-teaching', 'Non-Teaching'),
                          ],
                        ),

                        // Dropdown: Status
                        SizedBox(
                          width: 150,
                          child: SafeDropdownButtonFormField<String>(
                            key: const Key('status_filter_dropdown'),
                            isExpanded: true,
                            value: listState.status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                        // Dropdown: Department
                        SizedBox(
                          width: 160,
                          child: SafeDropdownButtonFormField<String>(
                            key: const Key('dept_filter_dropdown'),
                            isExpanded: true,
                            value: listState.department,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          child: SafeDropdownButtonFormField<String>(
                            key: const Key('desg_filter_dropdown'),
                            isExpanded: true,
                            value: listState.designation,
                            decoration: const InputDecoration(
                              labelText: 'Designation',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Roster Body
          Expanded(
            child: _buildRosterBody(context, listState, filteredTeachers, isMobile, theme, schoolId),
          ),

          // 4. Paged Controller Footer Bar
          _buildPaginationFooter(listState),
        ],
      ),
    );
  }

  Widget _buildPersonnelPill(String type, String label) {
    final isSelected = _personnelType == type;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _personnelType = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (theme.brightness == Brightness.dark ? EduPulseTheme.slate100 : EduPulseTheme.slate900)
              : (theme.brightness == Brightness.dark ? EduPulseTheme.slate800 : EduPulseTheme.slate100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (theme.brightness == Brightness.dark ? EduPulseTheme.slate900 : Colors.white)
                : (theme.brightness == Brightness.dark ? EduPulseTheme.slate300 : EduPulseTheme.slate700),
          ),
        ),
      ),
    );
  }

  Widget _buildRosterBody(
    BuildContext context,
    TeacherListState state,
    List<TeacherDto> displayTeachers,
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

    if (displayTeachers.isEmpty) {
      final hasActiveFilters = _searchController.text.isNotEmpty ||
          _personnelType != 'all' ||
          state.department != null ||
          state.designation != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.badge_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasActiveFilters
                    ? 'No teacher profiles found matching filters'
                    : 'No teachers found for the current school and academic year.',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  hasActiveFilters
                      ? 'Try clearing active filters or adjusting your search term.'
                      : 'Invite your first teacher or import your complete faculty roster from Excel or CSV.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (hasActiveFilters) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _personnelType = 'all';
                        });
                        ref.read(teachersListProvider.notifier).updateFilters(
                              search: '',
                              department: null,
                              designation: null,
                              status: null,
                            );
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                  ElevatedButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry / Refresh'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Staff Member'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => FlexibleImportWizardModal.show(context, importEntity: 'teachers'),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import Staff Roster'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isCardView) {
      return _buildCardGrid(context, displayTeachers, theme, schoolId);
    }

    return _buildCompactTable(context, displayTeachers, theme, schoolId);
  }

  Widget _buildCardGrid(
    BuildContext context,
    List<TeacherDto> teachers,
    ThemeData theme,
    String schoolId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width < 640) {
          crossAxisCount = 1;
        } else if (width < 1080) {
          crossAxisCount = 2;
        } else if (width < 1550) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 260,
          ),
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            final t = teachers[index];
            return _buildStaffCard(context, t, theme, schoolId);
          },
        );
      },
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    TeacherDto t,
    ThemeData theme,
    String schoolId,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    Color statusColor;
    switch (t.status.toUpperCase()) {
      case 'ACTIVE':
        statusColor = Colors.green;
        break;
      case 'ON_LEAVE':
        statusColor = Colors.orange;
        break;
      case 'RETIRED':
        statusColor = Colors.blueGrey;
        break;
      default:
        statusColor = Colors.red;
    }

    final initials = (t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '') +
        (t.lastName.isNotEmpty ? t.lastName[0].toUpperCase() : '');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openStaff360(t, schoolId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top: Avatar + Name + Designation + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                            ? NetworkImage(t.photoUrl!)
                            : null,
                        child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                            ? Text(
                                initials.isNotEmpty ? initials : 'ST',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? EduPulseTheme.slate900 : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.designation ?? 'Faculty Member',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          t.employeeCode.isNotEmpty ? t.employeeCode : t.staffCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(t.status, theme),
                ],
              ),

              // Middle: Department & Contact details
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.department ?? 'General Academics',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.mobile.isNotEmpty ? t.mobile : 'No Mobile',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.officialEmail.isNotEmpty ? t.officialEmail : 'No Email',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom: Salary / Info & Action Buttons
              Column(
                children: [
                  Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Salary display ONLY if real data exists
                      if (t.salary != null && t.salary! > 0)
                        Text(
                          _formatINR(t.salary!),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      else
                        Text(
                          t.employmentType.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),

                      // Direct Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('view_teacher_${t.employeeCode}'),
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            tooltip: 'View Teacher 360',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _openTeacher360(t, schoolId),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            key: Key('edit_teacher_${t.employeeCode}'),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit Profile',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: t.status == 'RETIRED' ? null : () => _showFormDialog(context, t),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            key: Key('toggle_status_${t.employeeCode}'),
                            icon: Icon(
                              t.status == 'ACTIVE' ? Icons.block : Icons.check_circle_outline,
                              size: 18,
                            ),
                            tooltip: t.status == 'ACTIVE' ? 'Deactivate' : 'Activate',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: t.status == 'RETIRED' ? null : () => _toggleTeacherStatus(t),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            key: Key('reset_pwd_${t.employeeCode}'),
                            icon: const Icon(Icons.lock_reset, size: 18),
                            tooltip: 'Reset Password',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: t.status == 'RETIRED' ? null : () => _resetTeacherPassword(t, schoolId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTable(
    BuildContext context,
    List<TeacherDto> teachers,
    ThemeData theme,
    String schoolId,
  ) {
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
          controller: _hScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _hScrollController,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              controller: _vScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vScrollController,
                scrollDirection: Axis.vertical,
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
                  rows: teachers.map((t) {
                    return DataRow(
                      cells: [
                        DataCell(Text(t.employeeCode)),
                        DataCell(Text(t.staffCode)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: InkWell(
                              onTap: () => _openStaff360(t, schoolId),
                              child: Text(
                                t.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(t.department ?? 'N/A')),
                        DataCell(Text(t.designation ?? 'N/A')),
                        DataCell(Text(t.employmentType)),
                        DataCell(Text(t.mobile)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(t.officialEmail, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(_buildStatusChip(t.status, theme)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: Key('view_teacher_${t.employeeCode}'),
                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                tooltip: 'View Teacher 360',
                                onPressed: () => _openTeacher360(t, schoolId),
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
                              IconButton(
                                key: Key('reset_pwd_${t.employeeCode}'),
                                icon: const Icon(Icons.lock_reset, size: 20),
                                tooltip: 'Reset Password',
                                onPressed: t.status == 'RETIRED' ? null : () => _resetTeacherPassword(t, schoolId),
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
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color bgColor;
    Color textColor;

    switch (status.toUpperCase()) {
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
        bgColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
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
