import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';
import '../../data/models/fee_models.dart';
import '../providers/fees_provider.dart';

class StudentLedgersPage extends ConsumerStatefulWidget {
  const StudentLedgersPage({super.key});

  @override
  ConsumerState<StudentLedgersPage> createState() => _StudentLedgersPageState();
}

class _StudentLedgersPageState extends ConsumerState<StudentLedgersPage> {
  final _searchController = TextEditingController();
  StudentDto? _selectedStudent;

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
    final typesState = ref.watch(feeTypesProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd MMM yyyy');

    String getFeeTypeName(String feeStructureId) {
      for (final s in structuresState.structures) {
        if (s.id == feeStructureId) {
          for (final t in typesState.types) {
            if (t.id == s.feeTypeId) return t.name;
          }
        }
      }
      return 'General Fee';
    }

    DateTime? getFeeDueDate(String feeStructureId) {
      for (final s in structuresState.structures) {
        if (s.id == feeStructureId) return s.dueDate;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Fee Ledger'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEARCH BOX HEADER
          Container(
            padding: EdgeInsets.all(spacing.md),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Student to View Ledger',
                    hintText: 'Enter student name or roll number...',
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
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: LinearProgressIndicator()),
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
              ],
            ),
          ),
          const Divider(height: 1),

          // SELECTED STUDENT LEDGER DETAILS
          Expanded(
            child: _selectedStudent == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: spacing.md),
                        Text(
                          'Select a student above to inspect their financial ledger.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : Consumer(
                    builder: (context, ref, child) {
                      final ledgerState = ref.watch(studentLedgerProvider(_selectedStudent!.id));

                      if (ledgerState.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (ledgerState.error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ledgerState.error!,
                                  style: TextStyle(color: theme.colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref.refresh(studentLedgerProvider(_selectedStudent!.id)),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final ledger = ledgerState.ledger;
                      if (ledger == null) {
                        return const Center(child: Text('No ledger details found.'));
                      }

                      // Derive calculations
                      double totalAssigned = ledger.assignments.fold(0.0, (sum, a) => sum + a.assignedAmount + a.fineAmount);
                      double totalConcession = ledger.assignments.fold(0.0, (sum, a) => sum + a.discountAmount);
                      double totalPaid = ledger.assignments.fold(0.0, (sum, a) => sum + a.paidAmount);
                      double outstanding = ledger.closingBalance;

                      return SingleChildScrollView(
                        padding: EdgeInsets.all(spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // STUDENT HEADER INFO CARD
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    _selectedStudent!.firstName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                SizedBox(width: spacing.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_selectedStudent!.firstName} ${_selectedStudent!.lastName}',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Roll: ${_selectedStudent!.rollNumber} | Admission: ${_selectedStudent!.admissionNumber}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: spacing.md),

                            // SUMMARY CARD GRID
                            GridView.count(
                              crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: spacing.sm,
                              mainAxisSpacing: spacing.sm,
                              childAspectRatio: 1.8,
                              children: [
                                _buildSummaryCard(theme, 'Total Assigned', currencyFormatter.format(totalAssigned), Colors.blue),
                                _buildSummaryCard(theme, 'Concessions', currencyFormatter.format(totalConcession), Colors.green),
                                _buildSummaryCard(theme, 'Total Paid', currencyFormatter.format(totalPaid), Colors.purple),
                                _buildSummaryCard(theme, 'Outstanding', currencyFormatter.format(outstanding), Colors.red),
                              ],
                            ),
                            SizedBox(height: spacing.lg),

                            // ASSIGNED FEES LIST
                            Text(
                              'Fee Assignments & Allocations',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: spacing.sm),
                            if (ledger.assignments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No fee assignments recorded for this student.'),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: ledger.assignments.length,
                                separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                                itemBuilder: (context, index) {
                                  final assign = ledger.assignments[index];
                                  final name = getFeeTypeName(assign.feeStructureId);
                                  final dueDate = getFeeDueDate(assign.feeStructureId);
                                  final netAmount = assign.assignedAmount + assign.fineAmount - assign.discountAmount;
                                  
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Due: ${dueDate != null ? dateFormatter.format(dueDate) : "N/A"}',
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormatter.format(netAmount - assign.paidAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: assign.status == FeeAssignmentStatus.PAID
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: assign.status == FeeAssignmentStatus.PAID
                                                  ? Colors.green.shade50
                                                  : assign.status == FeeAssignmentStatus.PARTIALLY_PAID
                                                      ? Colors.orange.shade50
                                                      : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              assign.status.name,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: assign.status == FeeAssignmentStatus.PAID
                                                    ? Colors.green.shade700
                                                    : assign.status == FeeAssignmentStatus.PARTIALLY_PAID
                                                        ? Colors.orange.shade700
                                                        : Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _showAssignmentDetailsDialog(context, assign, name, dueDate, currencyFormatter, dateFormatter),
                                    ),
                                  );
                                },
                              ),
                            SizedBox(height: spacing.lg),

                            // TRANSACTION PAYMENT HISTORY
                            Text(
                              'Payment & Invoicing History',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: spacing.sm),
                            if (ledger.payments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No transaction payments recorded for this student.'),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: ledger.payments.length,
                                separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                                itemBuilder: (context, index) {
                                  final pay = ledger.payments[index];
                                  return Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: pay.status == PaymentStatus.COMPLETED
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        child: Icon(
                                          pay.status == PaymentStatus.COMPLETED
                                              ? Icons.check_circle_outline
                                              : Icons.cancel_outlined,
                                          color: pay.status == PaymentStatus.COMPLETED
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      title: Text(
                                        'Receipt: ${pay.receiptNumber ?? "Pending"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${dateFormatter.format(pay.paymentDate)} | Method: ${pay.paymentMethod.name}',
                                      ),
                                      trailing: Text(
                                        currencyFormatter.format(pay.amountPaid),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String title, String val, Color accent) {
    return Card(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignmentDetailsDialog(
    BuildContext context,
    StudentFeeAssignment assign,
    String name,
    DateTime? dueDate,
    NumberFormat currencyFormatter,
    DateFormat dateFormatter,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original Amount: ${currencyFormatter.format(assign.assignedAmount)}'),
              const SizedBox(height: 4),
              Text('Discount: ${currencyFormatter.format(assign.discountAmount)}', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 4),
              Text('Late Fine: ${currencyFormatter.format(assign.fineAmount)}', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 4),
              Text('Paid: ${currencyFormatter.format(assign.paidAmount)}'),
              const Divider(),
              Text(
                'Net Outstanding: ${currencyFormatter.format(assign.assignedAmount + assign.fineAmount - assign.discountAmount - assign.paidAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Due Date: ${dueDate != null ? dateFormatter.format(dueDate) : "N/A"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
