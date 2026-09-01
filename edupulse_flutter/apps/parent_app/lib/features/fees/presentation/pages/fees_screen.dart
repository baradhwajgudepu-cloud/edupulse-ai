import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_files/edupulse_files.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import 'package:parent_app/features/homework/presentation/providers/homework_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final feesScreenDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final apiClient = ref.read(apiClientProvider);

  final ledgerResult = await apiClient.get(
    '/fees/ledgers/$studentId',
    mapper: (json) => json as Map<String, dynamic>,
  );

  final structuresResult = await apiClient.get(
    '/fees/structures',
    mapper: (json) => json as Map<String, dynamic>,
  );

  final ledger = ledgerResult.when(
    onSuccess: (data) => data['data'] as Map<String, dynamic>,
    onFailure: (failure) => throw Exception(failure.message),
  );

  final List structures = structuresResult.when(
    onSuccess: (data) => (data['data'] as List?) ?? [],
    onFailure: (_) => [],
  );

  // Map structure IDs to their descriptive names (e.g. Tuition Fee)
  final Map<String, String> structureNameMap = {};
  for (final s in structures) {
    final id = s['id'] as String?;
    final desc = s['description'] as String? ?? 'Academic Fee';
    if (id != null) {
      structureNameMap[id] = desc;
    }
  }

  return {
    'ledger': ledger,
    'structureNames': structureNameMap,
  };
});

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  // Simulation state
  bool _isProcessingGateway = false;
  double _downloadProgress = 0.0;

  Future<void> _downloadReceipt(String receiptNumber, String schoolId) async {
    setState(() {
      _downloadProgress = 0.0;
    });

    final config = ref.read(buildConfigProvider);
    final session = ref.read(sessionManagerProvider);
    final token = await session.getAccessToken();

    final url = '${config.apiBaseUrl}/fees/receipts/$receiptNumber/download';
    final headers = {
      'Authorization': 'Bearer $token',
      'X-Tenant-ID': config.tenantId,
      'X-School-ID': schoolId,
    };

    final downloadUseCase = ref.read(downloadAttachmentUseCaseProvider);
    final filename = 'EduPulse_Receipt_$receiptNumber.pdf';
    final result = await downloadUseCase(
      url: url,
      filename: filename,
      headers: headers,
      onProgress: (received, total) {
        if (total > 0) {
          setState(() {
            _downloadProgress = received / total;
          });
        }
      },
    );

    result.when(
      onSuccess: (path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt $receiptNumber downloaded successfully'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FileViewer(
                      path: path,
                      title: 'Receipt: $receiptNumber',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${failure.message}')),
        );
      },
    );
  }

  void _triggerPaymentSimulation(
    BuildContext context,
    String studentId,
    String academicYearId,
    String schoolId,
    double outstandingAmount,
    List assignments,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final currencyFormatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Secure Checkout',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'EduPulse Payment Gateway',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount to Pay',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(outstandingAmount),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isProcessingGateway) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    const Text(
                      'Processing payment on gateway...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ] else ...[
                    Text(
                      'Simulate Payment Mode',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setModalState(() {
                          _isProcessingGateway = true;
                        });
                        
                        // Construct allocations dynamically based on outstanding assignments
                        final List<Map<String, dynamic>> allocations = [];
                        double remainingToAllocate = outstandingAmount;
                        for (final a in assignments) {
                          if (remainingToAllocate <= 0) break;
                          final assigned = (a['assigned_amount'] as num?)?.toDouble() ?? 0.0;
                          final discount = (a['discount_amount'] as num?)?.toDouble() ?? 0.0;
                          final paid = (a['paid_amount'] as num?)?.toDouble() ?? 0.0;
                          final balance = assigned - discount - paid;
                          if (balance > 0) {
                            final double allocated = remainingToAllocate > balance ? balance : remainingToAllocate;
                            allocations.add({
                              'assignment_id': a['id'],
                              'amount_allocated': allocated,
                            });
                            remainingToAllocate -= allocated;
                          }
                        }

                        final randomRef = 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        final body = {
                          'student_id': studentId,
                          'academic_year_id': academicYearId,
                          'payment_method': 'ONLINE',
                          'transaction_reference': randomRef,
                          'remarks': 'Paid via parent app payment gateway simulation',
                          'allocations': allocations,
                        };

                        final apiClient = ref.read(apiClientProvider);
                        final result = await apiClient.post(
                          '/fees/payments',
                          data: body,
                          mapper: (json) => json as Map<String, dynamic>,
                        );

                        if (!ctx.mounted) return;
                        setModalState(() {
                          _isProcessingGateway = false;
                        });
                        Navigator.of(ctx).pop(); // Close bottom sheet

                        if (!context.mounted) return;
                        result.when(
                          onSuccess: (resData) {
                            ref.invalidate(feesScreenDataProvider(studentId));
                              
                              final resBody = resData['data'] as Map<String, dynamic>?;
                              final generatedReceipt = resBody?['receipt_number'] as String? ?? 'N/A';

                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Payment Successful'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Transaction Ref: $randomRef'),
                                      const SizedBox(height: 4),
                                      Text('Receipt Number: $generatedReceipt'),
                                      const SizedBox(height: 8),
                                      const Text('The fee ledger has been updated successfully.'),
                                    ],
                                  ),
                                  actions: [
                                    if (generatedReceipt != 'N/A')
                                      TextButton.icon(
                                        icon: const Icon(Icons.download_rounded),
                                        label: const Text('Download Receipt'),
                                        onPressed: () {
                                          Navigator.of(dCtx).pop();
                                          _downloadReceipt(generatedReceipt, schoolId);
                                        },
                                      ),
                                    TextButton(
                                      onPressed: () => Navigator.of(dCtx).pop(),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onFailure: (failure) {
                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.error_outline_rounded, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Payment Failed'),
                                    ],
                                  ),
                                  content: Text(failure.message),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dCtx).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                      },
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Simulate Success (Online Checkout)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.cancel_rounded, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Checkout Cancelled'),
                              ],
                            ),
                            content: const Text('The payment transaction was cancelled by the user.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dCtx).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Simulate Failure / Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    // Get selected student from dashboard state
    String studentId = 'a8bc2968-3d0d-431d-ab06-b90f518a0801';
    String studentName = 'Rahul Sharma';
    final dbState = ref.watch(dashboardStateProvider);
    if (dbState is DashboardSuccess) {
      final selected = dbState.data.selectedStudent;
      if (selected != null) {
        studentId = selected.id;
        studentName = selected.fullName;
      }
    }

    final screenDataAsync = ref.watch(feesScreenDataProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees Ledger'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          if (_downloadProgress > 0.0 && _downloadProgress < 1.0)
            LinearProgressIndicator(value: _downloadProgress),
          Expanded(
            child: screenDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
                SizedBox(height: spacing.md),
                Text(
                  'Failed to load fees details',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        data: (screenData) {
          final ledger = screenData['ledger'] as Map<String, dynamic>;
          final structureNames = screenData['structureNames'] as Map<String, String>;

          final assignments = (ledger['assignments'] as List?) ?? [];
          final payments = (ledger['payments'] as List?) ?? [];
          final closingBalance = (ledger['closing_balance'] as num?)?.toDouble() ?? 0.0;
          final academicYearId = assignments.isNotEmpty ? assignments.first['academic_year_id'] as String : '';
          
          final authState = ref.watch(authStateProvider);
          final schoolId = authState is Authenticated ? (authState.user.schools.firstOrNull ?? '16730f87-bf8d-44e0-acf9-4b055a778b58') : '16730f87-bf8d-44e0-acf9-4b055a778b58';

          if (assignments.isEmpty && payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, size: 64, color: theme.colorScheme.outline),
                  SizedBox(height: spacing.md),
                  Text(
                    'No fee structure assigned',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          double totalAssigned = 0;
          double totalPaid = 0;
          for (final a in assignments) {
            totalAssigned += (a['assigned_amount'] as num?)?.toDouble() ?? 0.0;
            totalPaid += (a['paid_amount'] as num?)?.toDouble() ?? 0.0;
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(feesScreenDataProvider(studentId).future),
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                // Child Context Banner
                Container(
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.face_rounded, color: theme.colorScheme.onSecondaryContainer),
                      SizedBox(width: spacing.sm),
                      Text(
                        'Student: $studentName',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.md),

                // Financial Summary Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Fee Assigned', style: theme.textTheme.bodyMedium),
                            Text(currencyFormatter.format(totalAssigned), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: spacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount Paid', style: theme.textTheme.bodyMedium),
                            Text(
                              currencyFormatter.format(totalPaid),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: spacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Outstanding Balance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              currencyFormatter.format(closingBalance),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: closingBalance > 0 ? theme.colorScheme.error : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.md),

                // Fee Structure Assignments
                Text(
                  'Fee Assignments',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.sm),
                ...assignments.map((a) {
                  final assigned = (a['assigned_amount'] as num?)?.toDouble() ?? 0.0;
                  final paid = (a['paid_amount'] as num?)?.toDouble() ?? 0.0;
                  final discount = (a['discount_amount'] as num?)?.toDouble() ?? 0.0;
                  final status = a['status'] as String? ?? 'UNPAID';
                  
                  final structId = a['fee_structure_id'] as String?;
                  final title = structureNames[structId] ?? 'Academic Fee';

                  return Card(
                    margin: EdgeInsets.only(bottom: spacing.sm),
                    child: ListTile(
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assigned: ${currencyFormatter.format(assigned)}'),
                          if (discount > 0) Text('Discount Concession: ${currencyFormatter.format(discount)}', style: const TextStyle(color: Colors.orange)),
                          Text('Paid: ${currencyFormatter.format(paid)}', style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(status),
                        backgroundColor: status == 'COMPLETED' || status == 'PAID'
                            ? Colors.green.shade100
                            : status == 'PARTIALLY_PAID'
                                ? Colors.orange.shade100
                                : Colors.red.shade100,
                      ),
                    ),
                  );
                }),
                SizedBox(height: spacing.md),

                // Payments list
                if (payments.isNotEmpty) ...[
                  Text(
                    'Payment Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spacing.sm),
                  ...payments.map((p) {
                    final amount = (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
                    final reference = p['transaction_reference'] as String? ?? 'N/A';
                    final dateStr = p['payment_date'] as String? ?? '';
                    final status = p['status'] as String? ?? 'COMPLETED';
                    final method = p['payment_method'] as String? ?? 'ONLINE';
                    final receiptNo = p['receipt_number'] as String? ?? 'N/A';

                    final isCancelled = status == 'CANCELLED';

                    return Card(
                      margin: EdgeInsets.only(bottom: spacing.sm),
                      child: Padding(
                        padding: EdgeInsets.all(spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                                      color: isCancelled ? Colors.red : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ref: $reference',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  currencyFormatter.format(amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCancelled ? Colors.red : Colors.green,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Date: ${formatDate(dateStr)}'),
                            Text('Method: $method'),
                            Text('Status: $status'),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Receipt No: $receiptNo'),
                                if (!isCancelled && receiptNo != 'N/A')
                                  TextButton.icon(
                                    onPressed: () => _downloadReceipt(receiptNo, schoolId),
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text('Receipt'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // Action payment trigger
                if (closingBalance > 0) ...[
                  SizedBox(height: spacing.lg),
                  ElevatedButton.icon(
                    onPressed: () {
                      _triggerPaymentSimulation(
                        context,
                        studentId,
                        academicYearId,
                        schoolId,
                        closingBalance,
                        assignments,
                      );
                    },
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Pay Balance Due'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: spacing.md),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.sm)),
                    ),
                  ),
                ],
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
}
