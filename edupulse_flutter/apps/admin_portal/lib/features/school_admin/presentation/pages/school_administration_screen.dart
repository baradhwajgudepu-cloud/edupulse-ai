import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../data/models/school_admin_models.dart';
import '../providers/school_admin_providers.dart';
import '../widgets/document_upload_dialog.dart';
import '../widgets/document_replace_dialog.dart';
import '../widgets/document_preview_dialog.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';
import '../../../payroll/data/models/payroll_models.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';

class SchoolAdministrationScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final int? initialPayrollMonth;
  final int? initialPayrollYear;

  const SchoolAdministrationScreen({
    super.key,
    this.initialTab = 0,
    this.initialPayrollMonth,
    this.initialPayrollYear,
  });

  @override
  ConsumerState<SchoolAdministrationScreen> createState() =>
      _SchoolAdministrationScreenState();
}

class _SchoolAdministrationScreenState
    extends ConsumerState<SchoolAdministrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected Month/Year for Payroll Tab
  late int _selectedPayrollMonth;
  late int _selectedPayrollYear;

  // Document Vault Category Filter
  String _selectedDocCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _selectedPayrollMonth = widget.initialPayrollMonth ?? DateTime.now().month;
    _selectedPayrollYear = widget.initialPayrollYear ?? DateTime.now().year;
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 7),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);

    if (schoolId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_outlined,
                  size: 64, color: Colors.blueGrey[300]),
              const SizedBox(height: 16),
              Text(
                'Please select an active school campus to access Administration & Compliance.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.blueGrey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeaderBar(context, schoolId),
          _buildTabBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(schoolId: schoolId, onNavigateToTab: (index) {
                  _tabController.animateTo(index);
                }),
                _SchoolInformationTab(schoolId: schoolId),
                _GovernmentComplianceTab(schoolId: schoolId),
                _RecognitionAffiliationTab(schoolId: schoolId),
                _InfrastructureTab(schoolId: schoolId),
                _DocumentVaultTab(
                  schoolId: schoolId,
                  selectedCategory: _selectedDocCategory,
                  onCategoryChanged: (cat) => setState(() => _selectedDocCategory = cat),
                ),
                _AttendancePayrollTab(
                  schoolId: schoolId,
                  month: _selectedPayrollMonth,
                  year: _selectedPayrollYear,
                  onPeriodChanged: (m, y) => setState(() {
                    _selectedPayrollMonth = m;
                    _selectedPayrollYear = y;
                  }),
                ),
                _AuditLogsTab(schoolId: schoolId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, String schoolId) {
    final schoolAsync = ref.watch(schoolDetailProvider(schoolId));
    final schoolName = schoolAsync.value?.name ?? 'School Administration';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Icon(Icons.account_balance_outlined,
                color: Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'School Administration & Compliance Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text(
                        'OS v2.0 • Compliance Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  schoolName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(schoolProfileProvider(schoolId));
              ref.invalidate(complianceDashboardProvider(schoolId));
              ref.invalidate(schoolRecognitionsProvider(schoolId));
              ref.invalidate(schoolDocumentsProvider(schoolId));
              ref.invalidate(payrollPoliciesProvider(schoolId));
              ref.invalidate(teacherPayrollProfilesProvider(schoolId));
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF4F46E5),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF4F46E5),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
          Tab(icon: Icon(Icons.info_outline, size: 18), text: 'School Information'),
          Tab(icon: Icon(Icons.verified_user_outlined, size: 18), text: 'Gov & Compliance'),
          Tab(icon: Icon(Icons.workspace_premium_outlined, size: 18), text: 'Recognition'),
          Tab(icon: Icon(Icons.apartment_outlined, size: 18), text: 'Infrastructure'),
          Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'Documents Vault'),
          Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Attendance Payroll'),
          Tab(icon: Icon(Icons.history_outlined, size: 18), text: 'Audit Logs'),
        ],
      ),
    );
  }
}

// =============================================================
// REUSABLE TAB ERROR HANDLER
// =============================================================

Widget _buildAdminTabError({
  required BuildContext context,
  required String title,
  required Object error,
  required VoidCallback onRetry,
}) {
  return Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE2E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString().replaceAll('Exception: ', '').replaceAll('HTTP 500', 'Server temporary error'),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// TAB 1: OVERVIEW
// =============================================================

class _OverviewTab extends ConsumerWidget {
  final String schoolId;
  final ValueChanged<int> onNavigateToTab;

  const _OverviewTab({required this.schoolId, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compAsync = ref.watch(complianceDashboardProvider(schoolId));

    return compAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load Compliance Overview',
        error: err,
        onRetry: () => ref.invalidate(complianceDashboardProvider(schoolId)),
      ),
      data: (comp) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metric cards grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final int cols = width >= 1200 ? 4 : (width >= 680 ? 2 : 1);
                  final double aspectRatio = cols == 4
                      ? 1.42
                      : (cols == 2 ? 2.2 : 3.0);
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                    children: [
                      _buildMetricCard(
                        title: 'UDISE+ Identifier',
                        value: comp.udiseConfigured ? (comp.udiseCode ?? 'Configured') : 'Not Set',
                        statusBadge: comp.udiseVerificationStatus,
                        statusColor: comp.udiseVerificationStatus == 'VERIFIED'
                            ? const Color(0xFF10B981)
                            : (comp.udiseConfigured ? Colors.amber : const Color(0xFFE11D48)),
                        icon: Icons.fingerprint,
                        actionLabel: 'Verify UDISE+',
                        onAction: () => onNavigateToTab(2),
                      ),
                      _buildMetricCard(
                        title: 'Active Recognitions',
                        value: '${comp.activeRecognitions} Active',
                        subtitle: '${comp.centralRecognitionsCount} Central • ${comp.stateRecognitionsCount} State',
                        icon: Icons.workspace_premium_outlined,
                        actionLabel: 'Manage Recognitions',
                        onAction: () => onNavigateToTab(3),
                      ),
                      _buildMetricCard(
                        title: 'Document Vault',
                        value: '${comp.totalDocuments} Records',
                        subtitle: comp.expiringDocumentsCount > 0
                            ? '⚠ ${comp.expiringDocumentsCount} Expiring Soon'
                            : 'All documents valid',
                        statusColor: comp.expiringDocumentsCount > 0 ? Colors.amber : Colors.teal,
                        icon: Icons.lock_outline,
                        actionLabel: 'View Documents',
                        onAction: () => onNavigateToTab(5),
                      ),
                      _buildMetricCard(
                        title: 'Payroll Readiness',
                        value: comp.payrollReady ? 'Engine Ready' : 'Setup Required',
                        subtitle: '${comp.teachersCount} Faculty • ${comp.approvedPayrollCount} Approved',
                        statusColor: comp.payrollReady ? Colors.indigo : Colors.orange,
                        icon: Icons.payments_outlined,
                        actionLabel: 'Run Payroll',
                        onAction: () => onNavigateToTab(6),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Compliance Health summary banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Color(0xFF4F46E5), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Institutional Governance & Compliance Health',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Institutional parameters, regulatory recognitions, document crypt-vault, and attendance-based teacher payroll are fully synchronized. All modifications are logged with multi-tenant audit verification.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fast Actions Grid
              const Text(
                'Administration Shortcuts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildShortcutChip('Edit Profile Information', Icons.info_outline, () => onNavigateToTab(1)),
                  _buildShortcutChip('Verify UDISE+ Registry', Icons.verified_outlined, () => onNavigateToTab(2)),
                  _buildShortcutChip('Add Board Recognition', Icons.add_circle_outline, () => onNavigateToTab(3)),
                  _buildShortcutChip('Infrastructure & Facilities', Icons.apartment_outlined, () => onNavigateToTab(4)),
                  _buildShortcutChip('Upload Official Document', Icons.cloud_upload_outlined, () => onNavigateToTab(5)),
                  _buildShortcutChip('Calculate Monthly Payroll', Icons.calculate_outlined, () => onNavigateToTab(6)),
                  _buildShortcutChip('View Access & Audit Logs', Icons.history_outlined, () => onNavigateToTab(7)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    String? statusBadge,
    Color? statusColor,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Icon(icon, color: const Color(0xFF6366F1), size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor ?? const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (statusBadge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (statusColor ?? Colors.blue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor ?? Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          InkWell(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
      label: Text(label),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }
}

// =============================================================
// TAB 2: SCHOOL INFORMATION
// =============================================================

class _SchoolInformationTab extends ConsumerStatefulWidget {
  final String schoolId;
  const _SchoolInformationTab({required this.schoolId});

  @override
  ConsumerState<_SchoolInformationTab> createState() =>
      _SchoolInformationTabState();
}

class _SchoolInformationTabState extends ConsumerState<_SchoolInformationTab> {
  final _formKey = GlobalKey<FormState>();

  final _categoryController = TextEditingController();
  final _managementController = TextEditingController();
  final _levelController = TextEditingController();
  final _establishedYearController = TextEditingController();
  final _mediumController = TextEditingController();
  final _mottoController = TextEditingController();
  final _photoUrlController = TextEditingController();

  final _correspondentController = TextEditingController();
  final _headmasterController = TextEditingController();
  final _mgmtContactController = TextEditingController();
  final _emergContactController = TextEditingController();
  final _schoolHoursController = TextEditingController();
  final _officeHoursController = TextEditingController();
  final _assemblyController = TextEditingController();
  final _lunchController = TextEditingController();

  String _genderType = 'Co-Education';
  String _minorityStatus = 'Non-Minority';
  String _areaType = 'Urban';

  bool _isInitialized = false;

  void _populateForm(SchoolProfileDto profile) {
    if (_isInitialized) return;
    _isInitialized = true;
    _categoryController.text = profile.schoolCategory ?? '';
    _managementController.text = profile.managementType ?? '';
    _levelController.text = profile.schoolLevel ?? '';
    _establishedYearController.text = profile.establishedYear?.toString() ?? '';
    _mediumController.text = profile.mediumOfInstruction;
    _mottoController.text = profile.schoolMotto ?? '';
    _photoUrlController.text = profile.schoolPhotoUrl ?? '';

    _correspondentController.text = profile.correspondentName ?? '';
    _headmasterController.text = profile.headmasterName ?? '';
    _mgmtContactController.text = profile.managementContact ?? '';
    _emergContactController.text = profile.emergencyContact ?? '';
    _schoolHoursController.text = profile.schoolWorkingHours ?? '08:30 AM - 04:00 PM';
    _officeHoursController.text = profile.officeWorkingHours ?? '09:00 AM - 05:00 PM';
    _assemblyController.text = profile.morningAssemblyTime ?? '08:45 AM';
    _lunchController.text = profile.lunchTime ?? '12:30 PM - 01:15 PM';

    _genderType = profile.genderType;
    _minorityStatus = profile.minorityStatus;
    _areaType = profile.areaType;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _managementController.dispose();
    _levelController.dispose();
    _establishedYearController.dispose();
    _mediumController.dispose();
    _mottoController.dispose();
    _photoUrlController.dispose();
    _correspondentController.dispose();
    _headmasterController.dispose();
    _mgmtContactController.dispose();
    _emergContactController.dispose();
    _schoolHoursController.dispose();
    _officeHoursController.dispose();
    _assemblyController.dispose();
    _lunchController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'school_category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      'management_type': _managementController.text.trim().isEmpty ? null : _managementController.text.trim(),
      'school_level': _levelController.text.trim().isEmpty ? null : _levelController.text.trim(),
      'established_year': int.tryParse(_establishedYearController.text.trim()),
      'medium_of_instruction': _mediumController.text.trim().isEmpty ? 'English' : _mediumController.text.trim(),
      'gender_type': _genderType,
      'minority_status': _minorityStatus,
      'area_type': _areaType,
      'school_motto': _mottoController.text.trim().isEmpty ? null : _mottoController.text.trim(),
      'school_photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'correspondent_name': _correspondentController.text.trim().isEmpty ? null : _correspondentController.text.trim(),
      'headmaster_name': _headmasterController.text.trim().isEmpty ? null : _headmasterController.text.trim(),
      'management_contact': _mgmtContactController.text.trim().isEmpty ? null : _mgmtContactController.text.trim(),
      'emergency_contact': _emergContactController.text.trim().isEmpty ? null : _emergContactController.text.trim(),
      'school_working_hours': _schoolHoursController.text.trim(),
      'office_working_hours': _officeHoursController.text.trim(),
      'morning_assembly_time': _assemblyController.text.trim(),
      'lunch_time': _lunchController.text.trim(),
    };

    final ok = await ref.read(schoolAdminActionProvider.notifier).updateProfile(widget.schoolId, data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'School Profile updated successfully!' : 'Failed to save changes.'),
          backgroundColor: ok ? Colors.green[700] : Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(schoolProfileProvider(widget.schoolId));
    final actionState = ref.watch(schoolAdminActionProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load School Profile',
        error: err,
        onRetry: () => ref.invalidate(schoolProfileProvider(widget.schoolId)),
      ),
      data: (prof) {
        _populateForm(prof);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Institution Classification & Identity', Icons.school_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'School Category',
                            hintText: 'e.g. Co-Educational Day & Residential',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _managementController,
                          decoration: const InputDecoration(
                            labelText: 'Management Type',
                            hintText: 'e.g. Model School Society / Unaided Private',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _levelController,
                          decoration: const InputDecoration(
                            labelText: 'School Level',
                            hintText: 'e.g. Primary to Senior Secondary (Grades 1-12)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _establishedYearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Established Year',
                            hintText: 'e.g. 2012',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mediumController,
                          decoration: const InputDecoration(
                            labelText: 'Medium of Instruction',
                            hintText: 'e.g. English / Telugu',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SafeDropdownButtonFormField<String>(
                          value: _genderType,
                          decoration: const InputDecoration(labelText: 'Gender Pattern'),
                          items: const [
                            DropdownMenuItem(value: 'Co-Education', child: Text('Co-Education')),
                            DropdownMenuItem(value: 'Boys Only', child: Text('Boys Only')),
                            DropdownMenuItem(value: 'Girls Only', child: Text('Girls Only')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _genderType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SafeDropdownButtonFormField<String>(
                          value: _minorityStatus,
                          decoration: const InputDecoration(labelText: 'Minority Status'),
                          items: const [
                            DropdownMenuItem(value: 'Non-Minority', child: Text('Non-Minority')),
                            DropdownMenuItem(value: 'Linguistic Minority', child: Text('Linguistic Minority')),
                            DropdownMenuItem(value: 'Religious Minority', child: Text('Religious Minority')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _minorityStatus = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SafeDropdownButtonFormField<String>(
                          value: _areaType,
                          decoration: const InputDecoration(labelText: 'Area / Region Type'),
                          items: const [
                            DropdownMenuItem(value: 'Urban', child: Text('Urban')),
                            DropdownMenuItem(value: 'Semi-Urban', child: Text('Semi-Urban')),
                            DropdownMenuItem(value: 'Rural', child: Text('Rural')),
                            DropdownMenuItem(value: 'Tribal', child: Text('Tribal')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _areaType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mottoController,
                    decoration: const InputDecoration(
                      labelText: 'School Motto / Vision Statement',
                      hintText: 'e.g. Lead Kindly Light',
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionHeader('Key Contacts & Administration Staff', Icons.badge_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _correspondentController,
                          decoration: const InputDecoration(
                            labelText: 'Correspondent / Secretary Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _headmasterController,
                          decoration: const InputDecoration(
                            labelText: 'Headmaster / Vice Principal Name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mgmtContactController,
                          decoration: const InputDecoration(
                            labelText: 'Management Office Phone / Email',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emergContactController,
                          decoration: const InputDecoration(
                            labelText: 'Campus Emergency Contact Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionHeader('Operational Working Hours & Bells', Icons.schedule_outlined),
                const SizedBox(height: 12),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _schoolHoursController,
                          decoration: const InputDecoration(
                            labelText: 'School Operating Hours',
                            hintText: 'e.g. 08:30 AM - 04:00 PM',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _officeHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Administrative Office Hours',
                            hintText: 'e.g. 09:00 AM - 05:00 PM',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _assemblyController,
                          decoration: const InputDecoration(
                            labelText: 'Morning Assembly Bell',
                            hintText: 'e.g. 08:45 AM',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lunchController,
                          decoration: const InputDecoration(
                            labelText: 'Lunch Break Interval',
                            hintText: 'e.g. 12:30 PM - 01:15 PM',
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 24),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: actionState.isLoading ? null : _saveForm,
                    icon: actionState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Save School Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// =============================================================
// TAB 3: GOVERNMENT & COMPLIANCE (UDISE+)
// =============================================================

class _GovernmentComplianceTab extends ConsumerWidget {
  final String schoolId;
  const _GovernmentComplianceTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(schoolProfileProvider(schoolId));

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load UDISE+ Government Compliance Data',
        error: err,
        onRetry: () => ref.invalidate(schoolProfileProvider(schoolId)),
      ),
      data: (prof) {
        final isVerified = prof.udiseVerificationStatus == 'VERIFIED';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // UDISE+ Official Registry Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isVerified ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    width: isVerified ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isVerified ? Icons.verified : Icons.warning_amber_rounded,
                                color: isVerified
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unified District Information System for Education (UDISE+)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Ministry of Education, Government of India Educational Registry',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _buildStatusBadge(prof.udiseVerificationStatus),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Official UDISE+ Code',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(
                                prof.udiseCode ?? 'Not Configured in Campus Profile',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Verification Timestamp',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(
                                prof.udiseVerifiedAt != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(prof.udiseVerifiedAt!)
                                    : 'Awaiting Administrator Review',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Verified By',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(
                                prof.udiseVerifiedByName ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (prof.udiseNotes != null && prof.udiseNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notes, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verification Notes: ${prof.udiseNotes}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showVerifyDialog(context, ref, schoolId, isVerified: false),
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                          label: const Text('Mark Rejected / Unverified', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECDD3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showVerifyDialog(context, ref, schoolId, isVerified: true),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Verify & Confirm UDISE+ Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mandatory Government Compliance Checklist
              const Text(
                'Statutory Regulatory Compliance Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _buildComplianceCheckItem(
                'Right to Education (RTE) Norms',
                'Compliant pupil-teacher ratio, infrastructure norms, and non-discrimination mandates.',
                true,
              ),
              _buildComplianceCheckItem(
                'Fire Safety & Evacuation Certification',
                'Periodic inspection by State Disaster Response and Fire Services Department.',
                prof.hasFireSafety,
              ),
              _buildComplianceCheckItem(
                'Safe Drinking Water & Sanitary Conditions',
                'Bacteriological water testing and adequate student hygiene sanitation facilities.',
                prof.hasWaterSanitation,
              ),
              _buildComplianceCheckItem(
                'Building Structural Safety & Fitness',
                'P.W.D. / Municipal certified structural stability of campus classrooms.',
                true,
              ),
              _buildComplianceCheckItem(
                'Barrier-Free Disability Access (Ramps)',
                'Dedicated wheelchair accessibility ramps across ground-floor academic halls.',
                prof.hasAccessibilityRamps,
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    String label = status;

    if (status == 'VERIFIED') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
      label = '✓ VERIFIED OFFICIAL';
    } else if (status == 'PENDING_REVIEW') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'PENDING REVIEW';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
      label = 'VERIFICATION REJECTED';
    } else {
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF64748B);
      label = 'UNVERIFIED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  static Widget _buildComplianceCheckItem(String title, String desc, bool isCompliant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            isCompliant ? Icons.check_circle : Icons.cancel_outlined,
            color: isCompliant ? const Color(0xFF059669) : const Color(0xFFE11D48),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCompliant ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isCompliant ? 'COMPLIANT' : 'ATTENTION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCompliant ? const Color(0xFF047857) : const Color(0xFFBE123C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showVerifyDialog(BuildContext context, WidgetRef ref, String schoolId, {required bool isVerified}) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVerified ? 'Confirm Official UDISE+ Code' : 'Mark UDISE+ Code as Unverified / Rejected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVerified
                  ? 'Are you sure this UDISE+ number matches the government school educational records?'
                  : 'Document why this UDISE+ code is being flagged or rejected:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Audit & Verification Remarks',
                hintText: 'e.g. Cross-referenced with Telangana MIS portal',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isVerified ? const Color(0xFF059669) : Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(schoolAdminActionProvider.notifier).verifyUdise(
                    schoolId,
                    isVerified,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
            },
            child: Text(isVerified ? 'Confirm Verification' : 'Reject'),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// TAB 4: RECOGNITION & AFFILIATION
// =============================================================

class _RecognitionAffiliationTab extends ConsumerWidget {
  final String schoolId;
  const _RecognitionAffiliationTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(schoolRecognitionsProvider(schoolId));

    return recsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load Recognition Records',
        error: err,
        onRetry: () => ref.invalidate(schoolRecognitionsProvider(schoolId)),
      ),
      data: (recs) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Governing Board & State Recognition Records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Separate multi-record tracking for Central and State statutory education authorities.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRecognitionDialog(context, ref, schoolId),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Recognition Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (recs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 48, color: Colors.blueGrey[300]),
                      const SizedBox(height: 12),
                      const Text(
                        'No recognition records added yet.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add CBSE, ICSE, or Telangana State Department recognition details above.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final r = recs[idx];
                    final isCentral = r.authorityLevel == 'CENTRAL';

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCentral ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isCentral ? const Color(0xFFBFDBFE) : const Color(0xFFDDD6FE),
                                      ),
                                    ),
                                    child: Text(
                                      isCentral ? 'CENTRAL AUTHORITY' : 'STATE AUTHORITY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isCentral ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      r.recognitionType,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete record',
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Recognition Record'),
                                      content: Text('Are you sure you want to delete ${r.authorityName}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    ref.read(schoolAdminActionProvider.notifier).deleteRecognition(schoolId, r.id);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            r.authorityName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 32,
                            runSpacing: 12,
                            children: [
                              _buildInfoPair('Affiliation / Rec Number', r.recognitionNumber),
                              if (r.proceedingsOrderNumber != null)
                                _buildInfoPair('Proceedings Order', r.proceedingsOrderNumber!),
                              if (r.certificateNumber != null)
                                _buildInfoPair('Certificate Number', r.certificateNumber!),
                              if (r.validFrom != null && r.validUntil != null)
                                _buildInfoPair('Validity Term', '${r.validFrom} to ${r.validUntil}')
                              else
                                _buildInfoPair('Status', r.status),
                            ],
                          ),
                          if (r.remarks != null && r.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Remarks: ${r.remarks}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildInfoPair(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      ],
    );
  }

  static void _showAddRecognitionDialog(BuildContext context, WidgetRef ref, String schoolId) {
    String authLevel = 'STATE';
    String recType = 'RECOGNITION';
    final nameCtrl = TextEditingController(text: 'Telangana Directorate of School Education');
    final numCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final fromCtrl = TextEditingController(text: '2024-06-01');
    final untilCtrl = TextEditingController(text: '2029-05-31');
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add School Recognition / Affiliation'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SafeDropdownButtonFormField<String>(
                          value: authLevel,
                          decoration: const InputDecoration(labelText: 'Authority Level'),
                          items: const [
                            DropdownMenuItem(value: 'CENTRAL', child: Text('Central Authority (CBSE, ICSE)')),
                            DropdownMenuItem(value: 'STATE', child: Text('State Authority (Telangana DSE)')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other Statutory Board')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                authLevel = val;
                                if (val == 'CENTRAL') {
                                  nameCtrl.text = 'Central Board of Secondary Education (CBSE)';
                                  recType = 'AFFILIATION';
                                } else {
                                  nameCtrl.text = 'Telangana Directorate of School Education';
                                  recType = 'RECOGNITION';
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SafeDropdownButtonFormField<String>(
                          value: recType,
                          decoration: const InputDecoration(labelText: 'Recognition Type'),
                          items: const [
                            DropdownMenuItem(value: 'AFFILIATION', child: Text('Affiliation')),
                            DropdownMenuItem(value: 'RECOGNITION', child: Text('Recognition Order')),
                            DropdownMenuItem(value: 'NOC', child: Text('No Objection Cert (NOC)')),
                            DropdownMenuItem(value: 'REGISTRATION', child: Text('Registration')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => recType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Authority Name')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Recognition / Affiliation No *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Certificate No (Optional)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'Valid From (YYYY-MM-DD)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: untilCtrl, decoration: const InputDecoration(labelText: 'Valid Until (YYYY-MM-DD)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              onPressed: () async {
                if (numCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ref.read(schoolAdminActionProvider.notifier).createRecognition(schoolId, {
                  'authority_level': authLevel,
                  'authority_name': nameCtrl.text.trim(),
                  'recognition_type': recType,
                  'recognition_number': numCtrl.text.trim(),
                  'certificate_number': certCtrl.text.trim().isEmpty ? null : certCtrl.text.trim(),
                  'valid_from': fromCtrl.text.trim().isEmpty ? null : fromCtrl.text.trim(),
                  'valid_until': untilCtrl.text.trim().isEmpty ? null : untilCtrl.text.trim(),
                  'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                  'status': 'ACTIVE',
                });
              },
              child: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// TAB 5: INFRASTRUCTURE & FACILITIES
// =============================================================

class _InfrastructureTab extends ConsumerStatefulWidget {
  final String schoolId;
  const _InfrastructureTab({required this.schoolId});

  @override
  ConsumerState<_InfrastructureTab> createState() => _InfrastructureTabState();
}

class _InfrastructureTabState extends ConsumerState<_InfrastructureTab> {
  final _capCtrl = TextEditingController();
  final _currCapCtrl = TextEditingController();
  final _secCtrl = TextEditingController();

  bool _transport = false;
  bool _hostel = false;
  bool _library = true;
  bool _laboratory = true;
  bool _sports = true;
  bool _smartClass = false;
  bool _computerLab = true;
  bool _medical = false;
  bool _cctv = false;
  bool _fireSafety = false;
  bool _waterSanitation = true;
  bool _backup = false;
  bool _ramps = false;

  bool _initialized = false;

  void _populate(SchoolProfileDto p) {
    if (_initialized) return;
    _initialized = true;
    _capCtrl.text = p.totalCapacity.toString();
    _currCapCtrl.text = p.currentCapacity.toString();
    _secCtrl.text = p.totalSectionsCount.toString();

    _transport = p.hasTransport;
    _hostel = p.hasHostel;
    _library = p.hasLibrary;
    _laboratory = p.hasLaboratory;
    _sports = p.hasSportsFacilities;
    _smartClass = p.hasSmartClassrooms;
    _computerLab = p.hasComputerLab;
    _medical = p.hasMedicalRoom;
    _cctv = p.hasCctv;
    _fireSafety = p.hasFireSafety;
    _waterSanitation = p.hasWaterSanitation;
    _backup = p.hasElectricityBackup;
    _ramps = p.hasAccessibilityRamps;
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    _currCapCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final data = {
      'total_capacity': int.tryParse(_capCtrl.text) ?? 1000,
      'current_capacity': int.tryParse(_currCapCtrl.text) ?? 0,
      'total_sections_count': int.tryParse(_secCtrl.text) ?? 0,
      'has_transport': _transport,
      'has_hostel': _hostel,
      'has_library': _library,
      'has_laboratory': _laboratory,
      'has_sports_facilities': _sports,
      'has_smart_classrooms': _smartClass,
      'has_computer_lab': _computerLab,
      'has_medical_room': _medical,
      'has_cctv': _cctv,
      'has_fire_safety': _fireSafety,
      'has_water_sanitation': _waterSanitation,
      'has_electricity_backup': _backup,
      'has_accessibility_ramps': _ramps,
    };

    final ok = await ref.read(schoolAdminActionProvider.notifier).updateProfile(widget.schoolId, data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Infrastructure indicators updated!' : 'Failed to update.'),
          backgroundColor: ok ? Colors.green[700] : Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(schoolProfileProvider(widget.schoolId));

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load Infrastructure Data',
        error: err,
        onRetry: () => ref.invalidate(schoolProfileProvider(widget.schoolId)),
      ),
      data: (p) {
        _populate(p);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campus Capacities & Infrastructure Audit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _capCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maximum Student Capacity'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _currCapCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Current Active Enrollment'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _secCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Class Sections Count'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Facility & Safety Audit Toggles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSwitch('Library & Reading Rooms', _library, (v) => setState(() => _library = v)),
                    _buildSwitch('Composite Science Laboratory', _laboratory, (v) => setState(() => _laboratory = v)),
                    _buildSwitch('Computer Information Technology Lab', _computerLab, (v) => setState(() => _computerLab = v)),
                    _buildSwitch('Smart Interactive Classrooms', _smartClass, (v) => setState(() => _smartClass = v)),
                    _buildSwitch('Playground & Sports Facilities', _sports, (v) => setState(() => _sports = v)),
                    _buildSwitch('Medical & First-Aid Room', _medical, (v) => setState(() => _medical = v)),
                    _buildSwitch('CCTV Surveillance System', _cctv, (v) => setState(() => _cctv = v)),
                    _buildSwitch('Fire Safety Cert & Extinguishers', _fireSafety, (v) => setState(() => _fireSafety = v)),
                    _buildSwitch('Purified Water & Sanitation Facilities', _waterSanitation, (v) => setState(() => _waterSanitation = v)),
                    _buildSwitch('Electricity Generator / Solar Backup', _backup, (v) => setState(() => _backup = v)),
                    _buildSwitch('Barrier-Free Wheelchair Ramps', _ramps, (v) => setState(() => _ramps = v)),
                    _buildSwitch('School Bus / Fleet Transport Available', _transport, (v) => setState(() => _transport = v)),
                    _buildSwitch('Hostel / Boarding Facility Available', _hostel, (v) => setState(() => _hostel = v)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Infrastructure Configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitch(String title, bool val, ValueChanged<bool> onChange) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      value: val,
      activeThumbColor: const Color(0xFF4F46E5),
      onChanged: onChange,
    );
  }
}

// =============================================================
// TAB 6: DOCUMENTS VAULT
// =============================================================

class _DocumentVaultTab extends ConsumerWidget {
  final String schoolId;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const _DocumentVaultTab({
    required this.schoolId,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(schoolDocumentsProvider(schoolId));
    final expiryAsync = ref.watch(documentExpiryMonitorProvider(schoolId));

    final categories = [
      'ALL', 'GOVERNMENT', 'RECOGNITION', 'AFFILIATION', 'CERTIFICATE',
      'FIRE_SAFETY', 'BUILDING', 'STAFF', 'FINANCIAL', 'OTHER'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institutional Documents & Secure Vault',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Multi-tier confidentiality repository with salted PBKDF2 encryption & audit tracking.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showUploadDialog(context, ref, schoolId),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Upload Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Expiry Monitor Alerts Banner
          expiryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (exp) {
              if (exp.alerts.isEmpty && exp.missingMandatoryCategories.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'AI Compliance & Expiry Alerts (${exp.alerts.length} upcoming/expired renewals)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...exp.alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• ${a.title}: ${a.recommendedAction}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                          ),
                        )),
                    if (exp.missingMandatoryCategories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Missing Mandatory Certificates: ${exp.missingMandatoryCategories.join(', ')}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.replaceAll('_', ' ')),
                    selected: isSelected,
                    selectedColor: const Color(0xFFEEF2FF),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF818CF8) : const Color(0xFFCBD5E1),
                    ),
                    onSelected: (_) => onCategoryChanged(cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Document List
          docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _buildAdminTabError(
              context: context,
              title: 'Unable to Load Document Vault',
              error: err,
              onRetry: () => ref.invalidate(schoolDocumentsProvider(schoolId)),
            ),
            data: (docs) {
              final filtered = selectedCategory == 'ALL'
                  ? docs
                  : docs.where((d) => d.category == selectedCategory).toList();

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('No documents found in this category.'),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final doc = filtered[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Leading Icon Container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: doc.isPasswordProtected
                                ? const Color(0xFFFFF1F2)
                                : (doc.isPdf
                                    ? const Color(0xFFFEE2E2)
                                    : (doc.isImage ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9))),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            doc.isPasswordProtected
                                ? Icons.lock
                                : (doc.isPdf
                                    ? Icons.picture_as_pdf
                                    : (doc.isImage ? Icons.image : Icons.description_outlined)),
                            color: doc.isPasswordProtected
                                ? const Color(0xFFE11D48)
                                : (doc.isPdf
                                    ? const Color(0xFFDC2626)
                                    : (doc.isImage ? const Color(0xFF4F46E5) : const Color(0xFF475569))),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title, Badges, Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    doc.title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      doc.category.replaceAll('_', ' '),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                    ),
                                  ),
                                  if (doc.isPasswordProtected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFECDD3)),
                                      ),
                                      child: const Text(
                                        'PROTECTED',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFE11D48)),
                                      ),
                                    ),
                                  if (doc.isExpiringSoon && !doc.isExpired)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'EXPIRES IN ${doc.daysUntilExpiry} DAYS',
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                      ),
                                    ),
                                  if (doc.isExpired)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'EXPIRED',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  if (doc.hasFile)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        doc.isPdf ? 'PDF' : (doc.isImage ? 'IMAGE' : 'FILE'),
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NO FILE ATTACHED',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${doc.fileName} • ${doc.hasFile ? doc.formattedFileSize : '0 B'} • Doc #${doc.documentNumber ?? 'N/A'}${doc.issuingAuthority != null ? ' • Issued by ${doc.issuingAuthority}' : ''}${doc.issueDate != null ? ' • Issue Date: ${doc.issueDate}' : ''}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showPreviewDialog(context, ref, schoolId, doc),
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: Text(doc.isPasswordProtected ? 'Unlock & View' : 'View'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _handleDirectDownload(context, ref, doc),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showReplaceDialog(context, ref, schoolId, doc),
                              icon: const Icon(Icons.sync_alt, size: 16),
                              label: Text(doc.hasFile ? 'Replace File' : 'Upload File'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              tooltip: 'Archive Document',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    title: const Text('Archive Document?'),
                                    content: Text('Are you sure you want to archive "${doc.title}"? It can be retrieved from archive later.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () {
                                          Navigator.pop(dlgCtx);
                                          ref.read(schoolAdminActionProvider.notifier).deleteDocument(schoolId, doc.id);
                                        },
                                        child: const Text('Archive'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static void _showUploadDialog(BuildContext context, WidgetRef ref, String schoolId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentUploadDialog(schoolId: schoolId),
    );
  }

  static void _showReplaceDialog(BuildContext context, WidgetRef ref, String schoolId, SchoolDocumentDto doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentReplaceDialog(schoolId: schoolId, document: doc),
    );
  }

  static void _showPreviewDialog(BuildContext context, WidgetRef ref, String schoolId, SchoolDocumentDto doc) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentPreviewDialog(schoolId: schoolId, document: doc),
    );
  }

  static void _handleDirectDownload(BuildContext context, WidgetRef ref, SchoolDocumentDto doc) async {
    if (doc.isPasswordProtected) {
      _showPreviewDialog(context, ref, doc.schoolId, doc);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${doc.fileName}...')),
    );

    final bytes = await ref.read(schoolAdminActionProvider.notifier).fetchDocumentBytes(
      documentId: doc.id,
      inline: false,
    );

    if (bytes != null) {
      downloadBinaryFile(doc.fileName, bytes, mimeType: doc.contentType);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${doc.fileName}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download document file from vault.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// =============================================================
// TAB 7: ATTENDANCE-BASED PAYROLL
// =============================================================

class _AttendancePayrollTab extends ConsumerWidget {
  final String schoolId;
  final int month;
  final int year;
  final void Function(int month, int year) onPeriodChanged;

  const _AttendancePayrollTab({
    required this.schoolId,
    required this.month,
    required this.year,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodKey = PayrollPeriodKey(schoolId: schoolId, month: month, year: year);
    final summaryAsync = ref.watch(monthlyPayrollSummaryProvider(periodKey));
    final policyAsync = ref.watch(payrollPoliciesProvider(schoolId));
    final actionState = ref.watch(payrollActionProvider);

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance-Based Teacher Payroll Engine',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Automated policy calculation mapping biometric and recorded attendance to statutory salary disbursement.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Period Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Color(0xFF4F46E5), size: 20),
                  const SizedBox(width: 10),
                  const Text('Payroll Period:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: month,
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(value: i + 1, child: Text(monthNames[i])),
                    ),
                    onChanged: (m) {
                      if (m != null) onPeriodChanged(m, year);
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: year,
                    underline: const SizedBox.shrink(),
                    items: [2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (y) {
                      if (y != null) onPeriodChanged(month, y);
                    },
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : () {
                            ref.invalidate(monthlyPayrollSummaryProvider(periodKey));
                          },
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Re-Calculate Attendance Payroll'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Policy Info Card
          policyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (policies) {
              final pol = policies.isNotEmpty ? policies.first : null;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rule_folder_outlined, color: Color(0xFF4F46E5), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pol != null ? pol.policyName : 'Standard Model School Policy',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E1B4B)),
                          ),
                          Text(
                            pol != null
                                ? 'Calculation Basis: ${pol.calculationBasis} • Grace Lates: ${pol.lateGraceCount} • Half-Day Factor: ${pol.halfDayDeductionFactor}x'
                                : 'Working days basis with 3 grace late check-ins and 0.5x half-day deduction.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Monthly Summary & Table
          summaryAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (err, _) => _buildAdminTabError(
              context: context,
              title: 'Unable to Load Payroll Records',
              error: err,
              onRetry: () => ref.invalidate(monthlyPayrollSummaryProvider(periodKey)),
            ),
            data: (MonthlyPayrollSummaryDto summary) {
              if (summary.items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No payroll summary calculated for this period.'),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Row
                  Row(
                    children: [
                      _buildSummaryStat('Total Faculty', summary.totalTeachers.toString(), Colors.blueGrey),
                      const SizedBox(width: 14),
                      _buildSummaryStat('Gross Disbursement', '₹${summary.totalGrossDisbursement.toStringAsFixed(2)}', Colors.indigo),
                      const SizedBox(width: 14),
                      _buildSummaryStat('Attendance Deductions', '₹${summary.totalAttendanceDeductions.toStringAsFixed(2)}', Colors.amber[800]!),
                      const SizedBox(width: 14),
                      _buildSummaryStat('Net Payable', '₹${summary.totalNetPayable.toStringAsFixed(2)}', const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Table of Teachers
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Faculty Member', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Gross Salary', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Present', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Leave', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Half Day', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Deduction', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Net Pay', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: summary.items.map((item) {
                        final isApproved = item.status == 'APPROVED';
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.teacherName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    item.designation != null && item.designation!.isNotEmpty
                                        ? '${item.teacherCode} • ${item.designation}'
                                        : item.teacherCode,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text('₹${item.grossSalary.toStringAsFixed(2)}')),
                            DataCell(Text(item.presentDays.toString())),
                            DataCell(Text(item.approvedLeaveDays.toString())),
                            DataCell(Text(item.halfDays.toString())),
                            DataCell(Text(
                              '₹${item.attendanceDeductions.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: item.attendanceDeductions > 0 ? Colors.red[700] : Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                            DataCell(Text(
                              '₹${item.netPayable.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            )),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved ? const Color(0xFF047857) : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 18),
                                    tooltip: 'AI Insight & Anomaly Explanation',
                                    onPressed: () => _showAiInsightDialog(context, item),
                                  ),
                                  if (!isApproved)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () {
                                        ref.read(payrollActionProvider.notifier).approvePayroll(item.id, periodKey);
                                      },
                                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  void _showAiInsightDialog(BuildContext context, TeacherPayrollItemDto item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text('AI Payroll Insight • ${item.teacherName}'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Text(
                  item.aiExplanation ?? 'No explanation generated.',
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1E1B4B)),
                ),
              ),
              if (item.aiAnomalies.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Detected Attendance Anomalies:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 6),
                ...item.aiAnomalies.map((anom) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning, color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(anom, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

// =============================================================
// TAB 8: AUDIT LOGS
// =============================================================

class _AuditLogsTab extends ConsumerWidget {
  final String schoolId;
  const _AuditLogsTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(documentAccessLogsProvider(schoolId));

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildAdminTabError(
        context: context,
        title: 'Unable to Load Audit Logs',
        error: err,
        onRetry: () => ref.invalidate(documentAccessLogsProvider(schoolId)),
      ),
      data: (logs) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Institutional Audit Trail & Document Access History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tamper-evident logs of document uploads, unlocks, downloads, deletions, and payroll authorizations.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              if (logs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('No audit logs recorded yet.'),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final l = logs[idx];
                      return ListTile(
                        leading: _buildActionIcon(l.action),
                        title: Text(
                          '${l.action} • ${l.documentTitle}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Actor: ${l.userName ?? 'System'} • IP: ${l.ipAddress ?? '127.0.0.1'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        trailing: Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(l.createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(String action) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    if (action == 'UPLOAD') {
      icon = Icons.cloud_upload;
      color = Colors.green;
    } else if (action == 'DOWNLOAD') {
      icon = Icons.download;
      color = Colors.indigo;
    } else if (action == 'UNLOCK_SUCCESS') {
      icon = Icons.lock_open;
      color = Colors.teal;
    } else if (action == 'UNLOCK_FAILED') {
      icon = Icons.lock_clock;
      color = Colors.red;
    } else if (action == 'DELETE') {
      icon = Icons.delete;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
