import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/fee_models.dart';
import '../providers/fees_provider.dart';

final _uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

bool _isValidAssignmentId(String id) {
  if (id.isEmpty || id == 'default_assign_id') return false;
  return _uuidRegex.hasMatch(id) || id.startsWith('assign_');
}

bool _isValidAcademicYearId(String id) {
  if (id.isEmpty || id == 'default_ay_id') return false;
  return _uuidRegex.hasMatch(id) || id.startsWith('ay_');
}

/// Canonical dialog for recording fee payments for a student.
/// Validates genuine assignment UUIDs, supports multi-assignment allocation,
/// and handles students with no fee assignments gracefully.
Future<void> showRecordFeePaymentDialog({
  required BuildContext context,
  required String studentId,
  required String studentName,
  required String admissionNumber,
  required String schoolId,
  String? initialAcademicYearId,
  StudentLedger? initialLedger,
  String? preselectedAssignmentId,
  VoidCallback? onPaymentSuccess,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => RecordFeePaymentDialog(
      studentId: studentId,
      studentName: studentName,
      admissionNumber: admissionNumber,
      schoolId: schoolId,
      initialAcademicYearId: initialAcademicYearId,
      initialLedger: initialLedger,
      preselectedAssignmentId: preselectedAssignmentId,
      onPaymentSuccess: onPaymentSuccess,
    ),
  );
}

class RecordFeePaymentDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String schoolId;
  final String? initialAcademicYearId;
  final StudentLedger? initialLedger;
  final String? preselectedAssignmentId;
  final VoidCallback? onPaymentSuccess;

  const RecordFeePaymentDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.schoolId,
    this.initialAcademicYearId,
    this.initialLedger,
    this.preselectedAssignmentId,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<RecordFeePaymentDialog> createState() => _RecordFeePaymentDialogState();
}

class _RecordFeePaymentDialogState extends ConsumerState<RecordFeePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _remarksController = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.CASH;
  DateTime _selectedDate = DateTime.now();
  String? _selectedAssignmentId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLedger == null) {
        ref.read(studentLedgerProvider(widget.studentId).notifier).fetchLedger();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double _getAssignmentNetDue(StudentFeeAssignment a) {
    return (a.assignedAmount + a.fineAmount - a.discountAmount - a.paidAmount).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final ledgerState = ref.watch(studentLedgerProvider(widget.studentId));
    final ledger = widget.initialLedger ?? ledgerState.ledger;
    final isLoadingLedger = ledger == null && ledgerState.isLoading;

    if (isLoadingLedger) {
      return AlertDialog(
        title: const Text('Record Fee Payment'),
        content: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    final validAssignments = (ledger?.assignments ?? []).where((a) => _isValidAssignmentId(a.id)).toList();

    // Auto-select assignment if not already selected
    if (_selectedAssignmentId == null && validAssignments.isNotEmpty) {
      if (widget.preselectedAssignmentId != null &&
          validAssignments.any((a) => a.id == widget.preselectedAssignmentId)) {
        _selectedAssignmentId = widget.preselectedAssignmentId;
      } else {
        final withDue = validAssignments.where((a) => _getAssignmentNetDue(a) > 0).toList();
        _selectedAssignmentId = withDue.isNotEmpty ? withDue.first.id : validAssignments.first.id;
      }
      final currentAssign = validAssignments.firstWhere((a) => a.id == _selectedAssignmentId);
      final initialDue = _getAssignmentNetDue(currentAssign);
      if (_amountController.text.isEmpty && initialDue > 0) {
        _amountController.text = initialDue.toStringAsFixed(0);
      }
    }

    final hasNoAssignments = validAssignments.isEmpty;
    StudentFeeAssignment? selectedAssign;
    double maxDue = 0.0;
    if (!hasNoAssignments && _selectedAssignmentId != null) {
      selectedAssign = validAssignments.where((a) => a.id == _selectedAssignmentId).firstOrNull ?? validAssignments.first;
      maxDue = _getAssignmentNetDue(selectedAssign);
    }

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final liveRemaining = (maxDue - enteredAmount).clamp(0.0, maxDue);

    final screenH = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Record Fee Payment',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: (screenH * 0.85).clamp(300.0, 650.0),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Student Identity Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Admission No: ${widget.admissionNumber}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (hasNoAssignments) ...[
                  // Informative empty state banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'No Fee Assignments Found',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No fee structures are currently assigned to this student. Please assign fees to this student or class before recording a payment.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Multi-assignment selector if > 1
                  if (validAssignments.length > 1) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedAssignmentId,
                      decoration: const InputDecoration(
                        labelText: 'Select Fee Assignment *',
                        border: OutlineInputBorder(),
                      ),
                      items: validAssignments.map((a) {
                        final due = _getAssignmentNetDue(a);
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            'Assign: ${currencyFormatter.format(a.assignedAmount)} | Due: ${currencyFormatter.format(due)} (${a.status.name})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAssignmentId = val;
                            final assign = validAssignments.firstWhere((a) => a.id == val);
                            final due = _getAssignmentNetDue(assign);
                            if (due > 0) {
                              _amountController.text = due.toStringAsFixed(0);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Balance Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Outstanding Dues:'),
                            Text(
                              currencyFormatter.format(maxDue),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                                color: liveRemaining == 0 ? Colors.green.shade700 : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    key: const Key('modal_payment_amount_field'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount (₹) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a payment amount';
                      }
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Amount must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Payment Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Method
                  DropdownButtonFormField<PaymentMethod>(
                    value: _selectedMethod,
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
                      if (val != null) setState(() => _selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Reference
                  TextFormField(
                    key: const Key('payment_ref_field'),
                    controller: _refController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Reference (Optional)',
                      hintText: 'e.g. UTR / Cheque No / Ref ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  TextFormField(
                    key: const Key('payment_remarks_field'),
                    controller: _remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(hasNoAssignments ? 'Close' : 'Cancel'),
        ),
        if (!hasNoAssignments)
          KeyedSubtree(
            key: const Key('confirm_payment_button'),
            child: ElevatedButton(
              key: const Key('modal_submit_payment_button'),
              onPressed: _isSubmitting ? null : () => _submitPayment(selectedAssign!),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Payment'),
            ),
          ),
      ],
    );
  }

  Future<void> _submitPayment(StudentFeeAssignment assignment) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isValidAssignmentId(assignment.id)) {
      setState(() {
        _errorMessage = 'Invalid fee assignment record identifier. Please refresh the page.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final amount = double.parse(_amountController.text.trim());
    final academicYearId = assignment.academicYearId.isNotEmpty
        ? assignment.academicYearId
        : (widget.initialAcademicYearId ?? '');

    if (!_isValidAcademicYearId(academicYearId)) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Invalid academic year record identifier for this assignment.';
      });
      return;
    }

    final success = await ref.read(feePaymentActionProvider.notifier).recordPayment(
      studentId: widget.studentId,
      academicYearId: academicYearId,
      paymentMethod: _selectedMethod,
      transactionReference: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      schoolId: widget.schoolId,
      allocations: [
        {
          'assignment_id': assignment.id,
          'amount_allocated': amount,
        },
      ],
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        widget.onPaymentSuccess?.call();
        final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ${currencyFormatter.format(amount)} recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(feePaymentActionProvider).error;
        setState(() {
          _isSubmitting = false;
          _errorMessage = error ?? 'Failed to record payment. Please try again.';
        });
      }
    }
  }
}
