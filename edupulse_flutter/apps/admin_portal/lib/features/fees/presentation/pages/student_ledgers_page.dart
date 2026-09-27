import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';
import '../../data/models/fee_models.dart';
import '../providers/fees_provider.dart';
import '../widgets/fee_receipt_dialog.dart';
import '../widgets/record_fee_payment_dialog.dart';

class StudentLedgersPage extends ConsumerStatefulWidget {
  final StudentDto? initialStudent;
  const StudentLedgersPage({super.key, this.initialStudent});

  @override
  ConsumerState<StudentLedgersPage> createState() => _StudentLedgersPageState();
}

class _StudentLedgersPageState extends ConsumerState<StudentLedgersPage> {
  final _searchController = TextEditingController();
  StudentDto? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.initialStudent;
  }

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
                                const Spacer(),
                                FilledButton.icon(
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: const Text('Record Payment'),
                                  onPressed: () {
                                    showRecordFeePaymentDialog(
                                      context: context,
                                      studentId: _selectedStudent!.id,
                                      studentName: '${_selectedStudent!.firstName} ${_selectedStudent!.lastName}',
                                      admissionNumber: _selectedStudent!.admissionNumber,
                                      schoolId: schoolId,
                                      initialLedger: ledger,
                                      onPaymentSuccess: () {
                                        ref.invalidate(studentLedgerProvider(_selectedStudent!.id));
                                      },
                                    );
                                  },
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
                                      onTap: () => _showAssignmentDetailsDialog(context, assign, name, dueDate, currencyFormatter, dateFormatter, schoolId),
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
                                        '${dateFormatter.format(pay.paymentDate)} | Method: ${pay.paymentMethod.name}${pay.cancelReason != null ? "\nReason: ${pay.cancelReason}" : ""}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                currencyFormatter.format(pay.amountPaid),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  decoration: pay.status == PaymentStatus.CANCELLED
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                              ),
                                              if (pay.status == PaymentStatus.CANCELLED)
                                                Text(
                                                  'CANCELLED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.receipt_long_outlined, size: 20, color: Colors.indigo),
                                            tooltip: 'View / Print Receipt',
                                            onPressed: () => _showReceiptDialog(
                                              context,
                                              pay,
                                              _selectedStudent!,
                                              schoolId,
                                              ledger,
                                            ),
                                          ),
                                          if (pay.status == PaymentStatus.COMPLETED) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                              tooltip: 'Edit Payment',
                                              onPressed: () => _showEditPaymentDialog(
                                                context,
                                                pay,
                                                _selectedStudent!.id,
                                                schoolId,
                                                currencyFormatter,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                                              tooltip: 'Cancel Payment',
                                              onPressed: () => _showCancelPaymentDialog(
                                                context,
                                                pay,
                                                _selectedStudent!.id,
                                                schoolId,
                                                currencyFormatter,
                                              ),
                                            ),
                                          ],
                                        ],
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
    String schoolId,
  ) {
    final netOutstanding = assign.assignedAmount + assign.fineAmount - assign.discountAmount - assign.paidAmount;

    showDialog(
      context: context,
      builder: (dialogCtx) {
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
                'Net Outstanding: ${currencyFormatter.format(netOutstanding)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Due Date: ${dueDate != null ? dateFormatter.format(dueDate) : "N/A"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
            if (netOutstanding > 0 && _selectedStudent != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Record Payment'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showRecordPaymentDialog(
                    context,
                    _selectedStudent!,
                    assign,
                    netOutstanding,
                    schoolId,
                    currencyFormatter,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showReceiptDialog(
    BuildContext context,
    FeePayment payment,
    StudentDto student,
    String schoolId,
    StudentLedger ledger,
  ) {
    final schoolsState = ref.read(schoolsListProvider);
    SchoolDto? school;
    for (final s in schoolsState.schools) {
      if (s.id == schoolId) {
        school = s;
        break;
      }
    }

    final ayState = ref.read(academicYearsProvider(schoolId));
    AcademicYearDto? ay;
    for (final y in ayState.years) {
      if (y.id == payment.academicYearId) {
        ay = y;
        break;
      }
    }

    String? feeTypeName;
    double? assignedAmount;
    double? discountAmount;
    double? fineAmount;

    if (payment.allocations.isNotEmpty) {
      final firstAlloc = payment.allocations.first;
      for (final a in ledger.assignments) {
        if (a.id == firstAlloc.assignmentId) {
          assignedAmount = a.assignedAmount;
          discountAmount = a.discountAmount;
          fineAmount = a.fineAmount;

          final structuresState = ref.read(feeStructuresProvider(schoolId));
          final typesState = ref.read(feeTypesProvider);
          for (final s in structuresState.structures) {
            if (s.id == a.feeStructureId) {
              for (final t in typesState.types) {
                if (t.id == s.feeTypeId) {
                  feeTypeName = t.name;
                  break;
                }
              }
              break;
            }
          }
          break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => FeeReceiptDialog(
        payment: payment,
        student: student,
        schoolName: school?.name ?? 'EduPulse Academy',
        schoolAddress: school?.address,
        schoolPhone: school?.phone,
        schoolEmail: school?.email,
        academicYearName: ay?.name,
        feeTypeName: feeTypeName,
        assignedAmount: assignedAmount,
        concessionAmount: discountAmount,
        fineAmount: fineAmount,
        remainingBalance: ledger.closingBalance,
        apiClient: ref.read(apiClientProvider),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(
    BuildContext context,
    StudentDto student,
    StudentFeeAssignment assign,
    double maxAmount,
    String schoolId,
    NumberFormat currencyFormatter,
  ) async {
    final amountController = TextEditingController(text: maxAmount.toStringAsFixed(0));
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    var selectedMethod = PaymentMethod.CASH;
    DateTime selectedDate = DateTime.now();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
            final liveRemaining = (maxAmount - enteredAmount).clamp(0.0, maxAmount);

            return AlertDialog(
              title: const Text('Record Fee Payment'),
              content: SizedBox(
                width: 460,
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
                              color: Theme.of(sbContext).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Theme.of(sbContext).colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                        // Balance Preview Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(sbContext).colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(sbContext).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Outstanding Due:'),
                                  Text(
                                    currencyFormatter.format(maxAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Remaining After Payment:'),
                                  Text(
                                    currencyFormatter.format(liveRemaining),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: liveRemaining == 0 ? Colors.green.shade700 : Theme.of(sbContext).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Payment Amount (₹) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee, size: 20),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a payment amount';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Amount must be greater than zero';
                            }
                            if (parsed > maxAmount) {
                              return 'Amount cannot exceed outstanding balance (${currencyFormatter.format(maxAmount)})';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Payment Date Selector
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: sbContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Payment Date *',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<PaymentMethod>(
                          value: selectedMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method *',
                            border: OutlineInputBorder(),
                          ),
                          items: PaymentMethod.values.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(m.name.replaceAll('_', ' ')),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedMethod = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: refController,
                          decoration: const InputDecoration(
                            labelText: 'Transaction Reference (Optional)',
                            hintText: 'e.g. UTR / Cheque No / Ref ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: remarksController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Remarks (Optional)',
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
                          final amount = double.parse(amountController.text.trim());
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final success = await ref
                              .read(feePaymentActionProvider.notifier)
                              .recordPayment(
                                studentId: student.id,
                                academicYearId: assign.academicYearId,
                                paymentMethod: selectedMethod,
                                transactionReference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                                remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                                schoolId: schoolId,
                                allocations: [
                                  {
                                    'assignment_id': assign.id,
                                    'amount_allocated': amount,
                                  },
                                ],
                              );
                          if (success) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              final recordedPayment = ref.read(feePaymentActionProvider).payment;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Payment recorded successfully!'),
                                  backgroundColor: Colors.green,
                                  action: recordedPayment != null
                                      ? SnackBarAction(
                                          label: 'View Receipt',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            if (!context.mounted) return;
                                            final ledgerState = ref.read(studentLedgerProvider(student.id));
                                            if (ledgerState.ledger != null) {
                                              _showReceiptDialog(
                                                context,
                                                recordedPayment,
                                                student,
                                                schoolId,
                                                ledgerState.ledger!,
                                              );
                                            }
                                          },
                                        )
                                      : null,
                                ),
                              );
                              // Automatically show receipt dialog for immediate printing / download
                              if (recordedPayment != null) {
                                final ledgerState = ref.read(studentLedgerProvider(student.id));
                                if (ledgerState.ledger != null) {
                                  _showReceiptDialog(
                                    context,
                                    recordedPayment,
                                    student,
                                    schoolId,
                                    ledgerState.ledger!,
                                  );
                                }
                              }
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = ref.read(feePaymentActionProvider).error ?? 'Payment recording failed';
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
                      : const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCancelPaymentDialog(
    BuildContext context,
    FeePayment payment,
    String studentId,
    String schoolId,
    NumberFormat currencyFormatter,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            return AlertDialog(
              title: const Text('Cancel Fee Payment'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(sbContext).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Theme.of(sbContext).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                      Text(
                        'Amount: ${currencyFormatter.format(payment.amountPaid)} | Receipt: ${payment.receiptNumber ?? "N/A"}',
                        style: Theme.of(sbContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Cancellation Reason *',
                          hintText: 'Please enter why this payment is being cancelled...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Cancellation reason is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Dismiss'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final success = await ref
                              .read(feePaymentActionProvider.notifier)
                              .cancelPayment(
                                paymentId: payment.id,
                                cancelReason: reasonController.text.trim(),
                                studentId: studentId,
                                schoolId: schoolId,
                              );
                          if (success) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment cancelled successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = ref.read(feePaymentActionProvider).error ?? 'Payment cancellation failed';
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Cancellation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditPaymentDialog(
    BuildContext context,
    FeePayment payment,
    String studentId,
    String schoolId,
    NumberFormat currencyFormatter,
  ) async {
    PaymentMethod selectedMethod = payment.paymentMethod;
    final refController = TextEditingController(text: payment.transactionReference ?? '');
    final remarksController = TextEditingController(text: payment.remarks ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Payment Details'),
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
                              color: Theme.of(sbContext).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Theme.of(sbContext).colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                        Text(
                          'Receipt: ${payment.receiptNumber ?? "N/A"} | Amount: ${currencyFormatter.format(payment.amountPaid)}',
                          style: Theme.of(sbContext).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<PaymentMethod>(
                          value: selectedMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method *',
                            border: OutlineInputBorder(),
                          ),
                          items: PaymentMethod.values.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(method.name.replaceAll('_', ' ')),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedMethod = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: refController,
                          decoration: const InputDecoration(
                            labelText: 'Transaction Reference / Cheque No.',
                            hintText: 'e.g. TXN987654321 / CHQ123456',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarksController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Remarks / Notes (Optional)',
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
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final success = await ref
                              .read(feePaymentActionProvider.notifier)
                              .updatePayment(
                                paymentId: payment.id,
                                studentId: studentId,
                                paymentMethod: selectedMethod,
                                transactionReference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                                remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                                schoolId: schoolId,
                              );
                          if (success) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = ref.read(feePaymentActionProvider).error ?? 'Payment update failed';
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
  }
}
