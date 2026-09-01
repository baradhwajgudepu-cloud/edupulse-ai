import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AssignmentFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final TeacherSubjectAssignmentDto? assignment; // Null for Create, non-null for Edit

  const AssignmentFormDialog({
    super.key,
    required this.teacherId,
    this.assignment,
  });

  @override
  ConsumerState<AssignmentFormDialog> createState() => _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends ConsumerState<AssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _priorityController;
  late final TextEditingController _weeklyPeriodsController;
  late final TextEditingController _workloadPercentageController;
  late final TextEditingController _maxStudentsController;
  late final TextEditingController _remarksController;

  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  String? _selectedAssignmentType;
  String? _selectedStatus;
  
  bool _isClassTeacher = false;
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;

  bool get _isEdit => widget.assignment != null;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;

    _priorityController = TextEditingController(text: a?.priority.toString() ?? '1');
    _weeklyPeriodsController = TextEditingController(text: a?.weeklyPeriods.toString() ?? '4');
    _workloadPercentageController = TextEditingController(text: a?.workloadPercentage.toString() ?? '10.0');
    _maxStudentsController = TextEditingController(text: a?.maximumStudents?.toString() ?? '');
    _remarksController = TextEditingController(text: a?.remarks ?? '');

    _selectedAssignmentType = a?.assignmentType ?? 'PRIMARY';
    _selectedStatus = a?.status ?? 'ACTIVE';
    _isClassTeacher = a?.isClassTeacher ?? false;

    if (a != null) {
      _selectedAyId = a.academicYearId;
      _selectedClassId = a.classId;
      _selectedSectionId = a.sectionId;
      _selectedSubjectId = a.subjectId;
      _effectiveFrom = DateTime.tryParse(a.effectiveFrom);
      if (a.effectiveTo != null) {
        _effectiveTo = DateTime.tryParse(a.effectiveTo!);
      }
    } else {
      _effectiveFrom = DateTime.now();
    }

    // Trigger loading of setups
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
      }
    });
  }

  @override
  void dispose() {
    _priorityController.dispose();
    _weeklyPeriodsController.dispose();
    _workloadPercentageController.dispose();
    _maxStudentsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _effectiveFrom : _effectiveTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveFrom = picked;
        } else {
          _effectiveTo = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    if (_selectedAyId == null ||
        _selectedClassId == null ||
        _selectedSectionId == null ||
        _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Academic Year, Class, Section, and Subject.')),
      );
      return;
    }

    if (_effectiveFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Effective From date is required.')),
      );
      return;
    }

    if (_effectiveTo != null && _effectiveTo!.isBefore(_effectiveFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Effective To date cannot be before Effective From date.')),
      );
      return;
    }

    final data = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': _selectedAyId,
      'teacher_id': widget.teacherId,
      'subject_id': _selectedSubjectId,
      'class_id': _selectedClassId,
      'section_id': _selectedSectionId,
      'assignment_type': _selectedAssignmentType,
      'priority': int.tryParse(_priorityController.text) ?? 1,
      'weekly_periods': int.tryParse(_weeklyPeriodsController.text) ?? 4,
      'workload_percentage': double.tryParse(_workloadPercentageController.text) ?? 0.0,
      'effective_from': _formatDate(_effectiveFrom),
      'effective_to': _effectiveTo != null ? _formatDate(_effectiveTo) : null,
      'is_class_teacher': _isClassTeacher,
      'room_id': null, // Optional UUID
      'maximum_students': _maxStudentsController.text.trim().isEmpty ? null : int.tryParse(_maxStudentsController.text),
      'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    };

    if (_isEdit) {
      data['status'] = _selectedStatus;
    }

    final notifier = ref.read(assignmentActionProvider.notifier);
    final success = await notifier.execute(
      method: _isEdit ? 'PUT' : 'POST',
      path: _isEdit
          ? '/teacher-subject-assignments/${widget.assignment!.id}?school_id=$schoolId'
          : '/teacher-subject-assignments',
      data: data,
      teacherId: widget.teacherId,
      successMsg: _isEdit ? 'Assignment updated successfully.' : 'Assignment registered successfully.',
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final actionState = ref.watch(assignmentActionProvider);
    final theme = Theme.of(context);

    if (schoolId == null) {
      return const AlertDialog(
        content: Text('Please select a school context first.'),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));
    final subjectsState = ref.watch(subjectsProvider(schoolId));

    // Filter subjects by academic year
    final filteredSubjects = subjectsState.subjects.where((s) {
      if (_selectedAyId == null) return true;
      return s.academicYearId == _selectedAyId;
    }).toList();

    // Filter sections by class
    final filteredSections = sectionsState.sections.where((s) {
      if (_selectedClassId == null) return true;
      return s.classId == _selectedClassId;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? 'Edit Subject Assignment' : 'New Subject Assignment',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      // Dropdown: Academic Year
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedAyId,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year *',
                          border: OutlineInputBorder(),
                        ),
                        items: ayState.years.map((y) {
                          return DropdownMenuItem(
                            value: y.id,
                            child: Text('${y.name}${y.isCurrent ? " (Current)" : ""}'),
                          );
                        }).toList(),
                        onChanged: _isEdit ? null : (val) {
                          setState(() {
                            _selectedAyId = val;
                            _selectedSubjectId = null;
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dropdown: Class
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class / Grade Level *',
                          border: OutlineInputBorder(),
                        ),
                        items: classesState.classes.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: _isEdit ? null : (val) {
                          setState(() {
                            _selectedClassId = val;
                            _selectedSectionId = null;
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dropdown: Section
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedSectionId,
                        decoration: const InputDecoration(
                          labelText: 'Section *',
                          border: OutlineInputBorder(),
                        ),
                        items: filteredSections.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: _isEdit ? null : (val) => setState(() => _selectedSectionId = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dropdown: Subject
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                          border: OutlineInputBorder(),
                        ),
                        items: filteredSubjects.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.subjectName} (${s.subjectCode})'),
                          );
                        }).toList(),
                        onChanged: _isEdit ? null : (val) => setState(() => _selectedSubjectId = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dropdown: Assignment Type
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedAssignmentType,
                        decoration: const InputDecoration(
                          labelText: 'Assignment Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PRIMARY', child: Text('PRIMARY')),
                          DropdownMenuItem(value: 'SECONDARY', child: Text('SECONDARY')),
                          DropdownMenuItem(value: 'SUBSTITUTE', child: Text('SUBSTITUTE')),
                        ],
                        onChanged: (val) => setState(() => _selectedAssignmentType = val),
                      ),
                      const SizedBox(height: 16),

                      // Priority & Weekly Periods & Workload percentage
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weeklyPeriodsController,
                              decoration: const InputDecoration(
                                labelText: 'Weekly Periods *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final val = int.tryParse(v);
                                if (val == null || val <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _workloadPercentageController,
                              decoration: const InputDecoration(
                                labelText: 'Workload %',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                                  return 'Must be double';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date Range
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: IgnorePointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Effective From *',
                                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                    text: _effectiveFrom == null ? '' : _formatDate(_effectiveFrom),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: IgnorePointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Effective To',
                                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                    text: _effectiveTo == null ? '' : _formatDate(_effectiveTo),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Class Teacher Switch
                      CheckboxListTile(
                        value: _isClassTeacher,
                        title: const Text('Designate as Class Teacher'),
                        subtitle: const Text('Enforces at most one class teacher mapping per section.'),
                        onChanged: (val) => setState(() => _isClassTeacher = val ?? false),
                      ),
                      const SizedBox(height: 16),

                      // Priority & Max Students
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priorityController,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                                  return 'Must be integer';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _maxStudentsController,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Students',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Remarks
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),

                      if (_isEdit) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                            DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                            DropdownMenuItem(value: 'TRANSFERRED', child: Text('TRANSFERRED')),
                            DropdownMenuItem(value: 'ARCHIVED', child: Text('ARCHIVED')),
                          ],
                          onChanged: (val) => setState(() => _selectedStatus = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Backend error printout
              if (actionState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    actionState.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

              // Actions Panel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: actionState.isLoading ? null : _submit,
                    child: actionState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save Changes' : 'Assign Teacher'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
