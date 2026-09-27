import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../school_setup/data/models/school_setup_models.dart';
import '../../school_setup/presentation/widgets/school_logo_widget.dart';
import '../../school_setup/presentation/widgets/quick_school_onboarding_dialog.dart';
import '../../planner/presentation/providers/planner_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/auth/portal_permissions.dart';
import '../../tenant_setup/presentation/providers/tenant_providers.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';
import '../../dashboard/presentation/providers/command_center_provider.dart';
import '../../students/presentation/providers/student_providers.dart';
import '../../teachers/presentation/providers/teachers_providers.dart';
import '../../guardians/presentation/providers/guardian_providers.dart';
import '../../fees/presentation/providers/fees_provider.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isRetrying = false;
  bool _isLoggingOut = false;

  void _invalidateSchoolScopedProviders() {
    ref.invalidate(commandCenterProvider);
    ref.invalidate(studentListProvider);
    ref.invalidate(teachersListProvider);
    ref.invalidate(guardianListProvider);
    ref.invalidate(calendarFeedProvider);
    ref.invalidate(eventsListProvider);
    ref.invalidate(announcementsListProvider);
    ref.invalidate(examsListProvider);
    ref.invalidate(plannerAssignmentsProvider);
    ref.invalidate(teacherLeavesProvider);
    ref.invalidate(plannerNotificationsProvider);
    ref.invalidate(feeTypesProvider);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authState = ref.read(authStateProvider);
      if (authState is! Authenticated) {
        return;
      }
      ref.read(schoolsListProvider.notifier).fetchSchools();
      final isSuperAdmin = authState.user.isSuperuser ||
          authState.user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN');
      if (isSuperAdmin) {
        ref.read(tenantsListProvider.notifier).fetchTenants();
      }
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
    });
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    }
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

  void _showContextDetailsDialog(BuildContext context) {
    final schoolsState = ref.read(schoolsListProvider);
    final selectedSchoolId = ref.read(selectedSchoolIdProvider);
    final tenantsState = ref.read(tenantsListProvider);
    final activeTenantId = ref.read(activeTenantIdProvider);

    final school = schoolsState.schools.where((s) => s.id == selectedSchoolId).firstOrNull;
    final schoolName = school?.name ?? (selectedSchoolId == null ? 'All Schools / None' : 'Unknown School');
    final schoolId = school?.id ?? (selectedSchoolId ?? 'None');

    final tenant = tenantsState.tenants.where((t) => t.id == activeTenantId).firstOrNull;
    final tenantName = tenant?.name ?? (activeTenantId == null ? 'None' : 'Tenant ($activeTenantId)');
    final tenantId = activeTenantId ?? 'None';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('System Context Details'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diagnostic details for the currently active administrative context:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildContextRow(ctx, 'Tenant Name', tenantName),
              _buildContextRow(ctx, 'Tenant ID', tenantId, isCopyable: tenantId != 'None'),
              const Divider(height: 24),
              _buildContextRow(ctx, 'School Name', schoolName),
              _buildContextRow(ctx, 'School ID', schoolId, isCopyable: schoolId != 'None'),
              const Divider(height: 24),
              _buildContextRow(ctx, 'selectedSchoolId (State)', selectedSchoolId ?? 'None', isCopyable: selectedSchoolId != null),
              _buildContextRow(ctx, 'API Header (X-Tenant-ID)', activeTenantId ?? 'None', isCopyable: activeTenantId != null),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContextRow(BuildContext context, String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 175,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied $label to clipboard: $value'), duration: const Duration(seconds: 1)),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showUniversalSearchDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    String activeCategory = 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();

          final List<_SearchDestination> allItems = [
            const _SearchDestination('Students & Enrollments', 'View student directory and 360 profiles', Icons.school_outlined, AppRoutes.students, 'students'),
            const _SearchDestination('Teachers & Staff Directory', 'Manage faculty, designations and staff records', Icons.badge_outlined, AppRoutes.teachers, 'staff'),
            const _SearchDestination('Parents & Guardians', 'Linked family accounts and guardian profiles', Icons.family_restroom, AppRoutes.guardians, 'students'),
            const _SearchDestination('Classrooms & Rooms', 'View room allocations and facility capacities', Icons.meeting_room_outlined, AppRoutes.rooms, 'academics'),
            const _SearchDestination('Fee Collection & Outstanding', 'Student fee ledgers and pending installments', Icons.payments_outlined, AppRoutes.fees, 'finance'),
            const _SearchDestination('Staff Salaries & Disbursements', 'Monthly salary slips and disbursement records', Icons.payments_outlined, AppRoutes.salaries, 'finance'),
            const _SearchDestination('School Expenditures', 'Vendor payouts and operational expenditure logs', Icons.receipt_long_outlined, AppRoutes.expenses, 'finance'),
            const _SearchDestination('Timetables & Schedule', 'Master school timetable and daily schedules', Icons.table_chart_outlined, AppRoutes.timetables, 'academics'),
            const _SearchDestination('Exams & Assessments', 'Academic examinations, grading, marks import & report cards', Icons.assignment_turned_in_outlined, AppRoutes.results, 'academics'),
            const _SearchDestination('Attendance Registers', 'Student and staff check-ins and audit trails', Icons.how_to_reg_outlined, AppRoutes.attendance, 'operations'),
            const _SearchDestination('Bulk Import Center', 'Excel / CSV imports for students and staff', Icons.cloud_upload_outlined, AppRoutes.bulkImport, 'operations'),
            const _SearchDestination('School Setup Center', '8-stage progressive school configuration and onboarding', Icons.check_circle_outline, AppRoutes.schoolSetup, 'operations'),
            const _SearchDestination('School Administration & Compliance', 'UDISE+, recognition, secure documents, attendance payroll', Icons.account_balance_outlined, AppRoutes.schoolAdministration, 'operations'),
            const _SearchDestination('Roles & Permissions Matrix', 'RBAC matrix and role authorization policies', Icons.shield_outlined, AppRoutes.rolesPermissions, 'operations'),
          ];

          final filtered = allItems.where((i) {
            final matchesCategory = activeCategory == 'all' || i.category == activeCategory;
            final matchesQuery = query.isEmpty ||
                i.title.toLowerCase().contains(query) ||
                i.subtitle.toLowerCase().contains(query);
            return matchesCategory && matchesQuery;
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: "Search modules, students, staff, fees (e.g. 'Attendance', 'Timetable')...",
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        if (searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                            splashRadius: 16,
                            onPressed: () {
                              searchCtrl.clear();
                              setDialogState(() {});
                            },
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'ESC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Category Filter Chips
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSearchChip('all', 'All Modules', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                          const SizedBox(width: 6),
                          _buildSearchChip('students', 'Students', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                          const SizedBox(width: 6),
                          _buildSearchChip('staff', 'Staff & Faculty', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                          const SizedBox(width: 6),
                          _buildSearchChip('finance', 'Fee & Finance', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                          const SizedBox(width: 6),
                          _buildSearchChip('academics', 'Academics', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                          const SizedBox(width: 6),
                          _buildSearchChip('operations', 'Operations', activeCategory, (val) => setDialogState(() => activeCategory = val)),
                        ],
                      ),
                    ),
                  ),

                  // 3. Results List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No matching modules found',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Try searching for "attendance", "fees", "students", or "timetable"',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCCFBF1)),
                                  ),
                                  child: Icon(item.icon, size: 18, color: const Color(0xFF0F766E)),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFCBD5E1)),
                                hoverColor: const Color(0xFFF8FAFC),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.go(item.route);
                                },
                              );
                            },
                          ),
                  ),

                  // 4. Modal Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Navigate with mouse or tap • ESC to dismiss',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildSearchChip(
    String id,
    String label,
    String activeId,
    ValueChanged<String> onSelected,
  ) {
    final isActive = id == activeId;
    return InkWell(
      onTap: () => onSelected(id),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, ThemeData theme, {bool compact = false}) {
    return PopupMenuButton<String>(
      key: const Key('header-create-btn'),
      tooltip: 'Quick Create',
      offset: const Offset(0, 42),
      child: Container(
        height: 36,
        padding: compact
            ? const EdgeInsets.all(8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: EduPulseTheme.primaryTealDark,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            if (!compact) ...[
              const SizedBox(width: 6),
              const Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      onSelected: (route) {
        if (route == 'ONBOARD_NEW_SCHOOL') {
          QuickSchoolOnboardingDialog.show(context);
        } else if (route.isNotEmpty) {
          context.go(route);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'ONBOARD_NEW_SCHOOL',
          child: Row(
            children: [
              Icon(Icons.add_business_rounded, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text(
                'Create New School',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppRoutes.students,
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1, size: 18),
              SizedBox(width: 10),
              Text('Add Student'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.teachers,
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 18),
              SizedBox(width: 10),
              Text('Add Teacher / Staff'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.guardians,
          child: Row(
            children: [
              Icon(Icons.family_restroom, size: 18),
              SizedBox(width: 10),
              Text('Add Parent / Guardian'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.rooms,
          child: Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: 18),
              SizedBox(width: 10),
              Text('Add Classroom / Room'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppRoutes.fees,
          child: Row(
            children: [
              Icon(Icons.payments_outlined, size: 18),
              SizedBox(width: 10),
              Text('Record Fee Payment'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.expenses,
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18),
              SizedBox(width: 10),
              Text('Record School Expense'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.bulkImport,
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 18),
              SizedBox(width: 10),
              Text('Bulk Data Import'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppRoutes.examinations,
          child: Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 18),
              SizedBox(width: 10),
              Text('Create Examination'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppRoutes.marksImport,
          child: Row(
            children: [
              Icon(Icons.upload_file_outlined, size: 18),
              SizedBox(width: 10),
              Text('Import Exam Marks'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTenantSelector(
    ThemeData theme,
    TenantsListState tenantsState,
    String? selectedTenantId, {
    bool isDrawer = false,
    double screenWidth = 1200,
  }) {
    final dropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: SafeDropdownButton<String>(
          isExpanded: true,
          value: selectedTenantId,
          hint: const Text('No Tenant', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
          items: tenantsState.tenants.map((tenant) {
            return DropdownMenuItem(
              value: tenant.id,
              child: Text(
                tenant.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) async {
            if (v == null) return;
            _invalidateSchoolScopedProviders();
            final sessionManager = ref.read(sessionManagerProvider);
            try {
              ref.read(selectedTenantIdProvider.notifier).state = v;
              ref.read(selectedSchoolIdProvider.notifier).state = null;
              ref.read(selectedAcademicYearIdProvider.notifier).state = null;

              await sessionManager.saveSchoolId('');
              await sessionManager.saveSchoolName('');
              await sessionManager.saveTenantId(v);
              final newMatch = tenantsState.tenants.where((t) => t.id == v);
              if (newMatch.isNotEmpty) {
                await sessionManager.saveTenantName(newMatch.first.name);
              }
              await ref.read(schoolsListProvider.notifier).fetchSchools();
            } catch (_) {}
          },
        ),
      ),
    );

    if (isDrawer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ORGANIZATION / TENANT',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: dropdown),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: SizedBox(
        width: screenWidth < 960 ? 110 : 140,
        child: dropdown,
      ),
    );
  }

  Widget _buildSchoolSelector(
    ThemeData theme,
    List<SchoolDto> displaySchools,
    bool isSuperAdmin,
    bool isTenantAdmin,
    String? selectedSchoolId,
    double screenWidth, {
    bool isDrawer = false,
  }) {
    if (!isSuperAdmin && !isTenantAdmin && displaySchools.length == 1) {
      final singleBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
          children: [
            SchoolLogoWidget(
              schoolId: displaySchools.first.id,
              logoUrl: displaySchools.first.logoUrl,
              logoUpdatedAt: displaySchools.first.logoUpdatedAt,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displaySchools.first.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

      if (isDrawer) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ASSIGNED SCHOOL',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            singleBadge,
          ],
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth < 800 ? 100 : (screenWidth < 960 ? 120 : (screenWidth < 1100 ? 170 : 220)),
          ),
          child: singleBadge,
        ),
      );
    }

    final dropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: SafeDropdownButton<String?>(
          isExpanded: true,
          value: selectedSchoolId,
          fallbackValue: null,
          hint: const Text('All Schools', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
          items: [
            if (isSuperAdmin || isTenantAdmin)
              const DropdownMenuItem<String?>(
                value: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.corporate_fare_rounded, size: 16, color: EduPulseTheme.primaryTeal),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'All Schools',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ...displaySchools.map((school) {
              return DropdownMenuItem<String?>(
                value: school.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SchoolLogoWidget(
                      schoolId: school.id,
                      logoUrl: school.logoUrl,
                      logoUpdatedAt: school.logoUpdatedAt,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        school.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (v) async {
            _invalidateSchoolScopedProviders();

            ref.read(selectedSchoolIdProvider.notifier).state = v;
            ref.read(selectedAcademicYearIdProvider.notifier).state = null;

            final sessionManager = ref.read(sessionManagerProvider);
            if (v != null) {
              final schools = ref.read(schoolsListProvider).schools;
              final match = schools.where((s) => s.id == v);
              if (match.isNotEmpty) {
                final schoolTenantId = match.first.tenantId;
                if (schoolTenantId.isNotEmpty) {
                  ref.read(selectedTenantIdProvider.notifier).state = schoolTenantId;
                  try {
                    await sessionManager.saveTenantId(schoolTenantId);
                  } catch (_) {}
                }
                try {
                  await sessionManager.saveSchoolName(match.first.name);
                } catch (_) {}
              }
              try {
                await sessionManager.saveSchoolId(v);
              } catch (_) {}
            } else {
              try {
                await sessionManager.saveSchoolId('');
                await sessionManager.saveSchoolName('');
              } catch (_) {}
            }
          },
        ),
      ),
    );

    if (isDrawer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SCHOOL CAMPUS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: dropdown),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: screenWidth < 960 ? 90 : 120,
          maxWidth: screenWidth < 800 ? 110 : (screenWidth < 960 ? 130 : (screenWidth < 1100 ? 170 : 210)),
        ),
        child: dropdown,
      ),
    );
  }

  String _sanitizeAuthErrorMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('userstatus.locked') ||
        lower.contains('account status is currently') ||
        lower.contains('account_locked') ||
        lower.contains('account is locked')) {
      return 'Your account is locked. Please contact your school administrator to unlock your account.';
    }
    if (lower.contains('access_denied') || lower.contains('access denied') || lower.contains('lacks admin access')) {
      return 'You do not have administrative privileges to access this portal. Please sign in with an authorized administrator account.';
    }
    if (lower.contains('server_unreachable') ||
        lower.contains('connection failure') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('socketexception') ||
        lower.contains('cors')) {
      return 'Unable to reach the EduPulse backend server. Please check your internet connection and try again.';
    }
    if (lower.contains('401') || lower.contains('unauthorized') || lower.contains('expired')) {
      return 'Your authentication session has expired or is invalid. Please sign in again to continue.';
    }
    if (lower.contains('404') || lower.contains('not found') || lower.contains('not_found')) {
      return 'The EduPulse authentication service endpoint was not found (404). Please ensure the EduPulse backend is running at http://127.0.0.1:8000.';
    }
    if (lower.contains('500') || lower.contains('502') || lower.contains('503') || lower.contains('504')) {
      return 'The EduPulse server encountered a temporary issue. Please try again in a few moments.';
    }
    return 'A temporary operational issue occurred while restoring your session. Please retry or return to the login screen.';
  }

  Widget _buildAuthErrorRecoveryScreen(
    BuildContext context,
    ThemeData theme,
    AuthError authError,
  ) {
    final isLocked = isAccountLockedError(message: authError.message);
    final cardTitle = isLocked ? 'Account Locked' : 'Unable to restore your session';
    final cardIcon = isLocked ? Icons.lock_person_outlined : Icons.sync_problem_rounded;
    final sanitizedMessage = _sanitizeAuthErrorMessage(authError.message);

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EduPulseCard(
              padding: EduPulseCardPadding.lg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Icon(
                      cardIcon,
                      size: 28,
                      color: EduPulseTheme.roseDanger,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    cardTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sanitizedMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('auth_recovery_login_button'),
                          onPressed: (_isRetrying || _isLoggingOut)
                              ? null
                              : () async {
                                  setState(() => _isLoggingOut = true);
                                  try {
                                    await ref.read(authStateProvider.notifier).logout();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoggingOut = false);
                                    }
                                  }
                                },
                          icon: _isLoggingOut
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Return to Login'),
                        ),
                      ),
                      if (!isLocked) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('auth_recovery_retry_button'),
                            onPressed: (_isRetrying || _isLoggingOut)
                                ? null
                                : () async {
                                    setState(() => _isRetrying = true);
                                    try {
                                      await ref.read(authStateProvider.notifier).checkAuth();
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isRetrying = false);
                                      }
                                    }
                                  },
                            icon: _isRetrying
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EduPulseTheme.primaryTeal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required String id,
    required String label,
    required IconData icon,
    required String route,
    required bool isActive,
    String? badge,
    String? progressBadge,
    bool alert = false,
    bool isDrawer = false,
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: isActive ? EduPulseTheme.primaryTealDark : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: key,
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            context.go(route);
          },
          hoverColor: const Color(0x15FFFFFF),
          splashColor: const Color(0x25FFFFFF),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progressBadge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x33115E59),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x6614B8A6)),
                    ),
                    child: Text(
                      progressBadge,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5EEAD4),
                      ),
                    ),
                  ),
                ] else if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ] else if (alert) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B), // Amber 500
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader({bool isDrawer = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x25334155))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: EduPulseTheme.primaryTeal,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'EP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EDUPULSE AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Release 2.0 • School OS',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isDrawer)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildSetupProgressCard(BuildContext context, SchoolDto? school, {bool isDrawer = false}) {
    final hasProfile = school != null && school.name.isNotEmpty && school.code.isNotEmpty;
    final hasBoard = school != null && school.board.isNotEmpty;
    final hasGeofence = school != null && school.isGeofenceConfigured;

    int completed = 0;
    if (hasProfile && hasBoard) completed++;
    completed += 4; // Core academic structures pre-seeded in release
    if (hasGeofence) completed++;
    if (completed > 8) completed = 8;
    if (completed < 1) completed = 1;

    final pct = (completed / 8.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: InkWell(
        onTap: () {
          if (isDrawer) Navigator.pop(context);
          context.go(AppRoutes.schoolSetup);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2DD4BF)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'School Setup',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$completed of 8',
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarProfileCard(BuildContext context, UserEntity user, {bool isDrawer = false}) {
    final name = user.fullName.isNotEmpty ? user.fullName : 'Administrator';
    final role = user.isSuperuser ? 'Super Admin' : (user.roles.isNotEmpty ? user.roles.first : 'School Admin');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x25334155))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1E293B),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Color(0xFF2DD4BF),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 16, color: Color(0xFF94A3B8)),
            tooltip: 'Sign Out',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              if (isDrawer) Navigator.pop(context);
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopMicroBar(SchoolDto? selectedSchool, List<SchoolDto> displaySchools, String formattedDate) {
    final school = selectedSchool ?? (displaySchools.isNotEmpty ? displaySchools.first : null);
    final schoolName = school?.name ?? 'EduPulse AI Campus';
    final affiliation = school != null && school.board.isNotEmpty ? '${school.board} (${school.schoolType})' : 'CBSE Affiliated';
    final schoolCode = school?.code ?? 'SCH-01';

    return Container(
      height: 32,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 780;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.school, size: 14, color: Color(0xFF2DD4BF)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        schoolName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          affiliation,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        schoolCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AY: 2026-2027',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuperAdminContextBanner(BuildContext context, SchoolDto currentSchool, List<SchoolDto> allSchools) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x4D0D9488)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 960;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0x3314B8A6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x662DD4BF)),
                      ),
                      child: const Icon(Icons.business, size: 12, color: Color(0xFF5EEAD4)),
                    ),
                    const SizedBox(width: 8),
                    if (!isNarrow)
                      const Text(
                        'Current School Context: ',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    Flexible(
                      child: Text(
                        currentSchool.name,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        currentSchool.code,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5EEAD4)),
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 6),
                      StatusBadge(
                        label: currentSchool.status.isNotEmpty ? currentSchool.status : 'Active',
                        variant: currentSchool.status.toUpperCase() == 'ACTIVE'
                            ? StatusBadgeVariant.success
                            : StatusBadgeVariant.brand,
                        size: StatusBadgeSize.sm,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isNarrow ? 180 : 260),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: SafeDropdownButton<String?>(
                          key: const Key('super_admin_context_school_dropdown'),
                          value: currentSchool.id,
                          fallbackValue: null,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          items: allSchools.map((s) {
                            return DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                isNarrow ? s.code : '${s.name} (${s.code})',
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              _invalidateSchoolScopedProviders();
                              ref.read(selectedSchoolIdProvider.notifier).state = v;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _invalidateSchoolScopedProviders();
                      ref.read(selectedSchoolIdProvider.notifier).state = null;
                      ref.read(selectedAcademicYearIdProvider.notifier).state = null;
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x3314B8A6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x6614B8A6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 12, color: Color(0xFF5EEAD4)),
                          if (!isNarrow) ...[
                            const SizedBox(width: 4),
                            const Text(
                              'Platform Scope',
                              style: TextStyle(fontSize: 11, color: Color(0xFF5EEAD4), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaleContextBanner(BuildContext context) {
    return Container(
      height: 38,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amberAccent),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Invalid school context detected.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _invalidateSchoolScopedProviders();
                  ref.read(selectedSchoolIdProvider.notifier).state = null;
                  ref.read(selectedAcademicYearIdProvider.notifier).state = null;
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x3314B8A6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x6614B8A6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 12, color: Color(0xFF5EEAD4)),
                      if (!isNarrow) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'Return to Platform Scope',
                          style: TextStyle(fontSize: 11, color: Color(0xFF5EEAD4), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainHeaderBar(
    BuildContext context,
    ThemeData theme,
    String timeGreeting,
    String adminName,
    UserEntity user,
    bool isDrawerMode,
    bool isMobile,
    bool isSuperAdmin,
    bool isTenantAdmin,
    TenantsListState tenantsState,
    String? selectedTenantId,
    List<SchoolDto> displaySchools,
    String? selectedSchoolId,
    double screenWidth,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isDrawerMode)
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, size: 22, color: Color(0xFF334155)),
                      tooltip: 'Toggle Navigation',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '$timeGreeting, $adminName',
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
                          const SizedBox(width: 4),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      if (!isMobile)
                        const Text(
                          'School Command Center & Daily Operations',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
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
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (screenWidth >= 1240) ...[
                if (isSuperAdmin && tenantsState.tenants.isNotEmpty)
                  _buildTenantSelector(theme, tenantsState, selectedTenantId, screenWidth: screenWidth),
                if (displaySchools.isNotEmpty || isSuperAdmin || isTenantAdmin)
                  _buildSchoolSelector(theme, displaySchools, isSuperAdmin, isTenantAdmin, selectedSchoolId, screenWidth),
                const SizedBox(width: 8),
              ],
              if (screenWidth >= 1024) ...[
                InkWell(
                  key: const Key('header-global-search-trigger'),
                  onTap: () => _showUniversalSearchDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          screenWidth >= 1180 ? 'Search anything...' : 'Search...',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
                            ],
                          ),
                          child: const Text(
                            '⌘K',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCreateButton(context, theme),
                const SizedBox(width: 4),
              ] else ...[
                IconButton(
                  key: const Key('header-global-search-trigger'),
                  icon: const Icon(Icons.search, color: Color(0xFF334155)),
                  tooltip: 'Search... ⌘K',
                  onPressed: () => _showUniversalSearchDialog(context),
                ),
                _buildCreateButton(context, theme, compact: true),
              ],
              if (isSuperAdmin || isTenantAdmin)
                IconButton(
                  tooltip: 'System Context Details',
                  icon: const Icon(Icons.info_outline, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => _showContextDetailsDialog(context),
                ),
              Consumer(
                builder: (context, ref, child) {
                  final notifState = ref.watch(notificationsStateProvider);
                  int unreadCount = 0;
                  if (notifState is NotificationsSuccess) {
                    unreadCount = notifState.unreadCount;
                  }
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF334155)),
                        onPressed: () => context.push(AppRoutes.notifications),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Admin Profile',
                offset: const Offset(0, 48),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'setup') {
                    context.go(AppRoutes.schoolSetup);
                  } else if (value == 'settings') {
                    context.go(AppRoutes.settings);
                  } else if (value == 'logout') {
                    _handleLogout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(adminName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'setup',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Text('School Setup Center'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Settings & Roles'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 16, color: Color(0xFFE11D48)),
                        SizedBox(width: 8),
                        Text('Sign Out', style: TextStyle(color: Color(0xFFE11D48))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSidebar(
    BuildContext context,
    String activePath,
    SchoolDto? selectedSchool,
    SchoolsListState schoolsState,
    UserEntity user,
    PortalPermissions permissions, {
    bool isDrawer = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandHeader(isDrawer: isDrawer),
        _buildSetupProgressCard(context, selectedSchool, isDrawer: isDrawer),
        const SizedBox(height: 6),

        _buildNavItem(
          context: context,
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          route: AppRoutes.dashboard,
          isActive: activePath == AppRoutes.dashboard,
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'students',
          label: 'Students',
          icon: Icons.school_outlined,
          route: AppRoutes.students,
          isActive: activePath.startsWith(AppRoutes.students),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'guardians',
          label: 'Parents & Guardians',
          icon: Icons.people_outline,
          route: AppRoutes.guardians,
          isActive: activePath.startsWith(AppRoutes.guardians),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'staff',
          label: 'Teachers & Staff',
          icon: Icons.badge_outlined,
          route: AppRoutes.teachers,
          isActive: activePath.startsWith(AppRoutes.teachers),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'classes',
          label: 'Classes & Sections',
          icon: Icons.layers_outlined,
          route: AppRoutes.classes,
          isActive: activePath.startsWith(AppRoutes.classes) || activePath.startsWith(AppRoutes.sections),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'rooms',
          label: 'Classrooms & Rooms',
          icon: Icons.meeting_room_outlined,
          route: AppRoutes.rooms,
          isActive: activePath == AppRoutes.rooms,
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'planner',
          label: 'School Planner',
          icon: Icons.calendar_month_outlined,
          route: AppRoutes.plannerSchedule,
          isActive: activePath.startsWith('/planner'),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'attendance',
          label: 'Attendance',
          icon: Icons.how_to_reg_outlined,
          route: AppRoutes.attendance,
          isActive: activePath.startsWith(AppRoutes.attendance),
          alert: true,
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'exams-assessments',
          label: 'Exams & Assessments',
          icon: Icons.assignment_turned_in_outlined,
          route: AppRoutes.results,
          isActive: activePath.startsWith(AppRoutes.results),
          isDrawer: isDrawer,
          key: const Key('sidebar_nav_exams_assessments'),
        ),
        if (permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal) ...[
          _buildNavItem(
            context: context,
            id: 'fees',
            label: 'Fees & Collection',
            icon: Icons.payments_outlined,
            route: AppRoutes.fees,
            isActive: activePath.startsWith(AppRoutes.fees) &&
                !activePath.startsWith(AppRoutes.salaries) &&
                !activePath.startsWith(AppRoutes.expenses),
            alert: true,
            isDrawer: isDrawer,
          ),
          _buildNavItem(
            context: context,
            id: 'expenses',
            label: 'Expenses',
            icon: Icons.receipt_long_outlined,
            route: AppRoutes.expenses,
            isActive: activePath.startsWith(AppRoutes.expenses),
            isDrawer: isDrawer,
          ),
          _buildNavItem(
            context: context,
            id: 'salaries',
            label: 'Staff Salaries',
            icon: Icons.account_balance_wallet_outlined,
            route: AppRoutes.salaries,
            isActive: activePath.startsWith(AppRoutes.salaries),
            isDrawer: isDrawer,
          ),
        ],
        _buildNavItem(
          context: context,
          id: 'reports',
          label: 'Reports & Analytics',
          icon: Icons.bar_chart_outlined,
          route: AppRoutes.reports,
          isActive: activePath.startsWith(AppRoutes.reports) || activePath.startsWith(AppRoutes.reportCards),
          isDrawer: isDrawer,
          key: const Key('drawer_report_cards_tile'),
        ),
        if (permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal)
          _buildNavItem(
            context: context,
            id: 'imports',
            label: 'Imports Wizard',
            icon: Icons.cloud_upload_outlined,
            route: AppRoutes.bulkImport,
            isActive: activePath.startsWith(AppRoutes.bulkImport),
            isDrawer: isDrawer,
          ),
        if (permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal)
          _buildNavItem(
            context: context,
            id: 'school-admin',
            label: 'School Administration',
            icon: Icons.account_balance_outlined,
            route: AppRoutes.schoolAdministration,
            isActive: activePath.startsWith(AppRoutes.schoolAdministration),
            isDrawer: isDrawer,
          ),
        if (permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal)
          _buildNavItem(
            context: context,
            id: 'school-setup',
            label: 'School Setup',
            icon: Icons.check_circle_outline,
            route: AppRoutes.schoolSetup,
            isActive: activePath.startsWith(AppRoutes.schoolSetup) || activePath.startsWith(AppRoutes.schools),
            progressBadge: '5/8',
            isDrawer: isDrawer,
          ),
        if (permissions.isSuperAdmin || permissions.isTenantAdmin || permissions.isPrincipal)
          _buildNavItem(
            context: context,
            id: 'roles',
            label: 'Roles & Permissions',
            icon: Icons.shield_outlined,
            route: AppRoutes.rolesPermissions,
            isActive: activePath.startsWith(AppRoutes.rolesPermissions),
            isDrawer: isDrawer,
          ),
        _buildNavItem(
          context: context,
          id: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          route: AppRoutes.settings,
          isActive: activePath.startsWith(AppRoutes.settings),
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSuperAdminSidebar(
    BuildContext context,
    String activePath,
    SchoolsListState schoolsState,
    TenantsListState tenantsState,
    UserEntity user, {
    bool isDrawer = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x25334155))),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0x3314B8A6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x662DD4BF)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5EEAD4)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'EduPulse AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'PLATFORM',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF5EEAD4),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Platform Administration',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDrawer)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'OVERVIEW',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
        ),
        _buildNavItem(
          context: context,
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          route: AppRoutes.dashboard,
          isActive: activePath == AppRoutes.dashboard,
          isDrawer: isDrawer,
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'SCHOOLS MANAGEMENT',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
        ),
        _buildNavItem(
          context: context,
          id: 'all-schools',
          label: 'All Schools',
          icon: Icons.business_outlined,
          route: AppRoutes.schools,
          isActive: activePath.startsWith(AppRoutes.schools),
          badge: schoolsState.schools.length.toString(),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'onboarding',
          label: 'Onboarding Pipeline',
          icon: Icons.flight_takeoff,
          route: AppRoutes.schoolOnboarding,
          isActive: activePath.startsWith(AppRoutes.schoolOnboarding),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'migrations',
          label: 'Data Migrations',
          icon: Icons.sync_alt_outlined,
          route: AppRoutes.migrations,
          isActive: activePath.startsWith(AppRoutes.migrations),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'school-admin',
          label: 'School Administration',
          icon: Icons.account_balance_outlined,
          route: AppRoutes.schoolAdministration,
          isActive: activePath.startsWith(AppRoutes.schoolAdministration),
          isDrawer: isDrawer,
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'USERS & ROLES',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
        ),
        _buildNavItem(
          context: context,
          id: 'tenants',
          label: 'Tenants Directory',
          icon: Icons.corporate_fare_rounded,
          route: AppRoutes.tenants,
          isActive: activePath.startsWith(AppRoutes.tenants),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'users',
          label: 'Platform Users',
          icon: Icons.people_outline,
          route: AppRoutes.users,
          isActive: activePath.startsWith(AppRoutes.users),
          isDrawer: isDrawer,
        ),
        _buildNavItem(
          context: context,
          id: 'roles',
          label: 'Roles & Permissions',
          icon: Icons.shield_outlined,
          route: AppRoutes.rolesPermissions,
          isActive: activePath.startsWith(AppRoutes.rolesPermissions),
          isDrawer: isDrawer,
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'GOVERNANCE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
        ),
        _buildNavItem(
          context: context,
          id: 'platform-reports',
          label: 'Platform Reports',
          icon: Icons.bar_chart_outlined,
          route: AppRoutes.reports,
          isActive: activePath.startsWith(AppRoutes.reports),
          isDrawer: isDrawer,
          key: const Key('drawer_report_cards_tile'),
        ),
        _buildNavItem(
          context: context,
          id: 'platform-settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          route: AppRoutes.settings,
          isActive: activePath.startsWith(AppRoutes.settings),
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Authenticated) {
        final user = next.user;
        final isSuper = user.isSuperuser ||
            user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN');

        if (isSuper) {
          ref.read(tenantsListProvider.notifier).fetchTenants();
        } else {
          final currentTenant = ref.read(selectedTenantIdProvider);
          if (currentTenant == null && user.tenantId != null && user.tenantId!.isNotEmpty) {
            ref.read(selectedTenantIdProvider.notifier).state = user.tenantId;
          }
        }
        ref.read(schoolsListProvider.notifier).fetchSchools();
        ref.read(notificationsStateProvider.notifier).fetchNotifications();
      } else if (next is Unauthenticated) {
        ref.read(selectedTenantIdProvider.notifier).state = null;
      }
    });

    if (authState is AuthInitial || authState is AuthLoading) {
      return Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading EduPulse...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authState is Unauthenticated) {
      return const Scaffold(
        body: SizedBox.shrink(),
      );
    }

    if (authState is AuthError) {
      return _buildAuthErrorRecoveryScreen(context, theme, authState);
    }

    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        final schools = ref.read(schoolsListProvider).schools;
        final match = schools.where((s) => s.id == next);
        if (match.isNotEmpty) {
          final tenantId = match.first.tenantId;
          if (tenantId.isNotEmpty && ref.read(selectedTenantIdProvider) != tenantId) {
            ref.read(selectedTenantIdProvider.notifier).state = tenantId;
          }
        }
      }
    });

    final isSuperAdmin = authState.user.isSuperuser ||
        authState.user.roles.any((r) => r.toUpperCase() == 'SUPER_ADMIN' || r.toUpperCase() == 'SYSTEM_ADMIN');

    final schoolsState = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final tenantsState = ref.watch(tenantsListProvider);
    final selectedTenantId = ref.watch(activeTenantIdProvider);

    ref.watch(tenantSetupWatcherProvider);

    final permissions = PortalPermissions.fromUser(authState.user);
    final isTenantAdmin = permissions.isTenantAdmin;

    final filteredSchools = schoolsState.schools.where((school) {
      if (isSuperAdmin || isTenantAdmin) return true;
      return authState.user.schools.contains(school.id);
    }).toList();

    final displaySchools = filteredSchools.isNotEmpty
        ? filteredSchools
        : (authState.user.schools.isNotEmpty
            ? authState.user.schools.map((id) => SchoolDto(
                id: id,
                name: authState.user.schoolNames[id] ?? 'Assigned School',
                code: '',
                board: '',
                schoolType: '',
                email: '',
                isActive: true,
                status: 'ACTIVE',
                tenantId: authState.user.tenantId ?? '',
                version: 1,
              )).toList()
            : <SchoolDto>[]);

    final adminName = authState.user.fullName;
    final activePath = GoRouterState.of(context).matchedLocation;
    final isDrawerMode = screenWidth < 960;
    final isMobile = screenWidth < 768;

    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final formattedDate = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    final selectedSchool = schoolsState.schools.where((s) => s.id == selectedSchoolId).firstOrNull;
    final hasContextBanner = isSuperAdmin && selectedSchoolId != null && selectedSchool != null;
    final hasStaleBanner = isSuperAdmin && selectedSchoolId != null && selectedSchool == null && !schoolsState.isLoading;
    final double totalHeaderHeight = 32.0 + ((hasContextBanner || hasStaleBanner) ? 38.0 : 0.0) + 64.0;

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(totalHeaderHeight),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          flexibleSpace: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopMicroBar(selectedSchool, displaySchools, formattedDate),
              if (hasContextBanner)
                _buildSuperAdminContextBanner(context, selectedSchool, schoolsState.schools)
              else if (hasStaleBanner)
                _buildStaleContextBanner(context),
              _buildMainHeaderBar(
                context,
                theme,
                timeGreeting,
                adminName,
                authState.user,
                isDrawerMode,
                isMobile,
                isSuperAdmin,
                isTenantAdmin,
                tenantsState,
                selectedTenantId,
                displaySchools,
                selectedSchoolId,
                screenWidth,
              ),
            ],
          ),
        ),
      ),
      drawer: isDrawerMode
          ? Drawer(
              backgroundColor: const Color(0xFF020617),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: isSuperAdmin && selectedSchoolId == null
                            ? _buildSuperAdminSidebar(context, activePath, schoolsState, tenantsState, authState.user, isDrawer: true)
                            : _buildAdminSidebar(context, activePath, selectedSchool, schoolsState, authState.user, permissions, isDrawer: true),
                      ),
                    ),
                    _buildSidebarProfileCard(context, authState.user, isDrawer: true),
                  ],
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isDrawerMode)
            Container(
              width: 256,
              decoration: const BoxDecoration(
                color: Color(0xFF020617),
                border: Border(
                  right: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: isSuperAdmin && selectedSchoolId == null
                          ? _buildSuperAdminSidebar(context, activePath, schoolsState, tenantsState, authState.user)
                          : _buildAdminSidebar(context, activePath, selectedSchool, schoolsState, authState.user, permissions),
                    ),
                  ),
                  _buildSidebarProfileCard(context, authState.user),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: EduPulseTheme.slate50,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchDestination {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String category;

  const _SearchDestination(this.title, this.subtitle, this.icon, this.route, [this.category = 'operations']);
}
