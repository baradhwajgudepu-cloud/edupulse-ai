import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/student_models.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final Set<String> _selectedStudentIds = {};
  Timer? _debounceTimer;

  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        ref.read(studentListProvider.notifier).fetchStudents();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() => _selectedStudentIds.clear());
      ref.read(studentListProvider.notifier).updateFilters(search: value);
    });
  }

  void _refreshData() {
    ref.read(studentListProvider.notifier).fetchStudents();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedAyId = null;
      _selectedClassId = null;
      _selectedSectionId = null;
      _selectedStatus = null;
      _selectedStudentIds.clear();
    });
    ref.read(studentListProvider.notifier).updateFilters(
          academicYearId: null,
          classId: null,
          sectionId: null,
          status: null,
          search: '',
        );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Invalidate and reload when school context changes globally
    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() {
          _selectedAyId = null;
          _selectedClassId = null;
          _selectedSectionId = null;
          _selectedStatus = null;
          _searchController.clear();
          _selectedStudentIds.clear();
        });
        ref.read(academicYearsProvider(next).notifier).fetchYears();
        ref.read(classesProvider(next).notifier).fetchClasses();
        ref.read(sectionsProvider(next).notifier).fetchSections();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Directory')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to view students.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final listState = ref.watch(studentListProvider);
    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));

    // Filter dependent lists
    final activeYears = ayState.years;
    final activeClasses = classState.classes.where((c) {
      if (_selectedAyId != null) return c.academicYearId == _selectedAyId;
      return true;
    }).toList();
    final activeSections = sectionState.sections.where((s) {
      if (_selectedClassId != null) return s.classId == _selectedClassId;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'admit_student_main_fab',
            onPressed: () async {
              await context.push('${AppRoutes.students}/new?school_id=$schoolId');
              if (!mounted) return;
              _refreshData();
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Admit Student'),
          ),
          const SizedBox(width: 8),
          MenuAnchor(
            alignmentOffset: const Offset(-180, -240),
            builder: (context, controller, child) {
              return FloatingActionButton(
                key: const Key('admit_options_dropdown_btn'),
                heroTag: 'admit_student_dropdown_fab',
                mini: true,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: const Icon(Icons.arrow_drop_down),
              );
            },
            menuChildren: [
              MenuItemButton(
                key: const Key('admit_student_option_btn'),
                leadingIcon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () async {
                  await context.push('${AppRoutes.students}/new?school_id=$schoolId');
                  if (!mounted) return;
                  _refreshData();
                },
                child: const Text('Admit Student'),
              ),
              MenuItemButton(
                key: const Key('bulk_import_option_btn'),
                leadingIcon: const Icon(Icons.upload_file_outlined),
                onPressed: () {
                  context.push(AppRoutes.bulkImport);
                },
                child: const Text('Bulk Import Students'),
              ),
              MenuItemButton(
                key: const Key('download_template_option_btn'),
                leadingIcon: const Icon(Icons.download_outlined),
                onPressed: _downloadStudentCsvTemplate,
                child: const Text('Download CSV Template'),
              ),
              MenuItemButton(
                key: const Key('bulk_delete_option_btn'),
                leadingIcon: const Icon(Icons.delete_outline),
                onPressed: _selectedStudentIds.isEmpty
                    ? null
                    : () {
                        _showBulkDeleteDialog(context, schoolId);
                      },
                child: const Text('Bulk Delete Students'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter section
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name, roll number, admission number...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        if (_selectedAyId != null ||
                            _selectedClassId != null ||
                            _selectedSectionId != null ||
                            _selectedStatus != null ||
                            _searchController.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear'),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final useWideLayout = constraints.maxWidth > 800;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: useWideLayout ? 4 : (isMobile ? 1 : 2),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: useWideLayout ? 3.5 : 4.5,
                        children: [
                          // Academic Year Filter
                          DropdownButtonFormField<String>(
                            value: _selectedAyId,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: activeYears.map((ay) {
                              return DropdownMenuItem<String>(
                                value: ay.id,
                                child: Text(ay.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAyId = val;
                                _selectedClassId = null;
                                _selectedSectionId = null;
                                _selectedStudentIds.clear();
                              });
                              ref.read(studentListProvider.notifier).updateFilters(
                                    academicYearId: val,
                                    classId: null,
                                    sectionId: null,
                                  );
                            },
                          ),
                          // Class Filter
                          DropdownButtonFormField<String>(
                            value: _selectedClassId,
                            decoration: const InputDecoration(
                              labelText: 'Class',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: activeClasses.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClassId = val;
                                _selectedSectionId = null;
                                _selectedStudentIds.clear();
                              });
                              ref.read(studentListProvider.notifier).updateFilters(
                                    classId: val,
                                    sectionId: null,
                                  );
                            },
                          ),
                          // Section Filter
                          DropdownButtonFormField<String>(
                            value: _selectedSectionId,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: activeSections.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(s.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSectionId = val;
                                _selectedStudentIds.clear();
                              });
                              ref.read(studentListProvider.notifier).updateFilters(sectionId: val);
                            },
                          ),
                          // Status Filter
                          DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                              DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                              DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                              DropdownMenuItem(value: 'WITHDRAWN', child: Text('Withdrawn')),
                              DropdownMenuItem(value: 'ALUMNI', child: Text('Alumni')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedStatus = val;
                                _selectedStudentIds.clear();
                              });
                              ref.read(studentListProvider.notifier).updateFilters(status: val);
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Main Listing Content
          Expanded(
            child: (listState.isLoading && listState.students.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : listState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error loading students: ${listState.error}',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : listState.students.isEmpty
                        ? const Center(
                            child: Text(
                              'No students found matching selected filters.',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                if (_selectedStudentIds.isNotEmpty)
                                  _buildBulkActionsToolbar(listState.students, schoolId, theme),
                                Expanded(
                                  child: isMobile
                                      ? _buildMobileList(listState.students, schoolId)
                                      : _buildDesktopTable(listState.students, schoolId, theme),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: listState.isLoading || listState.students.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: SafeArea(
                child: _buildPaginationBar(listState, theme),
              ),
            ),
    );
  }

  Widget _buildMobileList(List<StudentDto> students, String schoolId) {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.students}/${student.id}?school_id=$schoolId');
              if (!mounted) return;
              _refreshData();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${student.firstName} ${student.lastName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      _buildStatusChip(student.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Admission No: ${student.admissionNumber}'),
                  Text('Class/Section: ${student.className ?? "-"} / ${student.sectionName ?? "-"}'),
                  if (student.mobile != null) Text('Mobile: ${student.mobile}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<StudentDto> students, String schoolId, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableHeight = constraints.maxHeight;
            return Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1010,
                  height: tableHeight,
                  child: Column(
                    children: [
                      _buildTableHeader(theme, students),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Scrollbar(
                            controller: _verticalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              scrollDirection: Axis.vertical,
                              child: _buildTableBody(students, schoolId, theme),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableBody(List<StudentDto> students, String schoolId, ThemeData theme) {
    return Column(
      children: students.map((student) => _buildTableRow(student, schoolId, theme)).toList(),
    );
  }

  Widget _buildTableRow(StudentDto student, String schoolId, ThemeData theme) {
    final isSelected = _selectedStudentIds.contains(student.id);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.08) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) {
                _toggleSelectStudent(student.id, val ?? false);
              },
            ),
          ),
          _buildDataCell(
            InkWell(
              onTap: () async {
                await context.push('${AppRoutes.students}/${student.id}?school_id=$schoolId');
                if (!mounted) return;
                _refreshData();
              },
              child: Text(
                '${student.firstName} ${student.lastName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            180,
          ),
          _buildDataCell(Text(student.admissionNumber), 120),
          _buildDataCell(Text(student.rollNumber), 100),
          _buildDataCell(Text(student.className ?? '-'), 120),
          _buildDataCell(Text(student.sectionName ?? '-'), 120),
          _buildDataCell(Text(student.gender), 100),
          _buildDataCell(_buildStatusChip(student.status), 120),
          _buildDataCell(
            IconButton(
              key: Key('edit_student_${student.id}'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () async {
                await context.push('${AppRoutes.students}/${student.id}?school_id=$schoolId');
                if (!mounted) return;
                _refreshData();
              },
            ),
            100,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(ThemeData theme, List<StudentDto> visibleStudents) {
    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Checkbox(
              value: _isAllSelected(visibleStudents),
              tristate: _isAnySelected(visibleStudents) && !_isAllSelected(visibleStudents),
              onChanged: (val) {
                _toggleSelectAll(visibleStudents, val ?? false);
              },
            ),
          ),
          _buildHeaderCell('Student Name', 180, theme),
          _buildHeaderCell('Admission No', 120, theme),
          _buildHeaderCell('Roll No', 100, theme),
          _buildHeaderCell('Class', 120, theme),
          _buildHeaderCell('Section', 120, theme),
          _buildHeaderCell('Gender', 100, theme),
          _buildHeaderCell('Status', 120, theme),
          _buildHeaderCell('Action', 100, theme),
        ],
      ),
    );
  }

  bool _isAllSelected(List<StudentDto> students) {
    if (students.isEmpty) return false;
    return students.every((s) => _selectedStudentIds.contains(s.id));
  }

  bool _isAnySelected(List<StudentDto> students) {
    return students.any((s) => _selectedStudentIds.contains(s.id));
  }

  void _toggleSelectAll(List<StudentDto> students, bool select) {
    setState(() {
      if (select) {
        _selectedStudentIds.addAll(students.map((s) => s.id));
      } else {
        _selectedStudentIds.removeAll(students.map((s) => s.id));
      }
    });
  }

  void _toggleSelectStudent(String studentId, bool select) {
    setState(() {
      if (select) {
        _selectedStudentIds.add(studentId);
      } else {
        _selectedStudentIds.remove(studentId);
      }
    });
  }

  Widget _buildHeaderCell(String text, double width, ThemeData theme) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  void _downloadStudentCsvTemplate() {
    const headers = [
      'academic_year_id',
      'first_name',
      'last_name',
      'gender',
      'date_of_birth',
      'admission_number',
      'admission_date',
      'roll_number',
      'email',
      'phone',
      'father_name',
      'mother_name',
      'address',
      'class_name',
      'class_code',
      'section_name',
      'section_code',
      'status',
    ];
    final csvContent = headers.join(',');
    downloadCsvFile('student_import_template.csv', csvContent);
  }

  void _exportSelectedToCsv(List<StudentDto> students) {
    final selected = students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) return;

    final List<String> csvLines = [
      'id,first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,class_name,section_name,status'
    ];

    for (final s in selected) {
      final fields = [
        s.id,
        s.firstName,
        s.lastName,
        s.gender,
        s.dateOfBirth,
        s.admissionNumber,
        s.rollNumber,
        s.admissionDate,
        s.className ?? '',
        s.sectionName ?? '',
        s.status,
      ].map((f) => '"${f.replaceAll('"', '""')}"').join(',');
      csvLines.add(fields);
    }

    final csvContent = csvLines.join('\n');
    downloadCsvFile('students_export.csv', csvContent);
  }

  Widget _buildBulkActionsToolbar(List<StudentDto> students, String schoolId, ThemeData theme) {
    final listState = ref.watch(studentListProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;
          final titleText = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedStudentIds.length} selected (current page)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (listState.isDeleting) ...[
                const SizedBox(width: 12),
                Text(
                  'Deleting ${listState.deleteProgressCount}/${listState.deleteTotalCount}...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          );
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('bulk_change_status_btn'),
                icon: const Icon(Icons.change_circle_outlined),
                label: const Text('Change Status'),
                onPressed: listState.isDeleting ? null : () => _showBulkStatusChangeDialog(context, schoolId),
              ),
              TextButton.icon(
                key: const Key('bulk_move_section_btn'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Move Section'),
                onPressed: listState.isDeleting ? null : () => _showBulkMoveSectionDialog(context, schoolId),
              ),
              TextButton.icon(
                key: const Key('bulk_export_btn'),
                icon: const Icon(Icons.download),
                label: const Text('Export'),
                onPressed: listState.isDeleting ? null : () => _exportSelectedToCsv(students),
              ),
              TextButton.icon(
                key: const Key('bulk_delete_btn'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Bulk Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: (listState.isDeleting || _selectedStudentIds.isEmpty)
                    ? null
                    : () => _showBulkDeleteDialog(context, schoolId),
              ),
              IconButton(
                key: const Key('bulk_clear_btn'),
                icon: const Icon(Icons.clear),
                tooltip: 'Clear Selection',
                onPressed: listState.isDeleting ? null : () {
                  setState(() {
                    _selectedStudentIds.clear();
                  });
                },
              ),
            ],
          );

          if (isWide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleText,
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: buttons,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: titleText),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(child: buttons),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  void _showBulkStatusChangeDialog(BuildContext context, String schoolId) async {
    String? newStatus;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change Student Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update status for ${_selectedStudentIds.length} selected students to:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('bulk_status_dropdown'),
                  value: newStatus,
                  decoration: const InputDecoration(
                    labelText: 'New Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                    DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                    DropdownMenuItem(value: 'WITHDRAWN', child: Text('Withdrawn')),
                    DropdownMenuItem(value: 'ALUMNI', child: Text('Alumni')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      newStatus = val;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('confirm_status_change_dialog_btn'),
                onPressed: newStatus == null ? null : () => Navigator.of(context).pop(true),
                child: const Text('Apply Changes'),
              ),
            ],
          );
        });
      },
    );

    if (!context.mounted) return;
    if (confirm != true || newStatus == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final results = await ref.read(studentListProvider.notifier).bulkUpdateStatus(
      _selectedStudentIds.toList(),
      newStatus!,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    setState(() {
      _selectedStudentIds.clear();
    });

    _showBulkActionResults(results['successCount'] as int, results['failures'] as List<String>);
  }

  void _showBulkMoveSectionDialog(BuildContext context, String schoolId) async {
    // Show a loading indicator dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Fetch counts and sections capacity info
    final Map<String, int> currentCounts = await ref.read(studentListProvider.notifier).getSectionStudentCounts(schoolId);
    
    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss loading indicator
    }

    String? targetAyId;
    String? targetClassId;
    String? targetSectionId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Consumer(builder: (context, ref, child) {
          final ayState = ref.watch(academicYearsProvider(schoolId));
          final classState = ref.watch(classesProvider(schoolId));
          final sectionState = ref.watch(sectionsProvider(schoolId));

          final years = ayState.years;
          final classes = classState.classes.where((c) {
            if (targetAyId != null) return c.academicYearId == targetAyId;
            return true;
          }).toList();
          final sections = sectionState.sections.where((s) {
            if (targetClassId != null) return s.classId == targetClassId;
            return true;
          }).toList();

          return StatefulBuilder(builder: (context, setDialogState) {
            SectionDto? selectedSec;
            try {
              if (targetSectionId != null) {
                selectedSec = sections.firstWhere((s) => s.id == targetSectionId);
              }
            } catch (_) {}
            
            final occupancy = selectedSec == null ? 0 : (currentCounts[selectedSec.id] ?? 0);
            final capacity = selectedSec == null ? 0 : selectedSec.capacity;
            final isFull = selectedSec != null && occupancy >= capacity;

            return AlertDialog(
              title: const Text('Move Students to Section'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign ${_selectedStudentIds.length} selected students to:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('bulk_move_ay_dropdown'),
                    value: targetAyId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      border: OutlineInputBorder(),
                    ),
                    items: years.map((ay) {
                      return DropdownMenuItem<String>(
                        value: ay.id,
                        child: Text(ay.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        targetAyId = val;
                        targetClassId = null;
                        targetSectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('bulk_move_class_dropdown'),
                    value: targetClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: classes.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        targetClassId = val;
                        targetSectionId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('bulk_move_section_dropdown'),
                    value: targetSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                    ),
                    items: sections.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${s.name} (${currentCounts[s.id] ?? 0}/${s.capacity})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        targetSectionId = val;
                      });
                    },
                  ),
                  if (selectedSec != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Target capacity: $occupancy / $capacity students',
                      style: TextStyle(
                        color: isFull ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFull) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Warning: Target section capacity is full!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('confirm_move_section_dialog_btn'),
                  onPressed: (targetAyId == null || targetClassId == null || targetSectionId == null || isFull)
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: const Text('Move Students'),
                ),
              ],
            );
          });
        });
      },
    );

    if (!context.mounted) return;
    if (confirm != true || targetAyId == null || targetClassId == null || targetSectionId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final results = await ref.read(studentListProvider.notifier).bulkMoveSection(
      studentIds: _selectedStudentIds.toList(),
      academicYearId: targetAyId!,
      classId: targetClassId!,
      sectionId: targetSectionId!,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    setState(() {
      _selectedStudentIds.clear();
    });

    _showBulkActionResults(results['successCount'] as int, results['failures'] as List<String>);
  }

  void _showBulkActionResults(int successCount, List<String> failures) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Action Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Success: $successCount student(s) updated successfully.'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Failures (${failures.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: failures.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text('• $f', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      )).toList(),
                    ),
                  ),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              key: const Key('bulk_action_results_close_btn'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
  void _performBulkDelete(List<String> ids, String schoolId) async {
    final results = await ref.read(studentListProvider.notifier).bulkDeleteStudents(ids);

    if (!mounted) return;

    final successfulIds = List<String>.from(results['successfulIds'] as List? ?? []);
    final failedIds = List<String>.from(results['failedIds'] as List? ?? []);

    setState(() {
      _selectedStudentIds.removeAll(successfulIds);
    });

    _showBulkDeleteResults(
      results['successCount'] as int? ?? 0,
      List<String>.from(results['failures'] as List? ?? []),
      failedIds,
      schoolId,
    );
  }

  void _showBulkDeleteDialog(BuildContext context, String schoolId) async {
    final count = _selectedStudentIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete $count Students?'),
          content: const Text(
            'This action will permanently remove the selected student records. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_delete_dialog_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Students'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    if (confirm != true) return;

    _performBulkDelete(_selectedStudentIds.toList(), schoolId);
  }

  void _showBulkDeleteResults(int successCount, List<String> failures, List<String> failedIds, String schoolId) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Delete Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Successfully deleted: $successCount student(s).'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Failed to delete (${failures.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: failures.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text('• $f', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      )).toList(),
                    ),
                  ),
                ),
              ]
            ],
          ),
          actions: [
            if (failedIds.isNotEmpty)
              TextButton(
                key: const Key('bulk_delete_results_retry_btn'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _performBulkDelete(failedIds, schoolId);
                },
                child: const Text('Retry Failed'),
              ),
            TextButton(
              key: const Key('bulk_delete_results_close_btn'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
  Widget _buildPaginationBar(StudentListState state, ThemeData theme) {
    final currentPage = (state.skip / state.limit).floor() + 1;
    final showingStart = state.students.isEmpty ? 0 : state.skip + 1;
    final showingEnd = state.skip + state.students.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        final showingText = Text(
          'Showing $showingStart-$showingEnd of ${state.total} students',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        );

        final pageText = Text(
          'Page $currentPage',
          style: theme.textTheme.bodyMedium,
        );

        final prevButton = OutlinedButton(
          key: const Key('pagination_prev_btn'),
          onPressed: state.skip > 0
              ? () {
                  setState(() => _selectedStudentIds.clear());
                  ref.read(studentListProvider.notifier).prevPage();
                }
              : null,
          child: const Text('Previous'),
        );

        final nextButton = OutlinedButton(
          key: const Key('pagination_next_btn'),
          onPressed: state.hasMore
              ? () {
                  setState(() => _selectedStudentIds.clear());
                  ref.read(studentListProvider.notifier).nextPage();
                }
              : null,
          child: const Text('Next'),
        );

        final rowsPerPageDropdown = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rows per page: ', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 4),
            DropdownButton<int>(
              key: const Key('pagination_limit_dropdown'),
              value: state.limit,
              items: [10, 25, 50, 100].map((limit) {
                return DropdownMenuItem<int>(
                  value: limit,
                  child: Text('$limit'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStudentIds.clear());
                  ref.read(studentListProvider.notifier).updateLimit(val);
                }
              },
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: showingText),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  prevButton,
                  const SizedBox(width: 8),
                  pageText,
                  const SizedBox(width: 8),
                  nextButton,
                  const SizedBox(width: 32),
                  rowsPerPageDropdown,
                ],
              ),
            ],
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: showingText),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    prevButton,
                    const SizedBox(width: 12),
                    pageText,
                    const SizedBox(width: 12),
                    nextButton,
                    const SizedBox(width: 24),
                    rowsPerPageDropdown,
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.grey;
        break;
      case 'SUSPENDED':
        color = Colors.orange;
        break;
      case 'WITHDRAWN':
        color = Colors.red;
        break;
      case 'ALUMNI':
        color = Colors.blue;
        break;
      default:
        color = Colors.black;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
