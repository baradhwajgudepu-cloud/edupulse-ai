import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';

class SectionDetailsScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String? sectionId;

  const SectionDetailsScreen({
    super.key,
    required this.schoolId,
    this.sectionId,
  });

  @override
  ConsumerState<SectionDetailsScreen> createState() => _SectionDetailsScreenState();
}

class _SectionDetailsScreenState extends ConsumerState<SectionDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _capacityController = TextEditingController(text: '40');
  final _roomNumberController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();

  String _selectedStatus = 'ACTIVE';
  String? _selectedClassId;
  String? _selectedAyId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.sectionId != null && widget.sectionId != 'new';
    Future.microtask(() {
      ref.read(classesProvider(widget.schoolId).notifier).fetchClasses();
      if (_isEditMode) {
        _loadSectionDetails();
      }
    });
  }

  Future<void> _loadSectionDetails() async {
    final s = await ref.read(sectionDetailProvider((schoolId: widget.schoolId, id: widget.sectionId!)).future);
    setState(() {
      _nameController.text = s.name;
      _codeController.text = s.code;
      _capacityController.text = s.capacity.toString();
      _roomNumberController.text = s.roomNumber ?? '';
      _sortOrderController.text = s.sortOrder.toString();
      _descriptionController.text = s.description ?? '';
      _selectedStatus = s.status;
      _selectedClassId = s.classId;
      _selectedAyId = s.academicYearId;
      _entityVersion = s.version;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _capacityController.dispose();
    _roomNumberController.dispose();
    _sortOrderController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null || _selectedAyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active class context'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = {
      'school_id': widget.schoolId,
      'academic_year_id': _selectedAyId,
      'class_id': _selectedClassId,
      'name': _nameController.text,
      'code': _codeController.text,
      'capacity': int.tryParse(_capacityController.text) ?? 40,
      'room_number': _roomNumberController.text.isEmpty ? null : _roomNumberController.text,
      'sort_order': int.tryParse(_sortOrderController.text) ?? 1,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'status': _selectedStatus,
    };

    final path = _isEditMode
        ? '/sections/${widget.sectionId}?school_id=${widget.schoolId}'
        : '/sections';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Section updated' : 'Section registered successfully',
        );

    if (success) {
      ref.invalidate(sectionsProvider(widget.schoolId));
      if (_isEditMode) {
        ref.invalidate(sectionDetailProvider((schoolId: widget.schoolId, id: widget.sectionId!)));
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
        _loadSectionDetails(); // Force reload to fetch latest database details
      }
    }
  }

  Future<void> _deleteSection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: const Text('This will soft-delete this section. Mapped student associations will be detached.'),
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
          path: '/sections/${widget.sectionId}?school_id=${widget.schoolId}',
          successMsg: 'Section soft-deleted successfully',
        );

    if (success) {
      ref.invalidate(sectionsProvider(widget.schoolId));
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
    final classState = ref.watch(classesProvider(widget.schoolId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Section Attributes' : 'New Section Setup'),
        actions: [
          if (_isEditMode)
            IconButton(
              tooltip: 'Delete section',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: actionState.isLoading ? null : _deleteSection,
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
                      Text('Class Association', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedClassId,
                        disabledHint: _selectedClassId != null
                            ? Text(classState.classes.firstWhere((c) => c.id == _selectedClassId, orElse: () => classState.classes.first).name)
                            : null,
                        decoration: const InputDecoration(labelText: 'Parent Class*', border: OutlineInputBorder()),
                        items: classState.classes.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: _isEditMode
                            ? null
                            : (v) {
                                final selectedClass = classState.classes.firstWhere((c) => c.id == v);
                                setState(() {
                                  _selectedClassId = v;
                                  _selectedAyId = selectedClass.academicYearId; // Inherit academic year from class context
                                });
                              },
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
                      Text('Section Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Section Name*', hintText: 'e.g. Section A', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Section Code*', hintText: 'e.g. SEC_A', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _capacityController,
                              decoration: const InputDecoration(labelText: 'Max Capacity*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _roomNumberController,
                              decoration: const InputDecoration(labelText: 'Classroom / Room Number', hintText: 'e.g. 101', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sortOrderController,
                        decoration: const InputDecoration(labelText: 'Display Sort Order*', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
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
                        items: ['ACTIVE', 'INACTIVE']
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
                        : const Text('Save Section'),
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
