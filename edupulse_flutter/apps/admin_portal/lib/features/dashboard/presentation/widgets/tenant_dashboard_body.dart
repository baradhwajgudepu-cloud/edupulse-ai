import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../reports/presentation/providers/reports_provider.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TenantDashboardBody extends ConsumerWidget {
  const TenantDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final authState = ref.watch(authStateProvider);
    final overviewAsync = ref.watch(tenantOverviewProvider);

    String adminName = 'Administrator';
    String userRole = 'Tenant Admin / Chairman';
    if (authState is Authenticated) {
      adminName = authState.user.fullName;
      if (authState.user.roles.isNotEmpty) {
        userRole = authState.user.roles.first;
      }
    }

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              SizedBox(height: spacing.sm),
              Text(
                'Failed to load tenant analytics overview',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing.xs),
              Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      data: (data) {
        final tenantName = data['tenant_name'] ?? 'EduPulse Group';
        final totalSchools = data['total_schools'] ?? 0;
        final totalStudents = data['total_students'] ?? 0;
        final totalTeachers = data['total_teachers'] ?? 0;
        final overallAttendance = data['overall_attendance'] ?? 100.0;
        final feeCollection = data['fee_collection_percentage'] ?? 100.0;
        final outstandingFees = data['outstanding_fees'] ?? 0.0;
        final reportCardCompletion = data['report_card_completion_percentage'] ?? 100.0;
        final activeAcademicYear = data['active_academic_year'] ?? 'N/A';
        final List<dynamic> schools = data['schools'] ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Card / Tenant Profile Header
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.lg),
                ),
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(
                          Icons.business,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenantName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome Back, $adminName ($userRole)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.lg),

              // 2. Metrics Grid (8 cards)
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 800 ? 3 : 2),
                crossAxisSpacing: spacing.md,
                mainAxisSpacing: spacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: [
                  _buildMetricCard(
                    context,
                    title: 'Total Schools',
                    value: '$totalSchools',
                    icon: Icons.school,
                    color: Colors.blue,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Total Students',
                    value: '$totalStudents',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Total Teachers',
                    value: '$totalTeachers',
                    icon: Icons.person,
                    color: Colors.orange,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Overall Attendance',
                    value: '${overallAttendance.toStringAsFixed(1)}%',
                    icon: Icons.calendar_today,
                    color: Colors.purple,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Fee Collection',
                    value: '${feeCollection.toStringAsFixed(1)}%',
                    icon: Icons.payment,
                    color: Colors.teal,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Outstanding Fees',
                    value: '₹${outstandingFees.toStringAsFixed(0)}',
                    icon: Icons.money_off,
                    color: Colors.red,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Report Card Status',
                    value: '${reportCardCompletion.toStringAsFixed(1)}%',
                    icon: Icons.assignment,
                    color: Colors.indigo,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Active Year Context',
                    value: activeAcademicYear,
                    icon: Icons.date_range,
                    color: Colors.cyan,
                  ),
                ],
              ),
              SizedBox(height: spacing.xl),

              // 3. School Comparison Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'School Comparison Overview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${schools.length} Schools Registered',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.md),

              // 4. Schools Table Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('School Campus')),
                      DataColumn(label: Text('Students'), numeric: true),
                      DataColumn(label: Text('Teachers'), numeric: true),
                      DataColumn(label: Text('Attendance'), numeric: true),
                      DataColumn(label: Text('Fee Collection'), numeric: true),
                      DataColumn(label: Text('Report Card %'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: schools.map((sch) {
                      final name = sch['school_name'] ?? 'N/A';
                      final std = sch['students_count'] ?? 0;
                      final tch = sch['teachers_count'] ?? 0;
                      final att = sch['attendance_percentage'] ?? 100.0;
                      final fee = sch['fee_collection_percentage'] ?? 100.0;
                      final rc = sch['report_card_completion_percentage'] ?? 100.0;
                      final isActive = sch['is_active'] ?? true;

                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                // Switch context to selected school and reload context-sensitive providers
                                ref.read(selectedSchoolIdProvider.notifier).state = sch['school_id'];
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.launch, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text('$std')),
                          DataCell(Text('$tch')),
                          DataCell(Text('${att.toStringAsFixed(1)}%')),
                          DataCell(Text('${fee.toStringAsFixed(1)}%')),
                          DataCell(Text('${rc.toStringAsFixed(1)}%')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: isActive ? Colors.green[800] : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(radius.sm),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
