import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../providers/dashboard_provider.dart';

class DashboardCards extends StatelessWidget {
  final ParentDashboardData data;

  const DashboardCards({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final selected = data.selectedStudent;
    final totalFees = data.totalFees;
    final hasPendingFees = data.pendingFees > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Student Profile Card (Top Card)
        if (selected != null)
          Card(
            elevation: 2,
            color: theme.colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      selected.firstName.isNotEmpty ? selected.firstName.substring(0, 1).toUpperCase() : 'S',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          'Class Info: ${selected.className} - ${selected.sectionName.replaceAll('Section ', '')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          'Admission No: ${selected.admissionNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: spacing.md),

        // 2. Fees Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius.md),
            onTap: () => context.push(AppRoutes.payFees),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: spacing.sm),
                      Text(
                        'Fees & Payments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  if (!hasPendingFees)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.sm),
                      child: Center(
                        child: Text(
                          'No pending fees',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeeDetail(
                          context: context,
                          label: 'Total Fees',
                          value: currencyFormatter.format(totalFees),
                        ),
                        _buildFeeDetail(
                          context: context,
                          label: 'Paid',
                          value: currencyFormatter.format(data.paidFees),
                          valueColor: Colors.green,
                        ),
                        _buildFeeDetail(
                          context: context,
                          label: 'Pending',
                          value: currencyFormatter.format(data.pendingFees),
                          valueColor: theme.colorScheme.error,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(AppRoutes.payFees);
                        },
                        icon: const Icon(Icons.payment_rounded),
                        label: const Text('Pay Fees'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // 3. 2x2 Grid for Other Cards
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: spacing.md,
          mainAxisSpacing: spacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            // Attendance Card
            _buildParentCard(
              context: context,
              title: 'Attendance Summary',
              icon: Icons.fact_check_rounded,
              color: Colors.teal,
              onTap: () => context.push(AppRoutes.attendance),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.attendancePercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Present: ${data.presentCount} | Absent: ${data.absentCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Homework Card
            _buildParentCard(
              context: context,
              title: 'Homework Overview',
              icon: Icons.menu_book_rounded,
              color: Colors.orange,
              onTap: () => context.push(AppRoutes.homework),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.pendingHomeworkCount} Pending',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Due assignments',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Exam Card
            _buildParentCard(
              context: context,
              title: 'Exams & Results',
              icon: Icons.assessment_rounded,
              color: Colors.blue,
              onTap: () => context.push(AppRoutes.exams),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.upcomingExam,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    data.latestResult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Announcements Card
            _buildParentCard(
              context: context,
              title: 'Announcements',
              icon: Icons.notifications_active_rounded,
              color: Colors.purple,
              onTap: () => context.push(AppRoutes.announcements),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.latestNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeeDetail({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildParentCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
