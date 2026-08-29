import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../data/models/school_setup_models.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String? classId;

  const ClassDetailsScreen({
    super.key,
    required this.schoolId,
    this.classId,
  });

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _levelController = TextEditingController(text: '1');
  final _streamController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController(text: '40');
  final _promotionOrderController = TextEditingController();

  String _selectedCategory = 'PRIMARY';
  String _selectedStatus = 'ACTIVE';
  String? _selectedAyId;
  String? _selectedNextClassId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.classId != null && widget.classId != 'new';
    Future.microtask(() {
      ref.read(academicYearsProvider(widget.schoolId).notifier).fetchYears();
      ref.read(classesProvider(widget.schoolId).notifier).fetchClasses();
      if (_isEditMode) {
        _loadClassDetails();
      }
    });
  }

  Future<void> _loadClassDetails() async {
    final c = await ref.read(classDetailProvider((schoolId: widget.schoolId, id: widget.classId!)).future);
    setState(() {
      _nameController.text = c.name;
      _displayNameController.text = c.displayName ?? '';
      _codeController.text = c.code;
      _levelController.text = c.level.toString();
      _streamController.text = c.stream ?? '';
      _descriptionController.text = c.description ?? '';
      _capacityController.text = c.capacity.toString();
      _promotionOrderController.text = c.promotionOrder?.toString() ?? '';
      _selectedCategory = c.category;
      _selectedStatus = c.status;
      _selectedAyId = c.academicYearId;
      _selectedNextClassId = c.nextClassId;
      _entityVersion = c.version;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    _levelController.dispose();
    _streamController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _promotionOrderController.dispose();
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

    final data = {
      'school_id': widget.schoolId,
      'academic_year_id': _selectedAyId,
      'name': _nameController.text,
      'display_name': _displayNameController.text.isEmpty ? null : _displayNameController.text,
      'code': _codeController.text,
      'level': int.tryParse(_levelController.text) ?? 1,
      'category': _selectedCategory,
      'stream': _streamController.text.isEmpty ? null : _streamController.text,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'capacity': int.tryParse(_capacityController.text) ?? 40,
      'promotion_order': int.tryParse(_promotionOrderController.text),
      'next_class_id': _selectedNextClassId,
      'status': _selectedStatus,
    };

    final path = _isEditMode
        ? '/classes/${widget.classId}?school_id=${widget.schoolId}'
        : '/classes';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Class updated' : 'Class registered successfully',
        );

    if (success) {
      ref.invalidate(classesProvider(widget.schoolId));
      if (_isEditMode) {
        ref.invalidate(classDetailProvider((schoolId: widget.schoolId, id: widget.classId!)));
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
        _loadClassDetails(); // Force reload to fetch latest database details
      }
    }
  }

  Future<void> _archiveClass() async {
    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'POST',
          path: '/classes/${widget.classId}/archive?school_id=${widget.schoolId}',
          successMsg: 'Class archived successfully',
        );

    if (success) {
      ref.invalidate(classesProvider(widget.schoolId));
      _loadClassDetails();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Archive failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _promoteClass() async {
    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'POST',
          path: '/classes/${widget.classId}/promote?school_id=${widget.schoolId}',
          successMsg: 'Class promotion sequence initialized',
        );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class promotion initialized successfully')),
      );
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Promotion trigger failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class?'),
        content: const Text(
            'This will soft-delete the class. This action will fail if active sections are currently assigned.'),
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
          path: '/classes/${widget.classId}?school_id=${widget.schoolId}',
          successMsg: 'Class soft-deleted successfully',
        );

    if (success) {
      ref.invalidate(classesProvider(widget.schoolId));
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
    final classState = ref.watch(classesProvider(widget.schoolId));
    final theme = Theme.of(context);

    // Filter available promotion next classes (exclude itself)
    final otherClasses = classState.classes.where((c) => c.id != widget.classId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Class Attributes' : 'Create Class'),
        actions: [
          if (_isEditMode) ...[
            IconButton(
              tooltip: 'Promote routine',
              icon: const Icon(Icons.upgrade, color: Colors.blue),
              onPressed: actionState.isLoading ? null : _promoteClass,
            ),
            IconButton(
              tooltip: 'Archive class',
              icon: const Icon(Icons.archive_outlined, color: Colors.orange),
              onPressed: actionState.isLoading ? null : _archiveClass,
            ),
            IconButton(
              tooltip: 'Delete class',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: actionState.isLoading ? null : _deleteClass,
            ),
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
                      Text('Academic Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedAyId,
                        disabledHint: _selectedAyId != null
                            ? Text(ayState.years.firstWhere((y) => y.id == _selectedAyId, orElse: () => ayState.years.first).name)
                            : null,
                        decoration: const InputDecoration(labelText: 'Academic Year Context*', border: OutlineInputBorder()),
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
                      Text('General Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Class Name*', hintText: 'e.g. Grade 8', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(labelText: 'Display Label', hintText: 'e.g. Eighth Grade', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(labelText: 'Class Code*', hintText: 'e.g. GRADE_8', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _levelController,
                              decoration: const InputDecoration(labelText: 'Grade Level (Level)*', hintText: 'e.g. 8', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                              decoration: const InputDecoration(labelText: 'Grade Category*', border: OutlineInputBorder()),
                              items: ['PRE_PRIMARY', 'PRIMARY', 'MIDDLE', 'HIGH', 'HIGHER_SECONDARY', 'OTHER']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _streamController,
                              decoration: const InputDecoration(labelText: 'Specialization Stream', hintText: 'e.g. General / Science / Commerce', border: OutlineInputBorder()),
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
                      Text('System & Promotion Rules', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                              controller: _capacityController,
                              decoration: const InputDecoration(labelText: 'Max Class Capacity*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _promotionOrderController,
                              decoration: const InputDecoration(labelText: 'Promotion Order Index', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        value: _selectedNextClassId,
                        decoration: const InputDecoration(labelText: 'Next Promotion Class Path', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Terminal Class)')),
                          ...otherClasses.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() => _selectedNextClassId = v),
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
                        : const Text('Save Class'),
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
