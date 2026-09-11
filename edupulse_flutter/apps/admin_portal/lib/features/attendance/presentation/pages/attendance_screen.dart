import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/portal_permissions.dart';
import '../providers/attendance_providers.dart';
import '../widgets/attendance_dashboard_view.dart';
import '../widgets/attendance_mark_view.dart';
import '../widgets/attendance_register_view.dart';
import '../widgets/attendance_upload_wizard.dart';
import '../widgets/attendance_imports_view.dart';
import '../widgets/attendance_audit_trail_view.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const AttendanceScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _tabCount;
  bool _canManageBulk = false;

  @override
  void initState() {
    super.initState();
    final permissions = ref.read(portalPermissionsProvider);
    _canManageBulk = permissions.canUploadAttendance;
    _tabCount = _canManageBulk ? 6 : 3;

    final safeInitialIndex = widget.initialTab.clamp(0, _tabCount - 1);
    _tabController = TabController(length: _tabCount, vsync: this, initialIndex: safeInitialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshActiveTab();
    });
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      final safeIndex = widget.initialTab.clamp(0, _tabCount - 1);
      if (_tabController.index != safeIndex) {
        _tabController.animateTo(safeIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshActiveTab() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
    ref.read(attendanceRegisterProvider.notifier).fetchRegister();
    if (_canManageBulk) {
      ref.read(attendanceImportsHistoryProvider.notifier).fetchHistory();
      ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to view attendance records.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final permissions = ref.watch(portalPermissionsProvider);
    final canManageBulkNow = permissions.canUploadAttendance;

    // If permissions changed during hot-reload or user switch, recreate tab controller
    if (canManageBulkNow != _canManageBulk) {
      _canManageBulk = canManageBulkNow;
      _tabCount = _canManageBulk ? 6 : 3;
      _tabController.dispose();
      _tabController = TabController(
        length: _tabCount,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, _tabCount - 1),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Screen Header & Refresh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: isDark ? Colors.grey[850]! : Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Management',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Campus-wide attendance monitoring, roster marking, bulk imports & audit trail.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('refresh_attendance_btn'),
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshActiveTab,
                  tooltip: 'Refresh All Attendance Data',
                ),
              ],
            ),
          ),

          // TabBar Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.grey[850]! : Colors.grey[200]!)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              tabs: [
                const Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 20),
                  text: 'Overview',
                ),
                const Tab(
                  icon: Icon(Icons.how_to_reg_outlined, size: 20),
                  text: 'Mark Attendance',
                ),
                const Tab(
                  icon: Icon(Icons.menu_book_outlined, size: 20),
                  text: 'Attendance Register',
                ),
                if (_canManageBulk) ...[
                  const Tab(
                    icon: Icon(Icons.upload_file_outlined, size: 20),
                    text: 'Bulk Upload',
                  ),
                  const Tab(
                    icon: Icon(Icons.history_outlined, size: 20),
                    text: 'Import History',
                  ),
                  const Tab(
                    icon: Icon(Icons.verified_user_outlined, size: 20),
                    text: 'Audit Trail',
                  ),
                ],
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const AttendanceDashboardView(),
                const AttendanceMarkView(),
                const AttendanceRegisterView(),
                if (_canManageBulk) ...[
                  AttendanceUploadWizard(
                    onNavigateToHistory: () => _tabController.animateTo(4),
                    onNavigateToRegister: () => _tabController.animateTo(2),
                  ),
                  const AttendanceImportsView(),
                  const AttendanceAuditTrailView(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
