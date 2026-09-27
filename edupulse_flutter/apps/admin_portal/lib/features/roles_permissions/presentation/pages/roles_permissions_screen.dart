import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/core/auth/portal_permissions.dart';

class RoleDefinition {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool isSystem;
  final Set<String> permissionCodes;

  RoleDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.permissionCodes,
  });

  RoleDefinition copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    bool? isSystem,
    Set<String>? permissionCodes,
  }) {
    return RoleDefinition(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
      permissionCodes: permissionCodes ?? this.permissionCodes,
    );
  }
}

class PermissionDefinition {
  final String id;
  final String code;
  final String name;
  final String module;

  const PermissionDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.module,
  });
}

class RolesPermissionsScreen extends ConsumerStatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  ConsumerState<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends ConsumerState<RolesPermissionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedRoleCode = 'ADMIN';

  List<RoleDefinition> _roles = [];
  Map<String, Set<String>> _activePermissions = {};
  Map<String, Set<String>> _initialPermissions = {};

  final Map<String, List<PermissionDefinition>> _permissionModules = {
    'Students': const [
      PermissionDefinition(id: 'perm_stud_read', code: 'student.read', name: 'View Student Directory & Profiles', module: 'Students'),
      PermissionDefinition(id: 'perm_stud_create', code: 'student.create', name: 'Enroll New Students', module: 'Students'),
      PermissionDefinition(id: 'perm_stud_update', code: 'student.update', name: 'Edit Student Details & Section', module: 'Students'),
      PermissionDefinition(id: 'perm_stud_delete', code: 'student.delete', name: 'Archive & Delete Student Records', module: 'Students'),
      PermissionDefinition(id: 'perm_guard_read', code: 'guardian.read', name: 'View Linked Parents & Guardians', module: 'Students'),
    ],
    'Attendance': const [
      PermissionDefinition(id: 'perm_att_read', code: 'attendance.read', name: 'View Attendance Records & Trends', module: 'Attendance'),
      PermissionDefinition(id: 'perm_att_create', code: 'attendance.create', name: 'Mark Daily Student Attendance', module: 'Attendance'),
      PermissionDefinition(id: 'perm_att_update', code: 'attendance.update', name: 'Audit & Correct Attendance Logs', module: 'Attendance'),
      PermissionDefinition(id: 'perm_staff_att', code: 'staff_attendance.read', name: 'View Staff & Faculty Attendance', module: 'Attendance'),
    ],
    'Fees & Finance': const [
      PermissionDefinition(id: 'perm_fee_read', code: 'fee.read', name: 'View Fee Structure & Dues', module: 'Fees & Finance'),
      PermissionDefinition(id: 'perm_fee_pay', code: 'fee.pay', name: 'Collect Fee Payments & Generate Receipts', module: 'Fees & Finance'),
      PermissionDefinition(id: 'perm_fee_create', code: 'fee.create', name: 'Configure Fee Heads & Concessions', module: 'Fees & Finance'),
      PermissionDefinition(id: 'perm_fee_report', code: 'fee.report', name: 'Access Financial Ledgers & Reconciliation', module: 'Fees & Finance'),
    ],
    'Academics': const [
      PermissionDefinition(id: 'perm_class_read', code: 'class.read', name: 'View Classes, Streams & Sections', module: 'Academics'),
      PermissionDefinition(id: 'perm_subj_read', code: 'subject.read', name: 'View Curriculum & Subject Catalog', module: 'Academics'),
      PermissionDefinition(id: 'perm_exam_read', code: 'exam.read', name: 'View Examination Schedules', module: 'Academics'),
      PermissionDefinition(id: 'perm_marks_read', code: 'marks.read', name: 'View & Enter Academic Marks', module: 'Academics'),
      PermissionDefinition(id: 'perm_rc_read', code: 'report_card.read', name: 'Compile & View Student Report Cards', module: 'Academics'),
      PermissionDefinition(id: 'perm_rc_dl', code: 'report_card.download', name: 'Download Official PDF Report Cards', module: 'Academics'),
    ],
    'Staff & Faculty': const [
      PermissionDefinition(id: 'perm_teach_read', code: 'teacher.read', name: 'View Teacher Directory & Profiles', module: 'Staff & Faculty'),
      PermissionDefinition(id: 'perm_leave_read', code: 'teacher_leave.read', name: 'View Faculty Leave Applications', module: 'Staff & Faculty'),
      PermissionDefinition(id: 'perm_leave_admin', code: 'teacher_leave.admin', name: 'Approve & Reject Faculty Leaves', module: 'Staff & Faculty'),
      PermissionDefinition(id: 'perm_teach_assign', code: 'teacher_subject_assignment.read', name: 'Manage Teacher Subject Allocations', module: 'Staff & Faculty'),
    ],
    'School Setup & Operations': const [
      PermissionDefinition(id: 'perm_ay_read', code: 'academic_year.read', name: 'View Academic Calendar & Terms', module: 'School Setup & Operations'),
      PermissionDefinition(id: 'perm_room_read', code: 'school.read', name: 'Manage Classrooms & Campus Geofences', module: 'School Setup & Operations'),
      PermissionDefinition(id: 'perm_tt_read', code: 'timetable.read', name: 'View Master Timetable & Class Periods', module: 'School Setup & Operations'),
    ],
    'Communication & Governance': const [
      PermissionDefinition(id: 'perm_ann_read', code: 'announcement.read', name: 'View Broadcast Announcements', module: 'Communication & Governance'),
      PermissionDefinition(id: 'perm_ann_pub', code: 'announcement.publish', name: 'Publish Campus Announcements', module: 'Communication & Governance'),
      PermissionDefinition(id: 'perm_notif_read', code: 'notification.read', name: 'Send Parent & Staff Notifications', module: 'Communication & Governance'),
      PermissionDefinition(id: 'perm_rep_read', code: 'reports.read', name: 'View Analytics & Performance Reports', module: 'Communication & Governance'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _roles = _getDefaultRoles();
    _activePermissions = {};
    _initialPermissions = {};
    for (final r in _roles) {
      _activePermissions[r.code] = Set<String>.from(r.permissionCodes);
      _initialPermissions[r.code] = Set<String>.from(r.permissionCodes);
    }
    _isLoading = false;
    _loadRolesAndPermissions();
  }

  Future<void> _loadRolesAndPermissions() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(
        '/roles',
        mapper: (json) {
          final list = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
          return list.map((item) {
            final m = item as Map<String, dynamic>;
            final permsList = m['permissions'] as List<dynamic>? ?? [];
            final permCodes = permsList.map((p) => (p as Map<String, dynamic>)['code'] as String).toSet();
            return RoleDefinition(
              id: m['id'] as String? ?? '',
              code: m['code'] as String? ?? '',
              name: m['name'] as String? ?? '',
              description: m['description'] as String? ?? '',
              isSystem: m['is_system'] as bool? ?? false,
              permissionCodes: permCodes,
            );
          }).toList();
        },
      );

      res.when(
        onSuccess: (roles) {
          if (roles.isNotEmpty) {
            _roles = roles;
          } else {
            _roles = _getDefaultRoles();
          }
        },
        onFailure: (_) {
          _roles = _getDefaultRoles();
        },
      );
    } catch (_) {
      _roles = _getDefaultRoles();
    }

    _activePermissions = {};
    _initialPermissions = {};
    for (final r in _roles) {
      _activePermissions[r.code] = Set<String>.from(r.permissionCodes);
      _initialPermissions[r.code] = Set<String>.from(r.permissionCodes);
    }

    if (_roles.isNotEmpty && !_roles.any((r) => r.code == _selectedRoleCode)) {
      _selectedRoleCode = _roles.first.code;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<RoleDefinition> _getDefaultRoles() {
    return [
      RoleDefinition(
        id: 'role_admin',
        code: 'ADMIN',
        name: 'School Admin',
        description: 'Complete institutional operations, admissions, billing, and setup governance.',
        isSystem: true,
        permissionCodes: {
          'student.read', 'student.create', 'student.update', 'student.delete', 'guardian.read',
          'attendance.read', 'attendance.create', 'attendance.update', 'staff_attendance.read',
          'fee.read', 'fee.pay', 'fee.create', 'fee.report',
          'class.read', 'subject.read', 'exam.read', 'marks.read', 'report_card.read', 'report_card.download',
          'teacher.read', 'teacher_leave.read', 'teacher_leave.admin', 'teacher_subject_assignment.read',
          'academic_year.read', 'school.read', 'timetable.read',
          'announcement.read', 'announcement.publish', 'notification.read', 'reports.read',
        },
      ),
      RoleDefinition(
        id: 'role_principal',
        code: 'PRINCIPAL',
        name: 'Principal',
        description: 'Academic controller, examination supervisor, performance reporting, and leave manager.',
        isSystem: true,
        permissionCodes: {
          'student.read', 'guardian.read',
          'attendance.read', 'staff_attendance.read',
          'fee.read', 'fee.report',
          'class.read', 'subject.read', 'exam.read', 'marks.read', 'report_card.read', 'report_card.download',
          'teacher.read', 'teacher_leave.read', 'teacher_leave.admin', 'teacher_subject_assignment.read',
          'academic_year.read', 'school.read', 'timetable.read',
          'announcement.read', 'announcement.publish', 'notification.read', 'reports.read',
        },
      ),
      RoleDefinition(
        id: 'role_teacher',
        code: 'TEACHER',
        name: 'Teacher',
        description: 'Classroom facilitator, geofenced attendance marking, grading, and homework manager.',
        isSystem: true,
        permissionCodes: {
          'student.read',
          'attendance.read', 'attendance.create',
          'class.read', 'subject.read', 'exam.read', 'marks.read', 'report_card.read',
          'teacher.read', 'teacher_leave.read',
          'academic_year.read', 'timetable.read',
          'announcement.read', 'notification.read',
        },
      ),
      RoleDefinition(
        id: 'role_parent',
        code: 'PARENT',
        name: 'Parent / Guardian',
        description: 'Student academic tracking, attendance calendar, homework alerts, and online fee payments.',
        isSystem: true,
        permissionCodes: {
          'student.read',
          'attendance.read',
          'fee.read', 'fee.pay',
          'exam.read', 'report_card.read', 'report_card.download',
          'timetable.read',
          'announcement.read', 'notification.read',
        },
      ),
      RoleDefinition(
        id: 'role_super_admin',
        code: 'SUPER_ADMIN',
        name: 'Super Admin',
        description: 'Platform administrator with global tenant provisioning and multi-school governance.',
        isSystem: true,
        permissionCodes: {
          for (final module in _permissionModules.values)
            for (final p in module) p.code
        },
      ),
    ];
  }

  void _togglePermission(String roleCode, String permCode) {
    setState(() {
      final currentSet = _activePermissions[roleCode] ?? {};
      if (currentSet.contains(permCode)) {
        currentSet.remove(permCode);
      } else {
        currentSet.add(permCode);
      }
      _activePermissions[roleCode] = currentSet;
    });
  }

  void _resetToCurrent(String roleCode) {
    setState(() {
      final initial = _initialPermissions[roleCode] ?? {};
      _activePermissions[roleCode] = Set<String>.from(initial);
    });
    _showFloatingNotification(
      'Permissions reset to last saved state.',
      const Color(0xFF1E293B),
      Icons.restore,
    );
  }

  void _resetToDefault(String roleCode) {
    final defaultRole = _getDefaultRoles().firstWhere((r) => r.code == roleCode, orElse: () => _roles.first);
    setState(() {
      _activePermissions[roleCode] = Set<String>.from(defaultRole.permissionCodes);
    });
    _showFloatingNotification(
      'Default permissions restored for ${defaultRole.name}.',
      const Color(0xFF0F766E),
      Icons.check_circle_outline,
    );
  }

  Future<void> _savePermissions(RoleDefinition role) async {
    final currentPerms = _activePermissions[role.code] ?? {};

    // Check if system default role
    if (role.isSystem) {
      _showFloatingNotification(
        'Permission management for system default role "${role.name}" is protected by backend policy.',
        const Color(0xFFB45309),
        Icons.shield_outlined,
      );
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.put(
        '/roles/${role.id}',
        data: {
          'name': role.name,
          'code': role.code,
          'description': role.description,
          'permission_ids': currentPerms.toList(),
        },
        mapper: (json) => json,
      );

      res.when(
        onSuccess: (_) {
          _initialPermissions[role.code] = Set<String>.from(currentPerms);
          ref.invalidate(portalPermissionsProvider);
          _showFloatingNotification(
            'Permissions updated successfully',
            const Color(0xFF059669),
            Icons.check_circle,
          );
        },
        onFailure: (failure) {
          _showFloatingNotification(
            'Unable to update permissions: ${failure.message}',
            const Color(0xFFE11D48),
            Icons.error_outline,
          );
        },
      );
    } catch (e) {
      _showFloatingNotification(
        'Unable to update permissions: $e',
        const Color(0xFFE11D48),
        Icons.error_outline,
      );
    }
  }

  void _showFloatingNotification(String message, Color backgroundColor, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 440,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final isSuperAdmin = authState is Authenticated && authState.user.isSuperuser;

    final visibleRoles = isSuperAdmin
        ? _roles
        : _roles.where((r) => r.code != 'SUPER_ADMIN').toList();

    final selectedRole = visibleRoles.firstWhere(
      (r) => r.code == _selectedRoleCode,
      orElse: () => visibleRoles.isNotEmpty ? visibleRoles.first : _getDefaultRoles().first,
    );

    final selectedPerms = _activePermissions[selectedRole.code] ?? {};

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFBF1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shield_outlined, color: Color(0xFF0F766E), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Roles & Permissions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Control what each role can view and manage across the school.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: Color(0xFF475569)),
                              SizedBox(width: 6),
                              Text(
                                'RBAC Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Role Selector Tabs
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: visibleRoles.map((role) {
                          final isSelected = role.code == selectedRole.code;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedRoleCode = role.code;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getRoleIcon(role.code),
                                      size: 16,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      role.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                    if (role.isSystem) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0x30FFFFFF) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'SYSTEM',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Selected Role Overview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedRole.name} Permissions Matrix',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedRole.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _resetToCurrent(selectedRole.code),
                              icon: const Icon(Icons.undo, size: 14),
                              label: const Text('Reset'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _resetToDefault(selectedRole.code),
                              icon: const Icon(Icons.restore, size: 14),
                              label: const Text('Reset to Default'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F766E),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _savePermissions(selectedRole),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Save Changes'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Module Grouped Permission Matrix
                  Column(
                    children: _permissionModules.entries.map((entry) {
                      final moduleName = entry.key;
                      final perms = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(_getModuleIcon(moduleName), size: 16, color: const Color(0xFF0F766E)),
                                      const SizedBox(width: 8),
                                      Text(
                                        moduleName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${perms.where((p) => selectedPerms.contains(p.code)).length} of ${perms.length} enabled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: perms.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, idx) {
                                final p = perms[idx];
                                final isGranted = selectedPerms.contains(p.code);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            p.code,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch.adaptive(
                                        value: isGranted,
                                        activeColor: const Color(0xFF0F766E),
                                        onChanged: (_) => _togglePermission(selectedRole.code, p.code),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getRoleIcon(String code) {
    switch (code.toUpperCase()) {
      case 'ADMIN':
      case 'SCHOOL_ADMIN':
        return Icons.admin_panel_settings_outlined;
      case 'PRINCIPAL':
        return Icons.school_outlined;
      case 'TEACHER':
        return Icons.badge_outlined;
      case 'PARENT':
        return Icons.family_restroom_outlined;
      case 'SUPER_ADMIN':
        return Icons.verified_user_outlined;
      default:
        return Icons.person_outline;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'Students':
        return Icons.school_outlined;
      case 'Attendance':
        return Icons.calendar_today_outlined;
      case 'Fees & Finance':
        return Icons.payments_outlined;
      case 'Academics':
        return Icons.assignment_outlined;
      case 'Staff & Faculty':
        return Icons.people_outline;
      case 'School Setup & Operations':
        return Icons.check_circle_outline;
      case 'Communication & Governance':
        return Icons.campaign_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}
