import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:principal_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:principal_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:principal_app/features/dashboard/presentation/providers/active_school_provider.dart';
import 'package:principal_app/core/router/routes.dart';
import 'package:principal_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:principal_app/features/staff_attendance/presentation/providers/staff_attendance_provider.dart';
import 'package:principal_app/features/leave_requests/presentation/providers/leave_requests_provider.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else {
      final formatter = NumberFormat('#,##,###');
      return '₹${formatter.format(amount.toInt())}';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final schoolId = await ref.read(sessionManagerProvider).getSchoolId();
      if (mounted) {
        ref.read(activeSchoolIdProvider.notifier).state = schoolId;
      }
      ref.read(dashboardStateProvider.notifier).fetchSummary();
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
      ref.read(staffAttendanceStateProvider.notifier).fetchAttendance();
      ref.read(leaveRequestsStateProvider.notifier).fetchRequests();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(dashboardStateProvider.notifier).fetchSummary(isRefresh: true);
    await ref.read(notificationsStateProvider.notifier).fetchNotifications(isRefresh: true);
    await ref.read(staffAttendanceStateProvider.notifier).fetchAttendance(isRefresh: true);
    await ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isRefresh: true);
  }

  String getSchoolName(String schoolId) {
    final authState = ref.read(authStateProvider);
    if (authState is Authenticated) {
      final name = authState.user.schoolNames[schoolId];
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return 'School: $schoolId';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSkeletonLoader(BuildContext context, {required double height}) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildSectionErrorCard(BuildContext context, {required String title, required String message}) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Unauthenticated) {
        context.go(AppRoutes.login);
      }
    });

    final authState = ref.watch(authStateProvider);
    final dashboardState = ref.watch(dashboardStateProvider);
    final activeSchoolId = ref.watch(activeSchoolIdProvider);

    String welcomeText = 'Good Morning, Principal';
    String userRole = 'Principal Portal';
    if (authState is Authenticated) {
      welcomeText = 'Welcome, ${authState.user.fullName}';
      if (authState.user.isSuperuser) {
        userRole = 'System Administrator (Bypassing RBAC)';
      }
    }

    final schoolName = activeSchoolId != null ? getSchoolName(activeSchoolId) : 'Loading School Context...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Leadership Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_rounded),
            tooltip: 'Parent Queries (Connect)',
            onPressed: () => context.push(AppRoutes.communication),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer(
              builder: (context, ref, child) {
                final notifState = ref.watch(notificationsStateProvider);
                int unreadCount = 0;
                if (notifState is NotificationsSuccess) {
                  unreadCount = notifState.unreadCount;
                }
                return Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount.toString()),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome & School Context Card
              Card(
                color: theme.colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.onPrimary,
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              welcomeText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              userRole,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              schoolName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
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

              // ==========================================
              // FINANCIAL SNAPSHOT SECTION
              // ==========================================
              Text(
                'Financial Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: spacing.sm),

              if (dashboardState is DashboardInitial || dashboardState is DashboardLoading) ...[
                _buildSkeletonLoader(context, height: 160),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardError) ...[
                _buildSectionErrorCard(context, title: 'Fees & Collections Error', message: dashboardState.message),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardSuccess) ...[
                if (dashboardState.data.feeError != null) ...[
                  _buildSectionErrorCard(context, title: 'Fee Analytics Restricted', message: dashboardState.data.feeError!),
                  SizedBox(height: spacing.md),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Today\'s Fees',
                          value: '₹${dashboardState.data.todayCollection.toStringAsFixed(0)}',
                          icon: Icons.currency_rupee_rounded,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Collection Rate',
                          value: '${dashboardState.data.collectionPercentage.toStringAsFixed(1)}%',
                          icon: Icons.percent_rounded,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Month Fees',
                          value: _formatCurrency(dashboardState.data.monthCollection),
                          icon: Icons.calendar_month_rounded,
                          color: theme.colorScheme.primary,
                          onTap: () => context.go(AppRoutes.fees),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Dues Pending',
                          value: _formatCurrency(dashboardState.data.pendingDues),
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red,
                          onTap: () => context.go(AppRoutes.fees),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),

                  // Collection & Defaulters Detail
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.md),
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
                              Text(
                                'Defaulters & Classes',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Defaulters: ${dashboardState.data.defaultersCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.sm),
                          if (dashboardState.data.topOutstandingClasses.isEmpty)
                            const Text(
                              'No outstanding class dues returned.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            )
                          else ...[
                            const Text(
                              'Top Outstanding Classes:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: spacing.xs),
                            ...dashboardState.data.topOutstandingClasses.map((item) {
                              final className = item['class_name']?.toString() ?? 'Class';
                              final outstandingAmount = (item['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(className, style: const TextStyle(fontSize: 12)),
                                    Text(
                                      '₹${outstandingAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          SizedBox(height: spacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => context.go(AppRoutes.fees),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('View Fee Analytics', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                ],
              ],

              // ==========================================
              // ACTION REQUIRED (ALERTS) SECTION
              // ==========================================
              Text(
                'Action Required',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: spacing.sm),

              if (dashboardState is DashboardInitial || dashboardState is DashboardLoading) ...[
                _buildSkeletonLoader(context, height: 120),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardError) ...[
                _buildSectionErrorCard(context, title: 'Alerts Error', message: dashboardState.message),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardSuccess) ...[
                if (dashboardState.data.notificationsError != null) ...[
                  _buildSectionErrorCard(context, title: 'Alerts Restricted', message: dashboardState.data.notificationsError!),
                  SizedBox(height: spacing.md),
                ] else ...[
                  Consumer(
                    builder: (context, ref, child) {
                      final leaveState = ref.watch(leaveRequestsStateProvider);
                      final pendingLeaves = leaveState.requests
                          .where((r) => r.status.toUpperCase() == 'PENDING')
                          .toList();

                      if (dashboardState.data.urgentNotifications.isEmpty &&
                          dashboardState.data.highPriorityNotifications.isEmpty &&
                          pendingLeaves.isEmpty) {
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius.md),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: const Center(
                              child: Text(
                                'No critical alerts requiring action.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pendingLeaves.isNotEmpty) ...[
                              _buildTeacherLeaveAlertCard(context, pendingLeaves.length),
                              SizedBox(height: spacing.sm),
                            ],
                            ...dashboardState.data.urgentNotifications.map((notif) => _buildAlertCard(context, notif, isUrgent: true)),
                            ...dashboardState.data.highPriorityNotifications.map((notif) => _buildAlertCard(context, notif, isUrgent: false)),
                          ],
                        );
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),
                ],
              ],

              // ==========================================
              // TODAY'S SNAPSHOT
              // ==========================================
              Text(
                'Today\'s Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: spacing.sm),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
                        child: const Icon(Icons.co_present_rounded, color: Colors.deepOrange),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Attendance',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Mark records, track class lists, and publish logs.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => context.go(AppRoutes.analytics),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.blue),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Staff Attendance",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final staffState = ref.watch(staffAttendanceStateProvider);
                                if (staffState.isLoading) {
                                  return const Text('Loading staff attendance summary...', style: TextStyle(fontSize: 12));
                                } else if (staffState.errorMessage != null) {
                                  return Text('Error loading summary', style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
                                } else if (staffState.summary != null) {
                                  final summary = staffState.summary!;
                                  return Text(
                                    '${summary.totalTeachers} Staff | ${summary.presentCount + summary.lateCount + summary.halfDayCount} Present | ${summary.onLeaveCount} Leave | ${summary.absentCount} Absent',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                }
                                return const Text('No records fetched for today.', style: TextStyle(fontSize: 12));
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => context.push(AppRoutes.teacherAttendance),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // ==========================================
              // ACADEMIC SNAPSHOT SECTION
              // ==========================================
              Text(
                'Academic Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: spacing.sm),

              if (dashboardState is DashboardInitial || dashboardState is DashboardLoading) ...[
                _buildSkeletonLoader(context, height: 120),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardError) ...[
                _buildSectionErrorCard(context, title: 'Academic Schedule Error', message: dashboardState.message),
                SizedBox(height: spacing.md),
              ] else if (dashboardState is DashboardSuccess) ...[
                if (dashboardState.data.academicsError != null) ...[
                  _buildSectionErrorCard(context, title: 'Academics Restricted', message: dashboardState.data.academicsError!),
                  SizedBox(height: spacing.md),
                ] else ...[
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.md),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Examinations:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: spacing.sm),
                          if (dashboardState.data.upcomingExaminations.isEmpty)
                            const Text(
                              'No upcoming examinations scheduled.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            )
                          else
                            ...dashboardState.data.upcomingExaminations.take(3).map((exam) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Container(
                                  padding: EdgeInsets.all(spacing.sm),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(radius.sm),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              exam.examName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              exam.examType,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacing.xs),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            '${_formatDate(exam.startDate)} to ${_formatDate(exam.endDate)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      if (exam.schedules.isNotEmpty) ...[
                                        SizedBox(height: spacing.xs),
                                        Text(
                                          'Schedules: ${exam.schedules.map((s) => s.subjectId).join(", ")}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          SizedBox(height: spacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => context.go(AppRoutes.analytics),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('View Academic Analytics', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                ],
              ],

              // ==========================================
              // KEY OPERATIONS GRID
              // ==========================================
              Text(
                'Key Operations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: spacing.sm),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: spacing.sm,
                mainAxisSpacing: spacing.sm,
                childAspectRatio: 1.4,
                children: [
                  _buildQuickActionCard(
                    context,
                    title: 'Student Directory',
                    subtitle: 'Browse student records',
                    icon: Icons.people_alt_rounded,
                    color: Colors.blue,
                    onTap: () => context.go(AppRoutes.students),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'Teacher Directory',
                    subtitle: 'Browse teacher profiles',
                    icon: Icons.badge_rounded,
                    color: Colors.orange,
                    onTap: () => context.go(AppRoutes.teachers),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'Fees & AI Analytics',
                    subtitle: 'Predictions & trends',
                    icon: Icons.analytics_rounded,
                    color: Colors.teal,
                    onTap: () => context.go(AppRoutes.fees),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'Notification Center',
                    subtitle: 'School broadcasts',
                    icon: Icons.campaign_rounded,
                    color: Colors.indigo,
                    onTap: () => context.go(AppRoutes.notifications),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'Academic & Attendance',
                    subtitle: 'Operations snapshot',
                    icon: Icons.pie_chart_rounded,
                    color: Colors.deepOrange,
                    onTap: () => context.go(AppRoutes.analytics),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'Report Cards',
                    subtitle: 'Approve & lock reviews',
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.purple,
                    onTap: () => context.go(AppRoutes.reportCards),
                  ),
                  _buildQuickActionCard(
                    context,
                    title: 'School Planner',
                    subtitle: 'Calendar, Events & Alerts',
                    icon: Icons.calendar_today_rounded,
                    color: Colors.pink,
                    onTap: () => context.go(AppRoutes.planner),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.md),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: spacing.sm),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, NotificationDto notif, {required bool isUrgent}) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final bgColor = isUrgent ? Colors.red.shade50 : Colors.orange.shade50;
    final textColor = isUrgent ? Colors.red.shade900 : Colors.orange.shade900;
    final iconColor = isUrgent ? Colors.red : Colors.orange;

    return Card(
      color: bgColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.notifications),
        borderRadius: BorderRadius.circular(radius.md),
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
                        isUrgent ? Icons.error_rounded : Icons.warning_amber_rounded,
                        color: iconColor,
                        size: 18,
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        isUrgent ? 'URGENT ALERT' : 'HIGH PRIORITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDateTime(notif.createdAt),
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(
                notif.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              if (notif.message.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  notif.message,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius.md),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(height: spacing.sm),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing.xs),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherLeaveAlertCard(BuildContext context, int count) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.teacherLeaves),
        borderRadius: BorderRadius.circular(radius.md),
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
                      const Icon(
                        Icons.error_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        'ACTION REQUIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Teacher Leave Requests',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              Text(
                '$count pending requests awaiting approval.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

