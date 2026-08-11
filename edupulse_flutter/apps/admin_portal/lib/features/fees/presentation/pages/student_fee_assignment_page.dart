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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    final searchState = ref.watch(studentSearchProvider(schoolId));
    final structuresState = ref.watch(feeStructuresProvider(schoolId));
    final scholarshipsState = ref.watch(scholarshipsProvider(schoolId));
    final creationState = ref.watch(feeAssignmentCreationProvider);
    final typesState = ref.watch(feeTypesProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    // Calculate preview values
    double originalFee = _selectedStructure?.amount ?? 0.0;
    double discount = 0.0;
    if (_selectedStructure != null && _selectedScholarship != null) {
      if (_selectedScholarship!.concessionType == ConcessionType.FIXED) {
        discount = _selectedScholarship!.value;
      } else {
        discount = originalFee * (_selectedScholarship!.value / 100.0);
      }
      if (discount > originalFee) {
        discount = originalFee;
      }
    }
    double netPayable = originalFee - discount;

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
                      Text(
                        '3. Attach Concession (Optional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      if (scholarshipsState.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<Scholarship?>(
                          value: _selectedScholarship,
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
                              final suffix = s.concessionType == ConcessionType.PERCENTAGE ? '%' : ' Fixed';
                              return DropdownMenuItem<Scholarship>(
                                value: s,
                                child: Text('${s.name} (${s.value}$suffix Waiver)'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedScholarship = val;
                            });
                          },
                        ),
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
                          const Text('Concession / Waiver:'),
                          Text(
                            '- ${currencyFormatter.format(discount)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.green.shade700,
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
                          onPressed: creationState.isLoading || _selectedStudent == null
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
                                    if (success && mounted) {
                                      // Refresh ledger status and metrics
                                      ref.invalidate(studentLedgerProvider(_selectedStudent!.id));
                                      ref.invalidate(feesDashboardProvider(schoolId));
                                      
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
