import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/fees_provider.dart';

class OutstandingDuesDetailScreen extends ConsumerWidget {
  final String? classId;
  final String className;

  const OutstandingDuesDetailScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(outstandingFeesProvider(classId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/fees');
            }
          },
        ),
        title: Text('$className Outstanding Dues'),
      ),
      body: _buildBody(context, ref, state, spacing, radius, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    OutstandingFeesState state,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              SizedBox(height: spacing.sm),
              const Text('Failed to load outstanding dues.'),
              Text(state.errorMessage!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              SizedBox(height: spacing.md),
              ElevatedButton(
                onPressed: () => ref.read(outstandingFeesProvider(classId).notifier).fetchReport(classId: classId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
            SizedBox(height: spacing.sm),
            const Text('No outstanding dues for this class.'),
          ],
        ),
      );
    }

    // Calculations for summary card
    double totalAssigned = 0.0;
    double totalPaid = 0.0;
    double totalOutstanding = 0.0;

    for (final rec in state.records) {
      totalAssigned += (rec['assigned_amount'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (rec['paid_amount'] as num?)?.toDouble() ?? 0.0;
      totalOutstanding += (rec['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Column(
      children: [
        // Summary Card
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(theme, 'Total Dues', '₹${totalAssigned.toStringAsFixed(0)}', Colors.black87),
                  _buildSummaryItem(theme, 'Paid', '₹${totalPaid.toStringAsFixed(0)}', Colors.green),
                  _buildSummaryItem(theme, 'Outstanding', '₹${totalOutstanding.toStringAsFixed(0)}', theme.colorScheme.error),
                ],
              ),
            ),
          ),
        ),
        
        // List Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Records (${state.records.length})',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
            ],
          ),
        ),
        const Divider(),

        // Records List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(spacing.md),
            itemCount: state.records.length,
            separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
            itemBuilder: (context, index) {
              final rec = state.records[index];
              final studentName = rec['student_name'] as String? ?? 'Student';
              final admNo = rec['admission_number'] as String? ?? '';
              final sectionName = rec['section_name'] as String? ?? '';
              final feeTypeName = rec['fee_type_name'] as String? ?? 'Fee';
              final outstanding = (rec['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
              final paid = (rec['paid_amount'] as num?)?.toDouble() ?? 0.0;
              final assigned = (rec['assigned_amount'] as num?)?.toDouble() ?? 0.0;
              final status = rec['status'] as String? ?? '';
              final dueDateStr = rec['due_date'] as String? ?? '';
              
              String formattedDate = dueDateStr;
              try {
                final parsed = DateTime.parse(dueDateStr);
                formattedDate = DateFormat('dd MMM yyyy').format(parsed);
              } catch (_) {}

              final statusColor = status.toUpperCase() == 'PAID'
                  ? Colors.green
                  : (status.toUpperCase() == 'PARTIALLY_PAID' ? Colors.orange : Colors.red);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.sm),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Adm No: $admNo | Sec: $sectionName',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(radius.xs),
                            ),
                            child: Text(
                              status.replaceAll('_', ' '),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feeTypeName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                'Due by: $formattedDate',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${outstanding.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Paid: ₹${paid.toStringAsFixed(0)} / ₹${assigned.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
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
  }

  Widget _buildSummaryItem(ThemeData theme, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
