import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';

class SubjectDetailsScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String? subjectId;

  const SubjectDetailsScreen({
    super.key,
    required this.schoolId,
    this.subjectId,
  });

  @override
  ConsumerState<SubjectDetailsScreen> createState() => _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends ConsumerState<SubjectDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _creditHoursController = TextEditingController();
  final _weeklyPeriodsController = TextEditingController();
  final _theoryMarksController = TextEditingController(text: '80');
  final _practicalMarksController = TextEditingController(text: '0');
  final _passMarksController = TextEditingController(text: '35');
  final _displayColorController = TextEditingController();
  final _displayOrderController = TextEditingController();

  String _selectedCategory = 'CORE';
  String _selectedType = 'THEORY';
  String _selectedStatus = 'ACTIVE';
  String? _selectedAyId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.subjectId != null && widget.subjectId != 'new';
    Future.microtask(() {
      ref.read(academicYearsProvider(widget.schoolId).notifier).fetchYears();
      if (_isEditMode) {
        _loadSubjectDetails();
      }
    });
  }

  Future<void> _loadSubjectDetails() async {
    final s = await ref.read(subjectDetailProvider((schoolId: widget.schoolId, id: widget.subjectId!)).future);
    setState(() {
      _nameController.text = s.subjectName;
      _codeController.text = s.subjectCode;
      _shortNameController.text = s.shortName ?? '';
      _descriptionController.text = s.description ?? '';
      _creditHoursController.text = s.creditHours?.toString() ?? '';
      _weeklyPeriodsController.text = s.weeklyPeriods?.toString() ?? '';
      _theoryMarksController.text = s.theoryMarks.toString();
      _practicalMarksController.text = s.practicalMarks.toString();
      _passMarksController.text = s.passMarks.toString();
      _displayColorController.text = s.displayColor ?? '';
      _displayOrderController.text = s.displayOrder?.toString() ?? '';
      _selectedCategory = s.category;
      _selectedType = s.subjectType;
      _selectedStatus = s.status;
      _selectedAyId = s.academicYearId;
      _entityVersion = s.version;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _creditHoursController.dispose();
    _weeklyPeriodsController.dispose();
    _theoryMarksController.dispose();
    _practicalMarksController.dispose();
    _passMarksController.dispose();
    _displayColorController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an academic year context'), backgroundColor: Colors.red),
      );
      return;
    }

    final theory = int.tryParse(_theoryMarksController.text) ?? 0;
    final practical = int.tryParse(_practicalMarksController.text) ?? 0;
    final pass = int.tryParse(_passMarksController.text) ?? 0;

    if (pass > (theory + practical)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pass marks cannot exceed the sum of theory and practical marks'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = {
      'school_id': widget.schoolId,
      'academic_year_id': _selectedAyId,
      'subject_code': _codeController.text,
      'subject_name': _nameController.text,
      'short_name': _shortNameController.text.isEmpty ? null : _shortNameController.text,
      'category': _selectedCategory,
      'subject_type': _selectedType,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'credit_hours': _creditHoursController.text.isEmpty ? null : int.tryParse(_creditHoursController.text),
      'weekly_periods': _weeklyPeriodsController.text.isEmpty ? null : int.tryParse(_weeklyPeriodsController.text),
      'theory_marks': theory,
      'practical_marks': practical,
      'pass_marks': pass,
      'display_color': _displayColorController.text.isEmpty ? null : _displayColorController.text,
      'display_order': _displayOrderController.text.isEmpty ? null : int.tryParse(_displayOrderController.text),
      'status': _selectedStatus,
    };

    final path = _isEditMode
        ? '/subjects/${widget.subjectId}?school_id=${widget.schoolId}'
        : '/subjects';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Subject details updated' : 'Subject registered successfully',
        );

    if (success) {
      ref.invalidate(subjectsProvider(widget.schoolId));
      if (_isEditMode) {
        ref.invalidate(subjectDetailProvider((schoolId: widget.schoolId, id: widget.subjectId!)));
      }
      context.pop();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
      if (actionState.isConflict) {
        _loadSubjectDetails(); // Force reload to fetch latest database details
      }
    }
  }

  Future<void> _deleteSubject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: const Text('This will soft-delete the subject, moving its status to ARCHIVED.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'DELETE',
          path: '/subjects/${widget.subjectId}?school_id=${widget.schoolId}',
          successMsg: 'Subject soft-deleted successfully',
        );

    if (success) {
      ref.invalidate(subjectsProvider(widget.schoolId));
      context.pop();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Delete failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(setupActionProvider);
    final ayState = ref.watch(academicYearsProvider(widget.schoolId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Subject Profile' : 'Register Subject'),
        actions: [
          if (_isEditMode)
            IconButton(
              tooltip: 'Delete subject',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: actionState.isLoading ? null : _deleteSubject,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode) ...[
                Text('Optimistic Lock Version: $_entityVersion', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
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
                      Text('Academic Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedAyId,
                        disabledHint: _selectedAyId != null
                            ? Text(ayState.years.firstWhere((y) => y.id == _selectedAyId, orElse: () => ayState.years.first).name)
                            : null,
                        decoration: const InputDecoration(labelText: 'Academic Year Scope*', border: OutlineInputBorder()),
                        items: ayState.years.map((y) {
                          return DropdownMenuItem(value: y.id, child: Text(y.name));
                        }).toList(),
                        onChanged: _isEditMode ? null : (v) => setState(() => _selectedAyId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      Text('Subject Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Subject Name*', hintText: 'e.g. Mathematics', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(labelText: 'Subject Code*', hintText: 'e.g. MATH101', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _shortNameController,
                              decoration: const InputDecoration(labelText: 'Short Code / Name', hintText: 'e.g. MATH', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(labelText: 'Category*', border: OutlineInputBorder()),
                              items: ['CORE', 'ELECTIVE', 'LANGUAGE', 'OPTIONAL', 'LAB', 'SPORTS', 'ARTS', 'CO_CURRICULAR']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(labelText: 'Type*', border: OutlineInputBorder()),
                              items: ['THEORY', 'PRACTICAL', 'THEORY_PRACTICAL']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedType = v!;
                                  if (v == 'THEORY') {
                                    _practicalMarksController.text = '0';
                                  } else if (v == 'PRACTICAL') {
                                    _theoryMarksController.text = '0';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      Text('Assessment & Credits Rules', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _creditHoursController,
                              decoration: const InputDecoration(labelText: 'Credit Hours', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weeklyPeriodsController,
                              decoration: const InputDecoration(labelText: 'Weekly Periods Count', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _theoryMarksController,
                              decoration: const InputDecoration(labelText: 'Theory Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              enabled: _selectedType != 'PRACTICAL',
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _practicalMarksController,
                              decoration: const InputDecoration(labelText: 'Practical Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              enabled: _selectedType != 'THEORY',
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _passMarksController,
                              decoration: const InputDecoration(labelText: 'Pass Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      Text('System & Styling Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _displayColorController,
                              decoration: const InputDecoration(labelText: 'Display Theme Color (Hex)', hintText: 'e.g. #FF5722', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _displayOrderController,
                              decoration: const InputDecoration(labelText: 'Display Sequence Order', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status*', border: OutlineInputBorder()),
                        items: ['ACTIVE', 'INACTIVE', 'ARCHIVED']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: actionState.isLoading ? null : _saveForm,
                    child: actionState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Subject'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
