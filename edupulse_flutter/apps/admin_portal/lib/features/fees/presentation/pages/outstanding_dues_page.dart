import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';
import '../../data/models/fee_models.dart';
import '../providers/fees_provider.dart';
import '../../../../core/routing/routes.dart';

class OutstandingDuesPage extends ConsumerWidget {
  final String? classId;
  final bool onlyDefaulters;

  const OutstandingDuesPage({
    super.key,
    this.classId,
    this.onlyDefaulters = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final schoolId = ref.watch(selectedSchoolIdProvider) ?? '';
    
    final params = OutstandingReportParams(
      schoolId: schoolId,
      classId: classId,
      onlyDefaulters: onlyDefaulters,
    );
    
    final reportState = ref.watch(outstandingReportProvider(params));

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd MMM yyyy');

    String pageTitle = onlyDefaulters ? 'Late Defaulters' : 'Outstanding Dues';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Stats & Filter Status
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Row(
                  children: [
                    Icon(
                      onlyDefaulters ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                      color: onlyDefaulters ? theme.colorScheme.error : theme.colorScheme.primary,
                      size: 28,
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            onlyDefaulters 
                              ? 'Viewing students with overdue unpaid fees'
                              : 'Viewing all outstanding student fee balances',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (classId != null && classId!.isNotEmpty) ...[
                            SizedBox(height: spacing.xs),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(radius.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Filtered by Class',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Report',
                      onPressed: () => ref.refresh(outstandingReportProvider(params)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),

            // Content Area
            Expanded(
              child: Builder(
                builder: (context) {
                  if (reportState.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (reportState.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          SizedBox(height: spacing.md),
                          Text(
                            'Failed to load report: ${reportState.error}',
                            style: theme.textTheme.titleMedium,
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton(
                            onPressed: () => ref.refresh(outstandingReportProvider(params)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = reportState.items;
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.secondary),
                          SizedBox(height: spacing.md),
                          Text(
                            'No outstanding dues found.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Responsive Table
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.md),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius.md),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            ),
                            columns: const [
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Admission No')),
                              DataColumn(label: Text('Class & Section')),
                              DataColumn(label: Text('Fee Type')),
                              DataColumn(label: Text('Assigned Amount')),
                              DataColumn(label: Text('Concession')),
                              DataColumn(label: Text('Fine')),
                              DataColumn(label: Text('Paid')),
                              DataColumn(label: Text('Outstanding')),
                              DataColumn(label: Text('Due Date')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      item.studentName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(item.admissionNumber)),
                                  DataCell(Text('${item.className} - ${item.sectionName}')),
                                  DataCell(Text(item.feeTypeName)),
                                  DataCell(Text(currencyFormatter.format(item.assignedAmount))),
                                  DataCell(Text(currencyFormatter.format(item.discountAmount))),
                                  DataCell(Text(currencyFormatter.format(item.fineAmount))),
                                  DataCell(Text(currencyFormatter.format(item.paidAmount))),
                                  DataCell(
                                    Text(
                                      currencyFormatter.format(item.outstandingAmount),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: onlyDefaulters ? theme.colorScheme.error : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(dateFormatter.format(item.dueDate))),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(item.status, theme).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(radius.sm),
                                      ),
                                      child: Text(
                                        item.status,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: _getStatusColor(item.status, theme),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    TextButton.icon(
                                      icon: const Icon(Icons.arrow_forward, size: 16),
                                      label: const Text('View Ledger'),
                                      onPressed: () {
                                        // Construct lightweight StudentDto for ledger navigation
                                        final studentDto = StudentDto.forLedger(
                                          id: item.studentId,
                                          firstName: item.studentName.split(' ').first,
                                          lastName: item.studentName.split(' ').skip(1).join(' '),
                                          admissionNumber: item.admissionNumber,
                                        );
                                        context.push(AppRoutes.feesLedger, extra: studentDto);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return theme.colorScheme.secondary;
      case 'PARTIALLY_PAID':
        return Colors.orange;
      case 'UNPAID':
      default:
        return theme.colorScheme.error;
    }
  }
}
