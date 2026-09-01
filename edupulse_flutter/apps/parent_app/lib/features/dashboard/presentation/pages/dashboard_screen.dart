import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/quick_actions.dart';
import '../../../../core/router/routes.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardStateProvider.notifier).fetchSummary();
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(dashboardStateProvider.notifier).fetchSummary(isRefresh: true);
    await ref.read(notificationsStateProvider.notifier).fetchNotifications(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Unauthenticated) {
        context.go(AppRoutes.login);
      }
    });

    final authState = ref.watch(authStateProvider);
    final dashboardState = ref.watch(dashboardStateProvider);

    String welcomeText = 'Welcome';
    if (authState is Authenticated) {
      welcomeText = 'Welcome, ${authState.user.fullName}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(local?.translate('dashboard') ?? 'Dashboard'),
        actions: [
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
                    onPressed: () => context.push('/notifications'),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: local?.translate('logout') ?? 'Logout',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(context, dashboardState, welcomeText, spacing, radius,
            theme, local),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.communication),
        label: const Text('Connect'),
        icon: const Icon(Icons.forum_rounded),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DashboardState state,
    String welcomeText,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
    EduLocalization? local,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
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
                    local?.translate('dashboard_placeholder') ??
                        'Welcome to EduPulse Parent App',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          const QuickActions(),
          SizedBox(height: spacing.lg),
          switch (state) {
            DashboardInitial() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            DashboardLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            DashboardEmpty() => Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    children: [
                      const Icon(Icons.analytics_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: spacing.sm),
                      Text(
                        local?.translate('no_data') ??
                            'No dashboard statistics found',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            DashboardError(:final message) => Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      SizedBox(height: spacing.sm),
                      Text(
                        local?.translate('dashboard_error') ??
                            'Failed to fetch dashboard metrics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: spacing.md),
                      ElevatedButton.icon(
                        onPressed: _onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(local?.translate('retry') ?? 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            DashboardSuccess(:final data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.students.length > 1) ...[
                    DropdownButtonFormField<StudentProfile>(
                      initialValue: data.selectedStudent,
                      items: data.students.map((student) {
                        return DropdownMenuItem(
                          value: student,
                          child: Text(student.fullName),
                        );
                      }).toList(),
                      onChanged: (newStudent) {
                        if (newStudent != null) {
                          ref.read(dashboardStateProvider.notifier).selectStudent(newStudent);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Child',
                        prefixIcon: const Icon(Icons.face_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius.sm),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.sm,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.md),
                  ],
                  DashboardCards(data: data),
                ],
              ),
          },
        ],
      ),
    );
  }
}
