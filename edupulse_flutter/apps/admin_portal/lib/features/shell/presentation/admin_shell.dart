import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../planner/presentation/providers/planner_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../tenant_setup/presentation/providers/tenant_providers.dart';
import '../../tenant_setup/data/models/tenant_models.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(schoolsListProvider.notifier).fetchSchools();
      final authState = ref.read(authStateProvider);
      final isSuperAdmin = authState is Authenticated &&
          (authState.user.isSuperuser ||
              authState.user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN'));
      if (isSuperAdmin) {
        ref.read(tenantsListProvider.notifier).fetchTenants();
      }
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the Admin Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Authenticated) {
        final user = next.user;
        final isSuper = user.isSuperuser ||
            user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN');

        final currentTenant = ref.read(selectedTenantIdProvider);
        if (currentTenant == null) {
          if (isSuper) {
            ref.read(selectedTenantIdProvider.notifier).state = null;
          } else {
            ref.read(selectedTenantIdProvider.notifier).state = user.tenantId;
          }
        }
      } else if (next is Unauthenticated) {
        ref.read(selectedTenantIdProvider.notifier).state = null;
      }
    });

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        final schools = ref.read(schoolsListProvider).schools;
        final match = schools.where((s) => s.id == next);
        if (match.isNotEmpty) {
          final tenantId = match.first.tenantId;
          if (ref.read(selectedTenantIdProvider) != tenantId) {
            ref.read(selectedTenantIdProvider.notifier).state = tenantId;
          }
        }
      }
    });

    ref.listen<SchoolsListState>(schoolsListProvider, (previous, next) {
      final selectedSchoolId = ref.read(selectedSchoolIdProvider);
      if (selectedSchoolId != null) {
        final match = next.schools.where((s) => s.id == selectedSchoolId);
        if (match.isNotEmpty) {
          final tenantId = match.first.tenantId;
          if (ref.read(selectedTenantIdProvider) != tenantId) {
            ref.read(selectedTenantIdProvider.notifier).state = tenantId;
          }
        }
      }
    });

    final schoolsState = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final tenantsState = ref.watch(tenantsListProvider);
    final selectedTenantId = ref.watch(activeTenantIdProvider);

    // Register the watcher provider to ensure it listens to active tenant switching
    ref.watch(tenantSetupWatcherProvider);

    final isSuperAdmin = authState is Authenticated &&
        (authState.user.isSuperuser ||
            authState.user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN'));

    final isTenantAdmin = authState is Authenticated &&
        authState.user.roles.any((r) => r.toUpperCase() == 'TENANT_ADMIN' || r.toUpperCase() == 'CHAIRMAN');

    final filteredSchools = schoolsState.schools.where((school) {
      if (isSuperAdmin || isTenantAdmin) return true;
      if (authState is Authenticated) {
        return authState.user.schools.contains(school.id);
      }
      return false;
    }).toList();

    String adminName = 'Administrator';
    String adminEmail = '';
    String tenantContext = 'Default Tenant';

    if (authState is Authenticated) {
      adminName = authState.user.fullName;
      adminEmail = authState.user.email;
      if (isSuperAdmin) {
        if (selectedTenantId == null) {
          tenantContext = 'No Tenant Selected';
        } else if (tenantsState.error != null || schoolsState.error != null) {
          tenantContext = 'Unable to load school context. Please retry.';
        } else if (tenantsState.isLoading) {
          tenantContext = 'Loading tenant context...';
        } else if (schoolsState.isLoading) {
          tenantContext = 'Loading schools...';
        } else if (selectedSchoolId == null) {
          tenantContext = 'Loading school context...';
        } else {
          final currentTenant = tenantsState.tenants.firstWhere(
            (t) => t.id == selectedTenantId,
            orElse: () => TenantDto(
              id: '',
              name: 'Delhi Public School Hyderabad',
              code: '',
              subdomain: '',
              email: '',
              timezone: '',
              currency: '',
              isActive: true,
              status: '',
            ),
          );
          tenantContext = currentTenant.name;
        }
      } else {
        final tId = authState.user.tenantId;
        tenantContext = tId != null
            ? 'Tenant ID: ${tId.substring(0, tId.length > 8 ? 8 : tId.length)}...'
            : 'No Tenant Context';
      }
    }

    final activePath = GoRouterState.of(context).matchedLocation;
    final isMobile = screenWidth < 768;

    // Sidebar items mapping
    Widget buildSidebarContent({bool isDrawer = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            selected: activePath == AppRoutes.dashboard,
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.dashboard);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Users'),
            selected: activePath.startsWith('/users'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.users);
            },
          ),
          if (isSuperAdmin)
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Tenants'),
              selected: activePath.startsWith('/tenants'),
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                context.go(AppRoutes.tenants);
              },
            ),
          ListTile(
            leading: const Icon(Icons.face_outlined),
            title: const Text('Students'),
            selected: activePath.startsWith('/students'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.students);
            },
          ),
          ListTile(
            leading: const Icon(Icons.co_present_outlined),
            title: const Text('Teachers & Staff'),
            selected: activePath.startsWith('/teachers'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.teachers);
            },
          ),
          ListTile(
            leading: const Icon(Icons.supervisor_account_outlined),
            title: const Text('Guardians'),
            selected: activePath.startsWith('/guardians'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.guardians);
            },
          ),
          ListTile(
            leading: const Icon(Icons.trending_up_outlined),
            title: const Text('Promotions'),
            selected: activePath.startsWith('/promotions'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.promotions);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Attendance'),
            selected: activePath.startsWith('/attendance'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.attendance);
            },
          ),

          // Expandable School Setup Section
          ExpansionTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('School Setup', style: TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: activePath.startsWith('/schools') ||
                activePath.startsWith('/classes') ||
                activePath.startsWith('/sections') ||
                activePath.startsWith('/subjects'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.business_outlined, size: 20),
                title: const Text('Schools / Campuses'),
                selected: activePath.startsWith('/schools') && !activePath.contains('/academic-years'),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.schools);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.calendar_month_outlined, size: 20),
                title: const Text('Academic Years'),
                selected: activePath.contains('/academic-years'),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  if (selectedSchoolId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a school context first.')),
                    );
                    return;
                  }
                  context.go('/schools/$selectedSchoolId/academic-years');
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.class_outlined, size: 20),
                title: const Text('Classes / Grade Levels'),
                selected: activePath.startsWith('/classes'),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.classes);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.room_preferences_outlined, size: 20),
                title: const Text('Sections & Rooms'),
                selected: activePath.startsWith('/sections'),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.sections);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.book_outlined, size: 20),
                title: const Text('Subject Catalog'),
                selected: activePath.startsWith('/subjects'),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.subjects);
                },
              ),
            ],
          ),

          // Expandable School Planner Section
          ExpansionTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('School Planner', style: TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: activePath.startsWith('/planner'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.calendar_today_outlined, size: 20),
                title: const Text('Calendar Feed'),
                selected: activePath == AppRoutes.plannerCalendar,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerCalendar);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.event_outlined, size: 20),
                title: const Text('Events'),
                selected: activePath == AppRoutes.plannerEvents,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerEvents);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.announcement_outlined, size: 20),
                title: const Text('Announcements'),
                selected: activePath == AppRoutes.plannerAnnouncements,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerAnnouncements);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                title: const Text('Circulars'),
                selected: activePath == AppRoutes.plannerCirculars,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerCirculars);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.school_outlined, size: 20),
                title: const Text('Exams'),
                selected: activePath == AppRoutes.plannerExams,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerExams);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                leading: const Icon(Icons.schedule_outlined, size: 20),
                title: const Text('Academic Schedule'),
                selected: activePath == AppRoutes.plannerSchedule,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  context.go(AppRoutes.plannerSchedule);
                },
              ),
            ],
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Bulk Import'),
            selected: activePath.startsWith('/bulk-import'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.bulkImport);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flight_takeoff),
            title: const Text('School Onboarding'),
            selected: activePath.startsWith('/school-onboarding'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.schoolOnboarding);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_alt_outlined),
            title: const Text('Data Migrations'),
            selected: activePath.startsWith('/migrations'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.migrations);
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Fees'),
            selected: activePath.startsWith('/fees'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.fees);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('Results'),
            selected: activePath == '/results' || (activePath.startsWith('/results/') && !activePath.startsWith('/results/report-cards')),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.results);
            },
          ),
          ListTile(
            key: const Key('drawer_report_cards_tile'),
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Report Cards'),
            selected: activePath.startsWith('/results/report-cards'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.reportCards);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reports'),
            selected: activePath.startsWith('/reports'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.reports);
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Connect Analytics'),
            selected: activePath.startsWith('/connect-analytics'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.connectAnalytics);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            selected: activePath.startsWith('/settings'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.settings);
            },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, size: 28),
            const SizedBox(width: 12),
            if (screenWidth >= 1200) ...[
              Flexible(
                child: Text(
                  'EduPulse Admin Portal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    tenantContext,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ] else if (screenWidth >= 1024) ...[
              Flexible(
                child: Text(
                  'EduPulse Admin Portal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              const Flexible(
                child: Text(
                  'EduPulse AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          ],
        ),
        actions: [
          // 🔄 Context Error Retry Button (Super Admin Only)
          if (isSuperAdmin && (tenantsState.error != null || schoolsState.error != null))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                label: const Text('Retry Context', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (tenantsState.error != null) {
                    ref.read(tenantsListProvider.notifier).fetchTenants();
                  }
                  if (schoolsState.error != null) {
                    ref.read(schoolsListProvider.notifier).fetchSchools();
                  }
                },
              ),
            ),
          // 🏢 Active Tenant Selector Dropdown (Super Admin Only)
          if (isSuperAdmin && tenantsState.tenants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 150,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: tenantsState.tenants.any((t) => t.id == selectedTenantId) ? selectedTenantId : null,
                      hint: const Text('Select Tenant', overflow: TextOverflow.ellipsis),
                      items: tenantsState.tenants.map((tenant) {
                        return DropdownMenuItem(
                          value: tenant.id,
                          child: Text(
                            tenant.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) async {
                        if (v != null) {
                          ref.read(selectedTenantIdProvider.notifier).state = v;
                          ref.read(selectedSchoolIdProvider.notifier).state = null;
                          ref.read(selectedAcademicYearIdProvider.notifier).state = null;
                          try {
                            await ref.read(sessionManagerProvider).saveSchoolId('');
                          } catch (_) {}
                          ref.read(schoolsListProvider.notifier).fetchSchools();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          // 🏫 Active School Selector Dropdown
          if (filteredSchools.isNotEmpty || isSuperAdmin || isTenantAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 150,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: filteredSchools.any((s) => s.id == selectedSchoolId) ? selectedSchoolId : null,
                      hint: const Text('All Schools', overflow: TextOverflow.ellipsis),
                      items: [
                        if (isSuperAdmin || isTenantAdmin)
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Schools',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ...filteredSchools.map((school) {
                          return DropdownMenuItem<String?>(
                            value: school.id,
                            child: Text(
                              school.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) async {
                        // 1. Invalidate planner providers to clear stale data immediately and prevent displaying data from previous school
                        ref.invalidate(calendarFeedProvider);
                        ref.invalidate(eventsListProvider);
                        ref.invalidate(announcementsListProvider);
                        ref.invalidate(examsListProvider);
                        ref.invalidate(plannerAssignmentsProvider);

                        // 2. Set selected school ID
                        ref.read(selectedSchoolIdProvider.notifier).state = v;
                        ref.read(selectedAcademicYearIdProvider.notifier).state = null; // Clear cached academic year

                        // 3. Sync selectedTenantIdProvider for UI and other components
                        if (v != null) {
                          final schools = ref.read(schoolsListProvider).schools;
                          final match = schools.where((s) => s.id == v);
                          if (match.isNotEmpty) {
                            ref.read(selectedTenantIdProvider.notifier).state = match.first.tenantId;
                          }
                        }

                        try {
                          await ref.read(sessionManagerProvider).saveSchoolId(v ?? '');
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (screenWidth >= 1024)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        adminName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        adminEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
                Consumer(
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
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => context.push(AppRoutes.notifications),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_outlined),
                  onPressed: _handleLogout,
                ),
              ],
            ),
          )
        ],
      ),
      drawer: isMobile
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(adminName),
                    accountEmail: Text(adminEmail),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  buildSidebarContent(isDrawer: true),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  )
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 280,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: buildSidebarContent(),
                ),
              ),
            ),
          Expanded(
            child: Container(
              color: theme.colorScheme.surface,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
