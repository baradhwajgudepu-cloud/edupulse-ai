import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/examination_models.dart';
import '../providers/examination_providers.dart';

class ExamTypesScreen extends ConsumerStatefulWidget {
  const ExamTypesScreen({super.key});

  @override
  ConsumerState<ExamTypesScreen> createState() => _ExamTypesScreenState();
}

class _ExamTypesScreenState extends ConsumerState<ExamTypesScreen> {
  String _searchQuery = '';
  ExamTypeCategoryEnum? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examTypesProvider);
    final theme = Theme.of(context);

    // Compute KPI metrics
    final totalTypes = state.types.length;
    final scholasticCount = state.types.where((t) => t.category == ExamTypeCategoryEnum.scholastic).length;
    final practicalCount = state.types.where((t) => t.category == ExamTypeCategoryEnum.practical || t.category == ExamTypeCategoryEnum.internalAssessment).length;
    final customCount = state.types.where((t) => !t.isSystem).length;

    // Filter types
    final filteredTypes = state.types.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || t.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examination Types',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage institutional examination categories, grading weightages, and assessment schemes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.read(examTypesProvider.notifier).loadTypes(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _showAddEditTypeDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exam Type'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Cards Row
            Row(
              children: [
                _buildKpiCard(
                  context,
                  title: 'Total Types',
                  value: totalTypes.toString(),
                  icon: Icons.assignment_outlined,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Scholastic Types',
                  value: scholasticCount.toString(),
                  icon: Icons.school_outlined,
                  color: Colors.teal,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Practical / Internal',
                  value: practicalCount.toString(),
                  icon: Icons.science_outlined,
                  color: Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  context,
                  title: 'Custom School Types',
                  value: customCount.toString(),
                  icon: Icons.tune_outlined,
                  color: Colors.amber[800]!,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error Banner
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => ref.read(examTypesProvider.notifier).loadTypes(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Filter and Search Toolbar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by exam type name or code...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ExamTypeCategoryEnum?>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category Filter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...ExamTypeCategoryEnum.values.map(
                            (cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.label),
                            ),
                          ),
                        ],
                        onChanged: (cat) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Table of Exam Types
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : filteredTypes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No examination types found.'),
                              ],
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                            columns: const [
                              DataColumn(label: Text('Type Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Default Weightage', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Type Scope', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filteredTypes.map((t) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (t.description != null && t.description!.isNotEmpty)
                                          Text(
                                            t.description!,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        t.code,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  DataCell(Text(t.category.label)),
                                  DataCell(Text('${t.defaultWeightage.toStringAsFixed(1)}%')),
                                  DataCell(
                                    t.isSystem
                                        ? const Chip(
                                            label: Text('System Standard', style: TextStyle(fontSize: 11)),
                                            backgroundColor: Color(0xFFE8F5E9),
                                            visualDensity: VisualDensity.compact,
                                          )
                                        : const Chip(
                                            label: Text('Custom School', style: TextStyle(fontSize: 11)),
                                            backgroundColor: Color(0xFFFFF3E0),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        t.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: t.isActive ? Colors.green[800] : Colors.red[800],
                                        ),
                                      ),
                                      backgroundColor: t.isActive ? Colors.green[50] : Colors.red[50],
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          tooltip: 'Edit Exam Type',
                                          onPressed: () => _showAddEditTypeDialog(context, existing: t),
                                        ),
                                        if (!t.isSystem)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            tooltip: 'Delete Exam Type',
                                            onPressed: () => _confirmDeleteType(context, t),
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
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditTypeDialog(BuildContext context, {ExamTypeMasterModel? existing}) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final weightageController = TextEditingController(text: (existing?.defaultWeightage ?? 100.0).toString());
    var selectedCategory = existing?.category ?? ExamTypeCategoryEnum.scholastic;
    var isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Exam Type' : 'Add New Exam Type'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Exam Type Name *',
                          hintText: 'e.g. Unit Test 1, Diagnostic Assessment',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        enabled: !isEditing, // Code is immutable once created
                        decoration: InputDecoration(
                          labelText: 'Type Code *',
                          hintText: 'e.g. UNIT_TEST, DIAGNOSTIC',
                          helperText: isEditing ? 'Type code cannot be changed once created' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ExamTypeCategoryEnum>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: ExamTypeCategoryEnum.values.map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label),
                          ),
                        ).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: weightageController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Default Weightage (%) *',
                          hintText: '100.0',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Additional details about this evaluation pattern...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Active Status'),
                        subtitle: const Text('Inactive types cannot be selected for new exams'),
                        value: isActive,
                        onChanged: (val) {
                          setDialogState(() {
                            isActive = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final code = codeController.text.trim();
                    final weightage = double.tryParse(weightageController.text.trim()) ?? 100.0;
                    final desc = descController.text.trim();

                    if (name.isEmpty || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in required fields.')),
                      );
                      return;
                    }

                    Navigator.of(dialogCtx).pop();

                    if (isEditing) {
                      await ref.read(examTypesProvider.notifier).updateType(
                            id: existing.id,
                            name: name,
                            description: desc,
                            category: selectedCategory,
                            defaultWeightage: weightage,
                            isActive: isActive,
                          );
                    } else {
                      await ref.read(examTypesProvider.notifier).createType(
                            name: name,
                            code: code,
                            description: desc,
                            category: selectedCategory,
                            defaultWeightage: weightage,
                          );
                    }
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Create Exam Type'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteType(BuildContext context, ExamTypeMasterModel type) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Exam Type?'),
          content: Text(
            'Are you sure you want to delete "${type.name}" (${type.code})?\n\n'
            'Note: You cannot delete exam types that are currently referenced by existing examinations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final ok = await ref.read(examTypesProvider.notifier).deleteType(type.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam type deleted successfully.')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
