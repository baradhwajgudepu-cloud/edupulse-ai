import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

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

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        ref.read(sessionManagerProvider).saveSchoolId(next);
      }
    });

    final schoolsState = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);

    String adminName = 'Administrator';
    String adminEmail = '';
    String tenantContext = 'Default Tenant';

    if (authState is Authenticated) {
      adminName = authState.user.fullName;
      adminEmail = authState.user.email;
      tenantContext = 'Tenant ID: ${authState.user.tenantId.substring(0, 8)}...';
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
          ListTile(
            leading: const Icon(Icons.face_outlined),
            title: const Text('Students'),
            selected: activePath.startsWith('/students'),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go(AppRoutes.students);
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
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reports (Soon)'),
            enabled: false,
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings (Soon)'),
            enabled: false,
            onTap: () {},
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 28),
            const SizedBox(width: 12),
            if (screenWidth >= 1024) ...[
              Flexible(
                child: Text(
                  'EduPulse Admin Portal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Container(
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
                ),
              ),
            ] else ...[
              const Text('EduPulse AI'),
            ]
          ],
        ),
        actions: [
          // 🏫 Active School Selector Dropdown
          if (schoolsState.schools.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSchoolId,
                    hint: const Text('Select School'),
                    items: schoolsState.schools.map((school) {
                      return DropdownMenuItem(
                        value: school.id,
                        child: Text(
                          school.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(selectedSchoolIdProvider.notifier).state = v;
                        ref.read(selectedAcademicYearIdProvider.notifier).state = null; // Clear cached academic year
                      }
                    },
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (screenWidth >= 800)
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
