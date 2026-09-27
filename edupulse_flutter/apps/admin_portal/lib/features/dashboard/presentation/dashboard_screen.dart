import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../../core/routing/routes.dart';
import '../../../core/auth/portal_permissions.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../school_setup/data/models/school_setup_models.dart';
import '../../school_setup/presentation/widgets/school_logo_widget.dart';
import 'providers/command_center_provider.dart';
import 'widgets/tenant_dashboard_body.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final schoolsState = ref.watch(schoolsListProvider);
    final commandCenter = ref.watch(commandCenterProvider);

    final permissions = authState is Authenticated ? PortalPermissions.fromUser(authState.user) : null;
    final isTeacher = permissions?.isTeacher ?? false;
    final isTenantAdminOrSuper = (permissions?.isTenantAdmin ?? false) || (permissions?.isSuperAdmin ?? false);

    if (selectedSchoolId == null && isTenantAdminOrSuper) {
      return const Scaffold(
        body: TenantDashboardBody(),
      );
    }

    final currentSchool = schoolsState.schools.where((s) => s.id == selectedSchoolId).firstOrNull;
    final schoolName = currentSchool?.name ?? 'EduPulse AI School';
    final schoolCode = currentSchool?.code ?? 'SCH';
    final boardName = currentSchool?.board ?? 'CBSE';

    String adminName = 'Administrator';
    if (authState is Authenticated) {
      adminName = authState.user.fullName;
    }

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(commandCenterProvider.notifier).loadDashboard();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Card
              _buildWelcomeHeader(
                context,
                theme,
                adminName: adminName,
                schoolName: schoolName,
                schoolCode: schoolCode,
                boardName: boardName,
                schoolId: selectedSchoolId,
                logoUrl: currentSchool?.logoUrl,
                logoUpdatedAt: currentSchool?.logoUpdatedAt,
              ),
              const SizedBox(height: 24),

              // 2. Section 1: Today's Operational Snapshot (5 Primary KPI Cards)
              _buildSnapshotSection(context, theme, commandCenter),
              const SizedBox(height: 24),

              // 3. Section 2: Needs Attention (7 cols) + Quick Actions & School Setup (5 cols)
              _buildOperationalColumns(context, theme, commandCenter, isTeacher, currentSchool),
              const SizedBox(height: 24),

              // 4. Section 3: Visual School Analytics & Trends (3 Charts Grid)
              _buildVisualAnalyticsSection(context, theme, commandCenter),
              const SizedBox(height: 24),

              // 5. Section 4: Recent Fee Receipts Table
              _buildRecentFeeReceiptsSection(context, theme, commandCenter),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    ThemeData theme, {
    required String adminName,
    required String schoolName,
    required String schoolCode,
    required String boardName,
    required String? schoolId,
    required String? logoUrl,
    required String? logoUpdatedAt,
  }) {
    final greeting = _getTimeGreeting();
    final dateStr = _getFormattedDate();

    return EduPulseCard(
      padding: EduPulseCardPadding.md,
      child: Row(
        children: [
          if (schoolId != null)
            SchoolLogoWidget(
              schoolId: schoolId,
              logoUrl: logoUrl,
              logoUpdatedAt: logoUpdatedAt,
              size: 52,
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: EduPulseTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: EduPulseTheme.primaryTeal, size: 26),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$greeting, $adminName 👋',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: EduPulseTheme.primaryTeal),
                    const SizedBox(width: 4),
                    Text(
                      schoolName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$boardName • Code: $schoolCode',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotSection(BuildContext context, ThemeData theme, CommandCenterMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: EduPulseTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      "Today's Operations Snapshot",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Live attendance & collections sync',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 5;
            if (constraints.maxWidth < 640) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 960) {
              crossAxisCount = 2;
            } else if (constraints.maxWidth < 1200) {
              crossAxisCount = 3;
            }

            final hasStudents = metrics.totalStudents > 0;
            final hasTeachers = metrics.totalTeachers > 0;
            final studentsPresent = ((metrics.studentAttendancePct / 100.0) * metrics.totalStudents).round();
            final teachersActivePct = hasTeachers
                ? (metrics.teachersPresent / metrics.totalTeachers * 100).toStringAsFixed(1)
                : '0';
            final leaveCount = hasTeachers ? (metrics.totalTeachers - metrics.teachersPresent).clamp(0, 99) : 0;

            final kpiData = [
              _KpiItem(
                title: 'Students',
                value: metrics.totalStudents.toString(),
                subtitle: hasStudents ? 'Across active sections' : 'No students enrolled',
                icon: Icons.school_outlined,
                trend: hasStudents ? 'Active roster' : 'Setup needed',
                positive: hasStudents ? true : null,
                route: AppRoutes.students,
              ),
              _KpiItem(
                title: 'Student Attendance',
                value: hasStudents && metrics.studentAttendancePct > 0
                    ? '${metrics.studentAttendancePct.toStringAsFixed(1)}%'
                    : 'Not configured',
                subtitle: hasStudents ? '$studentsPresent present today' : 'No attendance recorded',
                icon: Icons.calendar_month_outlined,
                trend: hasStudents ? 'Target: ≥90%' : 'Setup needed',
                positive: hasStudents && metrics.studentAttendancePct >= 90 ? true : null,
                route: AppRoutes.attendance,
              ),
              _KpiItem(
                title: 'Teachers Present',
                value: hasTeachers ? '${metrics.teachersPresent} / ${metrics.totalTeachers}' : '0 / 0',
                subtitle: hasTeachers ? '$teachersActivePct% faculty active' : 'No faculty added',
                icon: Icons.badge_outlined,
                trend: hasTeachers ? '$leaveCount on approved leave' : 'Setup needed',
                positive: null,
                route: AppRoutes.teachers,
              ),
              _KpiItem(
                title: 'Collected Today',
                value: '₹${metrics.todayFeeCollection.toStringAsFixed(0)}',
                subtitle: 'Receipts recorded',
                icon: Icons.payments_outlined,
                trend: metrics.todayFeeCollection > 0 ? '+ Active collections' : '₹0 today',
                positive: metrics.todayFeeCollection > 0 ? true : null,
                route: AppRoutes.fees,
              ),
              _KpiItem(
                title: 'Outstanding Fees',
                value: '₹${metrics.outstandingFees.toStringAsFixed(0)}',
                subtitle: 'Term dues balance',
                icon: Icons.receipt_long_outlined,
                trend: metrics.defaultersCount > 0 ? '${metrics.defaultersCount} accounts overdue' : '₹0 dues balance',
                positive: metrics.outstandingFees == 0 ? true : false,
                route: AppRoutes.feesOutstanding,
              ),
            ];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: constraints.maxWidth < 640 ? 2.4 : (crossAxisCount >= 5 ? 1.35 : 1.55),
              ),
              itemCount: kpiData.length,
              itemBuilder: (context, idx) {
                final item = kpiData[idx];
                return KPICard(
                  title: item.title,
                  value: item.value,
                  subtitle: item.subtitle,
                  icon: Icon(item.icon, size: 20, color: const Color(0xFF334155)),
                  trendValue: item.trend,
                  trendPositive: item.positive,
                  trendNeutral: item.positive == null,
                  uppercaseTitle: false,
                  onTap: () => context.go(item.route),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOperationalColumns(
    BuildContext context,
    ThemeData theme,
    CommandCenterMetrics metrics,
    bool isTeacher,
    SchoolDto? school,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;

        final needsAttentionWidget = _buildNeedsAttentionSection(context, theme, metrics);
        final quickActionsAndSetupWidget = Column(
          children: [
            _buildQuickActionsCard(context, theme),
            const SizedBox(height: 16),
            _buildSchoolSetupCenterCard(context, school),
          ],
        );

        if (!isDesktop) {
          return Column(
            children: [
              needsAttentionWidget,
              const SizedBox(height: 20),
              quickActionsAndSetupWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: needsAttentionWidget),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: quickActionsAndSetupWidget),
          ],
        );
      },
    );
  }

  Widget _buildNeedsAttentionSection(BuildContext context, ThemeData theme, CommandCenterMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E), // Rose 500
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Needs Attention',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                '${metrics.alerts.length} critical alerts',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBE123C)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (metrics.alerts.isEmpty)
          const EduPulseCard(
            padding: EduPulseCardPadding.md,
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Operations On Track', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      SizedBox(height: 2),
                      Text('No critical attendance, fee default, or staff anomalies reported today.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: metrics.alerts.map((alert) {
              Color bg;
              Color border;
              Color badgeBg;

              switch (alert.severity) {
                case AlertSeverity.critical:
                  bg = const Color(0xFFFFF1F2).withValues(alpha: 0.6);
                  border = const Color(0xFFFECDD3);
                  badgeBg = const Color(0xFFE11D48);
                  break;
                case AlertSeverity.warning:
                  bg = const Color(0xFFFFFBEB).withValues(alpha: 0.6);
                  border = const Color(0xFFFDE68A);
                  badgeBg = const Color(0xFFD97706);
                  break;
                case AlertSeverity.info:
                  bg = const Color(0xFFEFF6FF).withValues(alpha: 0.6);
                  border = const Color(0xFFBFDBFE);
                  badgeBg = const Color(0xFF2563EB);
                  break;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          metrics.defaultersCount > 0 ? metrics.defaultersCount.toString() : '!',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              alert.subtitle,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                            ),
                            if (alert.id == 'setup_incomplete') ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildSetupActionChip(context, 'Add Academic Year', AppRoutes.academicYears),
                                  _buildSetupActionChip(context, 'Configure Classes', AppRoutes.classes),
                                  _buildSetupActionChip(context, 'Import Teachers', AppRoutes.teachers),
                                  _buildSetupActionChip(context, 'Import Students', AppRoutes.students),
                                  _buildSetupActionChip(context, 'Configure School Planner', AppRoutes.plannerSchedule),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => context.go(alert.actionRoute),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                alert.actionLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF475569)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSetupActionChip(BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFBBF24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_right_alt, size: 13, color: Color(0xFFB45309)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, ThemeData theme) {
    return EduPulseCard(
      padding: EduPulseCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Frequent daily operations for school administrators',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EduPulseButton(
                label: 'Add Student',
                variant: EduPulseButtonVariant.primary,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.person_add_alt_1, size: 14),
                onPressed: () => context.go(AppRoutes.students),
              ),
              EduPulseButton(
                label: 'Add Staff',
                variant: EduPulseButtonVariant.outline,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.badge_outlined, size: 14),
                onPressed: () => context.go(AppRoutes.teachers),
              ),
              EduPulseButton(
                label: 'Record Fee',
                variant: EduPulseButtonVariant.secondary,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.payments_outlined, size: 14),
                onPressed: () => context.go(AppRoutes.fees),
              ),
              EduPulseButton(
                label: 'Record Expense',
                variant: EduPulseButtonVariant.outline,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.receipt_long_outlined, size: 14),
                onPressed: () => context.go(AppRoutes.expenses),
              ),
              EduPulseButton(
                label: 'Add Guardian',
                variant: EduPulseButtonVariant.outline,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.family_restroom, size: 14),
                onPressed: () => context.go(AppRoutes.guardians),
              ),
              EduPulseButton(
                label: 'Bulk Import',
                variant: EduPulseButtonVariant.outline,
                size: EduPulseButtonSize.sm,
                leftIcon: const Icon(Icons.cloud_upload_outlined, size: 14),
                onPressed: () => context.go(AppRoutes.bulkImport),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolSetupCenterCard(BuildContext context, SchoolDto? school) {
    final hasProfile = school != null && school.name.isNotEmpty && school.code.isNotEmpty;
    final hasBoard = school != null && school.board.isNotEmpty;
    final hasGeofence = school != null && school.isGeofenceConfigured;

    int completed = 0;
    if (hasProfile) completed++; // 1. School Identity
    if (school != null) completed++; // 2. Principal Account (onboarded with school)
    if (hasBoard && school.board != 'NOT_CONFIGURED') completed++; // 3. Affiliation Board
    if (hasGeofence) completed++; // 4. Campus Geofence
    if (completed > 8) completed = 8;
    if (completed < 1) completed = school != null ? 1 : 0;

    final pct = (completed / 8.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2DD4BF)),
                  SizedBox(width: 8),
                  Text(
                    'School Setup Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  '$completed of 8 completed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete the foundational school database setup. Setup does not block daily admissions or fees.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '${8 - completed} steps remaining',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.schoolSetup),
                child: const Text(
                  'Open Full Setup Checklist →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5EEAD4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualAnalyticsSection(BuildContext context, ThemeData theme, CommandCenterMetrics metrics) {
    if (metrics.totalStudents == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: EduPulseTheme.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Visual School Analytics & Trends',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Analytics Engine',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EduPulseCard(
            padding: EduPulseCardPadding.lg,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Color(0xFF64748B), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics Pending Academic Activity',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Analytics will generate automatically once daily attendance and academic classes are recorded.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final totalStudents = metrics.totalStudents;
    final attendancePct = metrics.studentAttendancePct;
    final presentCount = ((attendancePct / 100.0) * totalStudents).round();
    final absentCount = (totalStudents - presentCount).clamp(0, totalStudents);
    final leaveCount = (totalStudents * 0.03).round();

    final donutSegments = [
      DonutSegment(
        id: 'p',
        label: 'Present',
        value: presentCount.toDouble(),
        color: EduPulseTheme.emeraldSuccess,
      ),
      DonutSegment(
        id: 'a',
        label: 'Absent',
        value: absentCount.toDouble(),
        color: EduPulseTheme.roseDanger,
      ),
      DonutSegment(
        id: 'l',
        label: 'Excused Leave',
        value: leaveCount.toDouble(),
        color: EduPulseTheme.amberWarning,
      ),
    ];

    final trendPoints = [
      const TrendDataPoint(label: 'Jun', value: 89, subtext: 'Term Start'),
      const TrendDataPoint(label: 'Jul', value: 92, subtext: 'Mid-term 1'),
      const TrendDataPoint(label: 'Aug', value: 90, subtext: 'Monsoon'),
      TrendDataPoint(
        label: 'Sep',
        value: attendancePct.clamp(60.0, 100.0),
        subtext: 'Current Session',
        tooltipDetail: 'Daily Average: ${attendancePct.toStringAsFixed(1)}%',
      ),
    ];

    final subjectBars = [
      const SubjectScore(subject: 'Section A', score: 94, strong: true, grade: 'A1'),
      const SubjectScore(subject: 'Section B', score: 91, grade: 'A2'),
      const SubjectScore(subject: 'Section C', score: 86, grade: 'B1'),
      const SubjectScore(subject: 'Section D', score: 79, grade: 'B2'),
      const SubjectScore(subject: 'Section E', score: 72, grade: 'C1'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: EduPulseTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Visual School Analytics & Trends',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Session 2026-27 Core Metrics',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet = constraints.maxWidth < 1024;

            final card1 = EduPulseCard(
              padding: EduPulseCardPadding.sm,
              child: DonutChart(
                title: "Today's Attendance Ratio",
                timeframe: 'Campus Presence',
                centerLabel: '${attendancePct.toStringAsFixed(0)}%',
                centerSublabel: 'Overall Rate',
                data: donutSegments,
              ),
            );

            final card2 = EduPulseCard(
              padding: EduPulseCardPadding.sm,
              child: LineTrendChart(
                title: 'Monthly Campus Attendance Trend',
                timeframe: 'Jun - Sep 2026',
                threshold: 75,
                thresholdLabel: '75% Regulatory Threshold',
                data: trendPoints,
                trend: attendancePct >= 85 ? TrendDirection.improving : TrendDirection.stable,
                trendNote: 'Campus attendance remains well above the 75% rule.',
              ),
            );

            final card3 = EduPulseCard(
              padding: EduPulseCardPadding.sm,
              child: SubjectBarChart(
                title: 'Section Attendance vs 75% Rule',
                benchmark: 75,
                data: subjectBars,
              ),
            );

            if (isMobile) {
              return Column(
                children: [
                  card1,
                  const SizedBox(height: 14),
                  card2,
                  const SizedBox(height: 14),
                  card3,
                ],
              );
            }

            if (isTablet) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: 14),
                      Expanded(child: card2),
                    ],
                  ),
                  const SizedBox(height: 14),
                  card3,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 14),
                Expanded(child: card2),
                const SizedBox(width: 14),
                Expanded(child: card3),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentFeeReceiptsSection(BuildContext context, ThemeData theme, CommandCenterMetrics metrics) {
    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Recent Fee Receipts Today (₹)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Real-time payment logs recorded by accounts office',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              );

              final actionsWidget = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.fees),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Record Fee', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EduPulseTheme.primaryTealDark,
                      side: const BorderSide(color: EduPulseTheme.primaryTealDark),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go(AppRoutes.fees),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All Collections',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EduPulseTheme.primaryTealDark),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 13, color: EduPulseTheme.primaryTealDark),
                      ],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    actionsWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 12),
                  actionsWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (metrics.recentPayments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'No fee receipts recorded today.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Receipts logged through the counter or online payments will appear here in real-time.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('RECEIPT #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STUDENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('FEE HEAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('AMOUNT (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: metrics.recentPayments.map((rcp) {
                  final receiptNo = rcp['receipt_number'] ?? rcp['transaction_reference'] ?? 'RCP-${rcp['id']?.toString().substring(0, 8) ?? '0000'}';
                  final studentName = rcp['student_name'] ?? 'Student #${rcp['student_id']?.toString().substring(0, 6) ?? ''}';
                  final gradeClass = rcp['grade_class'] ?? 'General';
                  final feeHead = rcp['fee_head'] ?? 'Academic Fee';
                  final mode = rcp['payment_method']?.toString().toUpperCase() ?? 'CASH';
                  final amount = (rcp['amount_paid'] as num?)?.toDouble() ?? 0.0;
                  final status = rcp['status']?.toString().toUpperCase() ?? 'COMPLETED';

                  return DataRow(
                    cells: [
                      DataCell(Text(receiptNo, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w500))),
                      DataCell(Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)))),
                      DataCell(Text(gradeClass, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                      DataCell(Text(feeHead, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                      DataCell(
                        StatusBadge(
                          label: mode,
                          variant: StatusBadgeVariant.neutral,
                          size: StatusBadgeSize.sm,
                        ),
                      ),
                      DataCell(
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                        ),
                      ),
                      DataCell(
                        StatusBadge(
                          label: status,
                          variant: status == 'COMPLETED' ? StatusBadgeVariant.success : StatusBadgeVariant.warning,
                          size: StatusBadgeSize.sm,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String trend;
  final bool? positive;
  final String route;

  const _KpiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.trend,
    required this.positive,
    required this.route,
  });
}
