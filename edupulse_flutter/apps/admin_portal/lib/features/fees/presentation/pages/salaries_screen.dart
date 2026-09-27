import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/utils/numeric_utils.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class StaffSalaryItem {
  final String id;
  final String staffId;
  final String staffName;
  final String staffCode;
  final int month;
  final int year;
  final double baseSalary;
  final double allowances;
  final double deductions;
  final double netSalary;
  final String status;
  final String? paymentDate;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? remarks;

  const StaffSalaryItem({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffCode,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.allowances,
    required this.deductions,
    required this.netSalary,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.referenceNumber,
    this.remarks,
  });

  factory StaffSalaryItem.fromJson(Map<String, dynamic> json) {
    return StaffSalaryItem(
      id: json['id'] as String? ?? '',
      staffId: json['staff_id'] as String? ?? '',
      staffName: json['staff_name'] as String? ?? 'Staff Member',
      staffCode: json['staff_code'] as String? ?? 'EMP',
      month: safeParseInt(json['month'], 1),
      year: safeParseInt(json['year'], 2026),
      baseSalary: safeParseDouble(json['base_salary']),
      allowances: safeParseDouble(json['allowances']),
      deductions: safeParseDouble(json['deductions']),
      netSalary: safeParseDouble(json['net_salary']),
      status: json['status'] as String? ?? 'PENDING',
      paymentDate: json['payment_date'] as String?,
      paymentMethod: json['payment_method'] as String?,
      referenceNumber: json['reference_number'] as String?,
      remarks: json['remarks'] as String?,
    );
  }
}

final salariesListProvider = FutureProvider.autoDispose<List<StaffSalaryItem>>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return [];
  final apiClient = ref.watch(apiClientProvider);
  final res = await apiClient.get(
    '/staff-salaries?school_id=$schoolId',
    mapper: (json) {
      final list = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      return list.map((e) => StaffSalaryItem.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
  return res.when(
    onSuccess: (data) => data,
    onFailure: (err) => throw Exception(err.message),
  );
});

class SalariesScreen extends ConsumerStatefulWidget {
  const SalariesScreen({super.key});

  @override
  ConsumerState<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends ConsumerState<SalariesScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salariesAsync = ref.watch(salariesListProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Salaries & Payroll'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(salariesListProvider),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Generate Salaries'),
            onPressed: schoolId == null ? null : () => _generateSalaries(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: salariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading salaries: $e')),
        data: (salaries) {
          if (salaries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No salary records found for this period.', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Generate Salary Slips'),
                    onPressed: () => _generateSalaries(context),
                  ),
                ],
              ),
            );
          }

          final totalNet = salaries.fold<double>(0.0, (sum, s) => sum + s.netSalary);
          final paidNet = salaries.where((s) => s.status == 'PAID').fold<double>(0.0, (sum, s) => sum + s.netSalary);

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16.0),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    _buildStatCard('Total Payroll', '₹${totalNet.toStringAsFixed(0)}', Icons.monetization_on_outlined, theme),
                    const SizedBox(width: 16),
                    _buildStatCard('Disbursed (Paid)', '₹${paidNet.toStringAsFixed(0)}', Icons.check_circle_outline, theme, color: Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Pending', '₹${(totalNet - paidNet).toStringAsFixed(0)}', Icons.hourglass_top_outlined, theme, color: Colors.orange),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Staff Member')),
                        DataColumn(label: Text('Period')),
                        DataColumn(label: Text('Base Salary')),
                        DataColumn(label: Text('Allowances')),
                        DataColumn(label: Text('Deductions')),
                        DataColumn(label: Text('Net Salary')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: salaries.map((s) {
                        final isPaid = s.status == 'PAID';
                        final isNotConfigured = !isPaid && s.baseSalary == 0.0 && s.netSalary == 0.0;
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(s.staffCode, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                                ],
                              ),
                            ),
                            DataCell(Text('${s.month}/${s.year}')),
                            DataCell(Text('₹${s.baseSalary.toStringAsFixed(0)}')),
                            DataCell(Text('+₹${s.allowances.toStringAsFixed(0)}')),
                            DataCell(Text('-₹${s.deductions.toStringAsFixed(0)}')),
                            DataCell(Text('₹${s.netSalary.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              isNotConfigured
                                  ? const Chip(
                                      label: Text(
                                        'Not Configured',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: Color(0xFFFEF3C7),
                                      side: BorderSide.none,
                                    )
                                  : Chip(
                                      label: Text(
                                        s.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                      side: BorderSide.none,
                                    ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isPaid) ...[
                                    OutlinedButton(
                                      onPressed: () => _showEditSalaryDialog(context, s),
                                      child: const Text('Edit Salary'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () => _showPaySalaryDialog(context, s),
                                      child: const Text('Record Payment'),
                                    ),
                                  ] else ...[
                                    FilledButton.tonalIcon(
                                      icon: const Icon(Icons.receipt_long, size: 16),
                                      label: const Text('Payment Slip'),
                                      onPressed: () => _showPaymentDetailsDialog(context, s),
                                    ),
                                  ],
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
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, ThemeData theme, {Color? color}) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color ?? theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateSalaries(BuildContext context) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.post(
      '/staff-salaries/generate',
      data: {
        'school_id': schoolId,
        'month': _selectedMonth,
        'year': _selectedYear,
      },
      mapper: (json) => json,
    );

    if (context.mounted) {
      res.when(
        onSuccess: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salaries generated successfully.')),
          );
          ref.invalidate(salariesListProvider);
        },
        onFailure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${err.message}')),
          );
        },
      );
    }
  }

  Future<void> _showEditSalaryDialog(BuildContext context, StaffSalaryItem salary) async {
    final baseCtrl = TextEditingController(text: salary.baseSalary > 0 ? salary.baseSalary.toStringAsFixed(2) : '');
    final allowancesCtrl = TextEditingController(text: salary.allowances > 0 ? salary.allowances.toStringAsFixed(2) : '0');
    final deductionsCtrl = TextEditingController(text: salary.deductions > 0 ? salary.deductions.toStringAsFixed(2) : '0');
    final remarksCtrl = TextEditingController(text: salary.remarks ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final base = double.tryParse(baseCtrl.text.trim()) ?? 0.0;
          final allowances = double.tryParse(allowancesCtrl.text.trim()) ?? 0.0;
          final deductions = double.tryParse(deductionsCtrl.text.trim()) ?? 0.0;
          final net = (base + allowances - deductions).clamp(0.0, double.infinity);

          return AlertDialog(
            title: Text('Edit Salary: ${salary.staffName}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Staff Code: ${salary.staffCode} • Period: ${salary.month}/${salary.year}'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: baseCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Base Salary (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allowancesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Allowances / Bonus (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deductionsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Deductions / PF / Tax (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Calculated Net Salary:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '₹${net.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final parsedBase = double.tryParse(baseCtrl.text.trim()) ?? 0.0;
                  final parsedAllowances = double.tryParse(allowancesCtrl.text.trim()) ?? 0.0;
                  final parsedDeductions = double.tryParse(deductionsCtrl.text.trim()) ?? 0.0;

                  final apiClient = ref.read(apiClientProvider);
                  await apiClient.put(
                    '/staff-salaries/${salary.id}',
                    data: {
                      'base_salary': parsedBase,
                      'allowances': parsedAllowances,
                      'deductions': parsedDeductions,
                      'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                    },
                    mapper: (json) => json,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(salariesListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salary breakdown saved successfully.')),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPaySalaryDialog(BuildContext context, StaffSalaryItem salary) async {
    final refNumCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String paymentMethod = 'BANK_TRANSFER';
    DateTime paymentDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Record Salary Payment: ${salary.staffName}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Period:'),
                            Text('${salary.month}/${salary.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Net Disbursable Amount:'),
                            Text('₹${salary.netSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Marking this salary as PAID will automatically record an approved School Expense linked directly to this payout.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Payment Date: ${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: const Text('Change Date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setDialogState(() => paymentDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS/IMPS)')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('UPI / Online Transfer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Transaction / Cheque Reference #',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Disbursement Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final apiClient = ref.read(apiClientProvider);
                final dateStr = '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
                await apiClient.post(
                  '/staff-salaries/${salary.id}/pay',
                  data: {
                    'payment_method': paymentMethod,
                    'payment_date': dateStr,
                    'reference_number': refNumCtrl.text.trim().isEmpty ? null : refNumCtrl.text.trim(),
                    'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                  },
                  mapper: (json) => json,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(salariesListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Salary disbursement recorded successfully.')),
                  );
                }
              },
              child: const Text('Confirm Disbursement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentDetailsDialog(BuildContext context, StaffSalaryItem salary) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green),
            const SizedBox(width: 8),
            Text('Disbursed Slip: ${salary.staffName}'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Staff Code', salary.staffCode),
              _buildDetailRow('Payroll Period', '${salary.month}/${salary.year}'),
              const Divider(),
              _buildDetailRow('Base Salary', '₹${salary.baseSalary.toStringAsFixed(2)}'),
              _buildDetailRow('Allowances', '+₹${salary.allowances.toStringAsFixed(2)}'),
              _buildDetailRow('Deductions', '-₹${salary.deductions.toStringAsFixed(2)}'),
              const Divider(),
              _buildDetailRow('Net Disbursed', '₹${salary.netSalary.toStringAsFixed(2)}', isBold: true),
              const SizedBox(height: 12),
              _buildDetailRow('Payment Date', salary.paymentDate ?? 'Recorded'),
              _buildDetailRow('Payment Method', salary.paymentMethod ?? 'BANK_TRANSFER'),
              _buildDetailRow('Reference #', salary.referenceNumber ?? 'N/A'),
              if (salary.remarks != null && salary.remarks!.isNotEmpty)
                _buildDetailRow('Remarks', salary.remarks!),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.green.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'School Expense automatically recorded in Accounts',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
