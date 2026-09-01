import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/school_setup_providers.dart';

class AcademicYearDetailsScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String? ayId;

  const AcademicYearDetailsScreen({
    super.key,
    required this.schoolId,
    this.ayId,
  });

  @override
  ConsumerState<AcademicYearDetailsScreen> createState() => _AcademicYearDetailsScreenState();
}

class _AcademicYearDetailsScreenState extends ConsumerState<AcademicYearDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController(); // Stores yyyy-MM-dd
  final _endDateController = TextEditingController();   // Stores yyyy-MM-dd

  String _selectedStatus = 'UPCOMING';
  bool _isCurrent = false;

  // Custom Settings
  String _selectedGrading = 'GPA_4';
  final _passingPercentageController = TextEditingController(text: '40');
  bool _autoPromote = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.ayId != null && widget.ayId != 'new';
    if (_isEditMode) {
      Future.microtask(() => _loadAyDetails());
    }
  }

  Future<void> _loadAyDetails() async {
    final ay = await ref.read(academicYearDetailProvider((schoolId: widget.schoolId, id: widget.ayId!)).future);
    setState(() {
      _nameController.text = ay.name;
      _codeController.text = ay.code;
      _descriptionController.text = ay.description ?? '';
      _startDateController.text = ay.startDate;
      _endDateController.text = ay.endDate;
      _selectedStatus = ay.status;
      _isCurrent = ay.isCurrent;
      _entityVersion = ay.version;

      if (ay.settings != null) {
        _selectedGrading = ay.settings!['grading_scale']?.toString() ?? 'GPA_4';
        _passingPercentageController.text = ay.settings!['passing_percentage']?.toString() ?? '40';
        _autoPromote = ay.settings!['auto_promote_students'] as bool? ?? false;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _passingPercentageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      'code': _codeController.text,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'status': _selectedStatus,
      'is_current': _isCurrent,
      'settings': {
        'grading_scale': _selectedGrading,
        'passing_percentage': int.tryParse(_passingPercentageController.text) ?? 40,
        'auto_promote_students': _autoPromote,
      }
    };

    final path = _isEditMode
        ? '/schools/${widget.schoolId}/academic-years/${widget.ayId}'
        : '/schools/${widget.schoolId}/academic-years';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Academic year calendar details updated' : 'Academic year registered successfully',
        );

    if (success) {
      ref.invalidate(academicYearsProvider(widget.schoolId));
      if (_isEditMode) {
        ref.invalidate(academicYearDetailProvider((schoolId: widget.schoolId, id: widget.ayId!)));
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
        _loadAyDetails(); // Force reload to fetch latest database details
      }
    }
  }

  Future<void> _changeStatus(String action) async {
    final path = '/schools/${widget.schoolId}/academic-years/${widget.ayId}/$action';
    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'POST',
          path: path,
          successMsg: 'Academic year status updated successfully',
        );

    if (success) {
      ref.invalidate(academicYearsProvider(widget.schoolId));
      ref.invalidate(academicYearDetailProvider((schoolId: widget.schoolId, id: widget.ayId!)));
      _loadAyDetails();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Action failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAy() async {
    if (_isCurrent) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Action Blocked'),
          content: const Text(
              'Cannot delete the current academic year. Please transition the current year parameter first.'),
          actions: [
            TextButton(onPressed: () => context.pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Academic Year?'),
        content: const Text('This will soft-delete this academic year calendar and classes mapped within it.'),
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
          path: '/schools/${widget.schoolId}/academic-years/${widget.ayId}',
          successMsg: 'Academic year deleted successfully',
        );

    if (success) {
      ref.invalidate(academicYearsProvider(widget.schoolId));
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Academic Year' : 'Add Academic Year'),
        actions: [
          if (_isEditMode) ...[
            if (_selectedStatus != 'ACTIVE' && _selectedStatus != 'ARCHIVED')
              IconButton(
                tooltip: 'Activate',
                icon: const Icon(Icons.play_circle_outline, color: Colors.green),
                onPressed: actionState.isLoading ? null : () => _changeStatus('activate'),
              ),
            if (_selectedStatus != 'ARCHIVED')
              IconButton(
                tooltip: 'Archive',
                icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                onPressed: actionState.isLoading ? null : () => _changeStatus('archive'),
              ),
            IconButton(
              tooltip: 'Delete calendar',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: actionState.isLoading ? null : _deleteAy,
            )
          ]
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
                      Text('Duration & Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Academic Year Name*', hintText: 'e.g. 2026-2027', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Calendar Code*', hintText: 'e.g. AY2026', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Start Date*',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () => _selectDate(context, _startDateController),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _endDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'End Date*',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () => _selectDate(context, _endDateController),
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
                      Text('Details & Configs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status*', border: OutlineInputBorder()),
                        items: ['UPCOMING', 'ACTIVE', 'COMPLETED', 'ARCHIVED']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Mark as Current Active Year'),
                        subtitle: const Text('Setting this true deactivates the current active year transactional toggle'),
                        value: _isCurrent,
                        onChanged: (v) => setState(() => _isCurrent = v),
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
                      Text('Academic Rules & Grading', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGrading,
                        decoration: const InputDecoration(labelText: 'Grading Scale*', border: OutlineInputBorder()),
                        items: ['GPA_4', 'GPA_10', 'PERCENTAGE', 'MARKS_100']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGrading = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passingPercentageController,
                        decoration: const InputDecoration(labelText: 'Minimum Passing Percentage*', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Auto-Promote Eligible Students'),
                        subtitle: const Text('System automatically schedules promotions based on pass requirements'),
                        value: _autoPromote,
                        onChanged: (v) => setState(() => _autoPromote = v),
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
                        : const Text('Save Year'),
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
