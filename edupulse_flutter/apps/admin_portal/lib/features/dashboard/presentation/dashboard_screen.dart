import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../core/routing/routes.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../school_setup/presentation/providers/school_setup_providers.dart';
import 'widgets/tenant_dashboard_body.dart';

// Provider to fetch and cache system health status
final systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/system/health',
    mapper: (json) => json as Map<String, dynamic>,
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final authState = ref.watch(authStateProvider);
    final healthState = ref.watch(systemHealthProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);

    final isTenantAdminOrSuper = authState is Authenticated &&
        (authState.user.isSuperuser ||
            authState.user.roles.any((r) =>
                r.toUpperCase() == 'SUPER_ADMIN' ||
                r.toUpperCase() == 'TENANT_ADMIN' ||
                r.toUpperCase() == 'CHAIRMAN'));

    if (selectedSchoolId == null && isTenantAdminOrSuper) {
      return const Scaffold(
        body: TenantDashboardBody(),
      );
    }

    String adminName = 'Administrator';
    String schoolContext = 'N/A';
    if (authState is Authenticated) {
      adminName = authState.user.fullName;
      if (authState.user.schools.isNotEmpty) {
        schoolContext = 'Active School ID: ${authState.user.schools.first}';
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Card
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
                        Icons.person,
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
                            'Welcome Back, $adminName',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Logged in under $schoolContext',
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

            // 2. Health & Metrics Row
            Text(
              'System Health & Performance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.sm),
            healthState.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          'Failed to retrieve system status: ${error.toString()}',
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.invalidate(systemHealthProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                final appStatus = data['status'] ?? 'unknown';
                final dbStatus = data['database'] ?? 'unknown';
                final uptime = data['uptime'] ?? '0s';
                final timestamp = data['timestamp'] ?? 'unknown';

                final isAppHealthy = appStatus == 'healthy';
                final isDbHealthy = dbStatus == 'healthy';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    if (isMobile) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHealthCard(
                            theme: theme,
                            title: 'FastAPI Backend Uptime',
                            subtitle: uptime,
                            icon: Icons.speed_outlined,
                            statusText: appStatus.toString().toUpperCase(),
                            isHealthy: isAppHealthy,
                          ),
                          SizedBox(height: spacing.md),
                          _buildHealthCard(
                            theme: theme,
                            title: 'PostgreSQL Database Connection',
                            subtitle: 'Last Ping: ${timestamp.split('T').first}',
                            icon: Icons.storage_outlined,
                            statusText: dbStatus.toString().toUpperCase(),
                            isHealthy: isDbHealthy,
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildHealthCard(
                              theme: theme,
                              title: 'FastAPI Backend Uptime',
                              subtitle: uptime,
                              icon: Icons.speed_outlined,
                              statusText: appStatus.toString().toUpperCase(),
                              isHealthy: isAppHealthy,
                            ),
                          ),
                          SizedBox(width: spacing.md),
                          Expanded(
                            child: _buildHealthCard(
                              theme: theme,
                              title: 'PostgreSQL Database Connection',
                              subtitle: 'Last Ping: ${timestamp.split('T').first}',
                              icon: Icons.storage_outlined,
                              statusText: dbStatus.toString().toUpperCase(),
                              isHealthy: isDbHealthy,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                );
              },
            ),
            SizedBox(height: spacing.xl),

            // 3. Quick Access Modules (Phase 2 & 3 Roadmaps)
            Text(
              'Administrative Modules',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 600) {
                  crossAxisCount = 1;
                } else if (constraints.maxWidth < 900) {
                  crossAxisCount = 2;
                } else if (constraints.maxWidth < 1200) {
                  crossAxisCount = 3;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing.md,
                  mainAxisSpacing: spacing.md,
                  childAspectRatio: 1.4,
                  children: [
                    _buildModuleCard(
                      theme: theme,
                      title: 'School Config',
                      subtitle: 'Academic Years, Classes, Sections',
                      icon: Icons.school_outlined,
                      isImplemented: true,
                      onTap: () => context.go(AppRoutes.schools),
                    ),
                    _buildModuleCard(
                      theme: theme,
                      title: 'User Management',
                      subtitle: 'Students, Teachers, Guardians',
                      icon: Icons.people_outline,
                      isImplemented: true,
                      onTap: () => context.go(AppRoutes.users),
                    ),
                    _buildModuleCard(
                      theme: theme,
                      title: 'Bulk Import',
                      subtitle: 'Spreadsheet Onboarding Portal',
                      icon: Icons.cloud_upload_outlined,
                      isImplemented: true,
                      onTap: () => context.go(AppRoutes.bulkImport),
                    ),
                    _buildModuleCard(
                      theme: theme,
                      title: 'Fee Structure',
                      subtitle: 'Concessions, Assign, Invoicing',
                      icon: Icons.payments_outlined,
                      isImplemented: true,
                      onTap: () => context.go(AppRoutes.fees),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required String statusText,
    required bool isHealthy,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isHealthy ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isHealthy ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isImplemented,
    VoidCallback? onTap,
  }) {
    return Card(
      color: isImplemented ? null : theme.colorScheme.surface.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isImplemented ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: isImplemented
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  if (!isImplemented)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Soon',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isImplemented ? null : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
