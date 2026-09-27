import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/utils/numeric_utils.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class ExpenseItem {
  final String id;
  final String category;
  final String? subcategory;
  final double amount;
  final String expenseDate;
  final String description;
  final String paidTo;
  final String paymentMethod;
  final String? referenceNumber;
  final String? salaryPaymentId;
  final String status;

  const ExpenseItem({
    required this.id,
    required this.category,
    this.subcategory,
    required this.amount,
    required this.expenseDate,
    required this.description,
    required this.paidTo,
    required this.paymentMethod,
    this.referenceNumber,
    this.salaryPaymentId,
    required this.status,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'OPERATIONS',
      subcategory: json['subcategory'] as String?,
      amount: safeParseDouble(json['amount']),
      expenseDate: json['expense_date'] as String? ?? '',
      description: json['description'] as String? ?? '',
      paidTo: json['paid_to'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'BANK_TRANSFER',
      referenceNumber: json['reference_number'] as String?,
      salaryPaymentId: json['salary_payment_id'] as String?,
      status: json['status'] as String? ?? 'APPROVED',
    );
  }
}

final expensesListProvider = FutureProvider.autoDispose<List<ExpenseItem>>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return [];
  final apiClient = ref.watch(apiClientProvider);
  final res = await apiClient.get(
    '/expenses?school_id=$schoolId',
    mapper: (json) {
      final list = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      return list.map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
  return res.when(
    onSuccess: (data) => data,
    onFailure: (err) => throw Exception(err.message),
  );
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesListProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Expenditures'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(expensesListProvider),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Record Expense'),
            onPressed: schoolId == null ? null : () => _showAddExpenseDialog(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading expenses: $e')),
        data: (expenses) {
          final filtered = _selectedCategory == null
              ? expenses
              : expenses.where((e) => e.category == _selectedCategory).toList();

          final totalAmount = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              // Category filter and summary banner
              Container(
                padding: const EdgeInsets.all(16.0),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Expenditures', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text('₹${totalAmount.toStringAsFixed(0)}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                    DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: const Text('All Categories'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Categories')),
                        DropdownMenuItem(value: 'STAFF', child: Text('Staff (Payroll)')),
                        DropdownMenuItem(value: 'INFRASTRUCTURE', child: Text('Infrastructure')),
                        DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic')),
                        DropdownMenuItem(value: 'OPERATIONS', child: Text('Operations')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('No expenses recorded in this view.', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Record First Expense'),
                              onPressed: () => _showAddExpenseDialog(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          final isLinkedToSalary = item.salaryPaymentId != null;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getCategoryColor(item.category).withValues(alpha: 0.15),
                                child: Icon(_getCategoryIcon(item.category), color: _getCategoryColor(item.category), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Text(
                                    '₹${item.amount.toStringAsFixed(0)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Text('Paid to: ${item.paidTo} • Date: ${item.expenseDate} • ${item.paymentMethod}'),
                                    const Spacer(),
                                    if (isLinkedToSalary)
                                      const Chip(
                                        label: Text('Salary Linked', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                        backgroundColor: Color(0xFFE3F2FD),
                                        side: BorderSide.none,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ),
                              trailing: isLinkedToSalary
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Edit Expense',
                                          onPressed: () => _showEditExpenseDialog(context, item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _confirmDeleteExpense(context, item),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'STAFF':
        return Colors.purple;
      case 'INFRASTRUCTURE':
        return Colors.orange;
      case 'ACADEMIC':
        return Colors.blue;
      case 'OPERATIONS':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'STAFF':
        return Icons.people_outline;
      case 'INFRASTRUCTURE':
        return Icons.business_outlined;
      case 'ACADEMIC':
        return Icons.school_outlined;
      case 'OPERATIONS':
        return Icons.miscellaneous_services_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final descCtrl = TextEditingController();
    final paidToCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refNumCtrl = TextEditingController();
    String category = 'OPERATIONS';
    String paymentMethod = 'BANK_TRANSFER';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record School Expense'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'OPERATIONS', child: Text('Operations & Utilities')),
                      DropdownMenuItem(value: 'INFRASTRUCTURE', child: Text('Infrastructure & Repairs')),
                      DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic & Library Supplies')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidToCtrl,
                    decoration: const InputDecoration(labelText: 'Paid To (Vendor / Person)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('UPI / Online')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refNumCtrl,
                    decoration: const InputDecoration(labelText: 'Reference Number (Optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (descCtrl.text.trim().isEmpty || paidToCtrl.text.trim().isEmpty || amt <= 0) return;
                final apiClient = ref.read(apiClientProvider);
                final todayStr = DateTime.now().toIso8601String().split('T').first;

                await apiClient.post(
                  '/expenses',
                  data: {
                    'school_id': schoolId,
                    'category': category,
                    'amount': amt,
                    'expense_date': todayStr,
                    'description': descCtrl.text.trim(),
                    'paid_to': paidToCtrl.text.trim(),
                    'payment_method': paymentMethod,
                    'reference_number': refNumCtrl.text.trim().isEmpty ? null : refNumCtrl.text.trim(),
                  },
                  mapper: (json) => json,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(expensesListProvider);
              },
              child: const Text('Record Expense'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditExpenseDialog(BuildContext context, ExpenseItem item) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final descCtrl = TextEditingController(text: item.description);
    final paidToCtrl = TextEditingController(text: item.paidTo);
    final amountCtrl = TextEditingController(text: item.amount.toStringAsFixed(2));
    final refNumCtrl = TextEditingController(text: item.referenceNumber ?? '');
    String category = ['OPERATIONS', 'INFRASTRUCTURE', 'ACADEMIC', 'OTHER'].contains(item.category)
        ? item.category
        : 'OPERATIONS';
    String paymentMethod = item.paymentMethod;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit School Expense'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'OPERATIONS', child: Text('Operations & Utilities')),
                      DropdownMenuItem(value: 'INFRASTRUCTURE', child: Text('Infrastructure & Repairs')),
                      DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic & Library Supplies')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidToCtrl,
                    decoration: const InputDecoration(labelText: 'Paid To (Vendor / Person)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: ['BANK_TRANSFER', 'CHEQUE', 'CASH', 'ONLINE'].contains(paymentMethod) ? paymentMethod : 'BANK_TRANSFER',
                    decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('UPI / Online')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refNumCtrl,
                    decoration: const InputDecoration(labelText: 'Reference Number (Optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (descCtrl.text.trim().isEmpty || paidToCtrl.text.trim().isEmpty || amt <= 0) return;
                final apiClient = ref.read(apiClientProvider);

                await apiClient.put(
                  '/expenses/${item.id}?school_id=$schoolId',
                  data: {
                    'category': category,
                    'amount': amt,
                    'description': descCtrl.text.trim(),
                    'paid_to': paidToCtrl.text.trim(),
                    'payment_method': paymentMethod,
                    'reference_number': refNumCtrl.text.trim().isEmpty ? null : refNumCtrl.text.trim(),
                  },
                  mapper: (json) => json,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(expensesListProvider);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(BuildContext context, ExpenseItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete expense "${item.description}" of ₹${item.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(
        '/expenses/${item.id}?school_id=$schoolId',
        mapper: (json) => json,
      );
      ref.invalidate(expensesListProvider);
    }
  }
}
