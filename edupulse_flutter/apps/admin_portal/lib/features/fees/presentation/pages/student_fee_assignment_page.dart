import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';
import '../../data/models/fee_models.dart';
import '../providers/fees_provider.dart';

class StudentFeeAssignmentPage extends ConsumerStatefulWidget {
  const StudentFeeAssignmentPage({super.key});

  @override
  ConsumerState<StudentFeeAssignmentPage> createState() => _StudentFeeAssignmentPageState();
}

class _StudentFeeAssignmentPageState extends ConsumerState<StudentFeeAssignmentPage> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StudentDto? _selectedStudent;
  FeeStructure? _selectedStructure;
  Scholarship? _selectedScholarship;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateConcessionDialog(BuildContext context, String schoolId) async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final descController = TextEditingController();
    var concessionType = ConcessionType.PERCENTAGE;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Concession'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Concession Name *',
                            hintText: 'e.g. Sibling Discount, Merit Scholarship',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a concession name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ConcessionType>(
                          value: concessionType,
                          decoration: const InputDecoration(
                            labelText: 'Concession Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ConcessionType.PERCENTAGE,
                              child: Text('Percentage (%)'),
                            ),
                            DropdownMenuItem(
                              value: ConcessionType.FIXED,
                              child: Text('Fixed Amount (₹)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                concessionType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: valueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: concessionType == ConcessionType.PERCENTAGE
                                ? 'Discount Percentage (%) *'
                                : 'Discount Amount (₹) *',
                            hintText: concessionType == ConcessionType.PERCENTAGE ? 'e.g. 25' : 'e.g. 1000',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a value';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Please enter a valid positive number';
                            }
                            if (concessionType == ConcessionType.PERCENTAGE && parsed > 100) {
                              return 'Percentage cannot exceed 100%';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText: 'Notes or criteria for this concession',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          final parsedValue = double.parse(valueController.text.trim());
                          final desc = descController.text.trim().isEmpty ? null : descController.text.trim();
                          final created = await ref
                              .read(scholarshipsProvider(schoolId).notifier)
                              .createScholarshipAndReturn(
                                nameController.text.trim(),
                                concessionType,
                                parsedValue,
                                desc,
                              );
                          if (created != null) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              setState(() {
                                _selectedScholarship = created;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Concession "${created.name}" created and applied'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = ref.read(scholarshipsProvider(schoolId)).error ?? 'Failed to create concession';
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Concession'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    valueController.dispose();
    descController.dispose();
  }

  Future<void> _showEditConcessionDialog(
    BuildContext context,
    String schoolId,
    Scholarship scholarship,
  ) async {
    final nameController = TextEditingController(text: scholarship.name);
    final valueController = TextEditingController(
      text: scholarship.value.truncateToDouble() == scholarship.value
          ? scholarship.value.toInt().toString()
          : scholarship.value.toString(),
    );
    final descController = TextEditingController(text: scholarship.description ?? '');
    var concessionType = scholarship.concessionType;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Concession: ${scholarship.name}'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Concession Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a concession name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ConcessionType>(
                          value: concessionType,
                          decoration: const InputDecoration(
                            labelText: 'Concession Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ConcessionType.PERCENTAGE,
                              child: Text('Percentage (%)'),
                            ),
                            DropdownMenuItem(
                              value: ConcessionType.FIXED,
                              child: Text('Fixed Amount (₹)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                concessionType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: valueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: concessionType == ConcessionType.PERCENTAGE
                                ? 'Discount Percentage (%) *'
                                : 'Discount Amount (₹) *',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a value';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Please enter a valid positive number';
                            }
                            if (concessionType == ConcessionType.PERCENTAGE && parsed > 100) {
                              return 'Percentage cannot exceed 100%';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          final parsedValue = double.parse(valueController.text.trim());
                          final desc = descController.text.trim().isEmpty ? null : descController.text.trim();
                          final updated = await ref
                              .read(scholarshipsProvider(schoolId).notifier)
                              .updateScholarshipAndReturn(
                                id: scholarship.id,
                                name: nameController.text.trim(),
                                concessionType: concessionType,
                                value: parsedValue,
                                description: desc,
                              );
                          if (updated != null) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              setState(() {
                                _selectedScholarship = updated;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Concession "${updated.name}" updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = ref.read(scholarshipsProvider(schoolId)).error ?? 'Failed to update concession';
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    valueController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    final effectiveSchoolId = _selectedStudent?.schoolId.isNotEmpty == true
        ? _selectedStudent!.schoolId
        : (_selectedStructure?.schoolId.isNotEmpty == true
            ? _selectedStructure!.schoolId
            : schoolId);
    final currentSchoolId = effectiveSchoolId.isNotEmpty ? effectiveSchoolId : schoolId;

    final searchState = ref.watch(studentSearchProvider(currentSchoolId));
    final structuresState = ref.watch(feeStructuresProvider(currentSchoolId));
    final scholarshipsState = ref.watch(scholarshipsProvider(currentSchoolId));
    final creationState = ref.watch(feeAssignmentCreationProvider);
    final typesState = ref.watch(feeTypesProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    // Calculate preview values
    final double originalFee = _selectedStructure?.amount ?? 0.0;
    double rawDiscount = 0.0;
    if (_selectedStructure != null && _selectedScholarship != null) {
      if (_selectedScholarship!.concessionType == ConcessionType.FIXED) {
        rawDiscount = _selectedScholarship!.value;
      } else {
        rawDiscount = originalFee * (_selectedScholarship!.value / 100.0);
      }
    }
    final bool isConcessionExceeded = _selectedStructure != null &&
        _selectedScholarship != null &&
        rawDiscount > originalFee;
    final double discount = isConcessionExceeded ? originalFee : rawDiscount;
    final double netPayable = (originalFee - discount).clamp(0.0, double.infinity);

    // Ensure selected scholarship points to current instance in list if present
    final selectedInList = _selectedScholarship != null
        ? (scholarshipsState.scholarships.any((s) => s.id == _selectedScholarship!.id)
            ? scholarshipsState.scholarships.firstWhere((s) => s.id == _selectedScholarship!.id)
            : _selectedScholarship)
        : null;

    String getFeeTypeName(String feeTypeId) {
      for (final t in typesState.types) {
        if (t.id == feeTypeId) return t.name;
      }
      return 'Unknown Type';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Student Fee'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SELECT STUDENT CARD
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Search & Select Student',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by student name, roll number, or admission code...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(studentSearchProvider(schoolId).notifier).search('');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          ref.read(studentSearchProvider(schoolId).notifier).search(val);
                        },
                      ),
                      if (searchState.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (searchState.error != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.sm),
                          child: Text(
                            searchState.error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      if (_searchController.text.isNotEmpty &&
                          !searchState.isLoading &&
                          searchState.students.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          margin: EdgeInsets.only(top: spacing.xs),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchState.students.length,
                            itemBuilder: (context, index) {
                              final student = searchState.students[index];
                              return ListTile(
                                title: Text('${student.firstName} ${student.lastName}'),
                                subtitle: Text('Roll: ${student.rollNumber} | Adm: ${student.admissionNumber}'),
                                onTap: () {
                                  setState(() {
                                    _selectedStudent = student;
                                  });
                                  _searchController.clear();
                                  ref.read(studentSearchProvider(schoolId).notifier).search('');
                                },
                              );
                            },
                          ),
                        ),
                      if (_selectedStudent != null) ...[
                        SizedBox(height: spacing.md),
                        Container(
                          padding: EdgeInsets.all(spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(radius.sm),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text(
                                  _selectedStudent!.firstName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_selectedStudent!.firstName} ${_selectedStudent!.lastName}',
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Admission Number: ${_selectedStudent!.admissionNumber} | Class: ${_selectedStudent!.className ?? "N/A"}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _selectedStudent = null;
                                  });
                                },
                              )
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // 2. CHOOSE FEE STRUCTURE
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Select Fee Structure',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      if (structuresState.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (structuresState.structures.isEmpty)
                        Text(
                          'No active fee structures configured for this school.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        )
                      else
                        DropdownButtonFormField<FeeStructure>(
                          value: _selectedStructure,
                          decoration: const InputDecoration(
                            labelText: 'Fee Category / Amount',
                            border: OutlineInputBorder(),
                          ),
                          items: structuresState.structures.map((s) {
                            final name = getFeeTypeName(s.feeTypeId);
                            final classScope = s.classId == null ? 'All Classes' : 'Class Scope';
                            return DropdownMenuItem<FeeStructure>(
                              value: s,
                              child: Text('$name - ${currencyFormatter.format(s.amount)} ($classScope)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedStructure = val;
                            });
                          },
                          validator: (val) => val == null ? 'Please select a fee structure' : null,
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // 3. ATTACH CONCESSION (OPTIONAL)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '3. Attach Concession (Optional)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('+ Create Concession'),
                            onPressed: currentSchoolId.isEmpty
                                ? null
                                : () => _showCreateConcessionDialog(context, currentSchoolId),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      if (scholarshipsState.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (scholarshipsState.error != null)
                        Container(
                          padding: EdgeInsets.all(spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  scholarshipsState.error!,
                                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                onPressed: () => ref
                                    .read(scholarshipsProvider(currentSchoolId).notifier)
                                    .fetchScholarships(),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<Scholarship?>(
                                key: ValueKey(selectedInList?.id ?? 'none'),
                                value: selectedInList,
                                decoration: const InputDecoration(
                                  labelText: 'Scholarship / Waiver',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<Scholarship?>(
                                    value: null,
                                    child: Text('No Concession (Full Price)'),
                                  ),
                                  ...scholarshipsState.scholarships.map((s) {
                                    final suffix = s.concessionType == ConcessionType.PERCENTAGE
                                        ? '${s.value.toStringAsFixed(s.value.truncateToDouble() == s.value ? 0 : 2)}%'
                                        : currencyFormatter.format(s.value);
                                    return DropdownMenuItem<Scholarship?>(
                                      value: s,
                                      child: Text('${s.name} ($suffix Waiver)'),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedScholarship = val;
                                  });
                                },
                              ),
                            ),
                            if (selectedInList != null) ...[
                              SizedBox(width: spacing.sm),
                              IconButton.outlined(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Concession',
                                onPressed: () => _showEditConcessionDialog(
                                  context,
                                  currentSchoolId,
                                  selectedInList,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (selectedInList?.description != null && selectedInList!.description!.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.only(top: spacing.xs, left: spacing.xs),
                            child: Text(
                              selectedInList.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        if (isConcessionExceeded) ...[
                          SizedBox(height: spacing.sm),
                          Container(
                            padding: EdgeInsets.all(spacing.sm),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(radius.sm),
                              border: Border.all(color: theme.colorScheme.error),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                                SizedBox(width: spacing.sm),
                                Expanded(
                                  child: Text(
                                    'Concession cannot exceed the original fee amount (${currencyFormatter.format(originalFee)}).',
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // 4. PREVIEW PANEL & ASSIGN ACTION
              Card(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '4. Review Pricing & Preview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Original Fee Amount:'),
                          Text(
                            currencyFormatter.format(originalFee),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Applied Concession:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedScholarship != null ? _selectedScholarship!.name : 'None',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: _selectedScholarship != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedScholarship != null) ...[
                        SizedBox(height: spacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Concession Rate / Type:'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedScholarship!.concessionType == ConcessionType.PERCENTAGE
                                    ? '${_selectedScholarship!.value.toStringAsFixed(_selectedScholarship!.value.truncateToDouble() == _selectedScholarship!.value ? 0 : 2)}% (${_selectedScholarship!.concessionType.name})'
                                    : '${currencyFormatter.format(_selectedScholarship!.value)} (${_selectedScholarship!.concessionType.name})',
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: spacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Concession / Waiver:'),
                          Text(
                            '- ${currencyFormatter.format(discount)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: discount > 0 ? Colors.green.shade700 : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net Payable Amount:',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            currencyFormatter.format(netPayable),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (creationState.error != null) ...[
                        SizedBox(height: spacing.md),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                          child: Text(
                            creationState.error!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                      SizedBox(height: spacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: creationState.isLoading ||
                                  _selectedStudent == null ||
                                  _selectedStructure == null ||
                                  isConcessionExceeded
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    final success = await ref
                                        .read(feeAssignmentCreationProvider.notifier)
                                        .assignFee(
                                          studentId: _selectedStudent!.id,
                                          feeStructureId: _selectedStructure!.id,
                                          scholarshipId: _selectedScholarship?.id,
                                        );
                                    if (success && mounted && context.mounted) {
                                      // Refresh ledger status and metrics
                                      ref.invalidate(studentLedgerProvider(_selectedStudent!.id));
                                      ref.invalidate(feesDashboardProvider(currentSchoolId));
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Fee structure assigned successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      
                                      setState(() {
                                        _selectedStudent = null;
                                        _selectedStructure = null;
                                        _selectedScholarship = null;
                                      });
                                    }
                                  }
                                },
                          child: creationState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Confirm Fee Assignment'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
