import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/router/routes.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _selectedSchoolId;
  bool _isChangingPassword = false;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSelectedSchool();
    // Ensure dashboard data is fetched if it is not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardState = ref.read(dashboardStateProvider);
      if (dashboardState is DashboardInitial) {
        ref.read(dashboardStateProvider.notifier).fetchDashboard();
      }
    });
  }

  Future<void> _loadSelectedSchool() async {
    final sessionManager = ref.read(sessionManagerProvider);
    final schoolId = await sessionManager.getSchoolId();
    if (mounted) {
      setState(() {
        _selectedSchoolId = schoolId;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _switchSchool(String schoolId) async {
    final sessionManager = ref.read(sessionManagerProvider);
    await sessionManager.saveSchoolId(schoolId);
    setState(() {
      _selectedSchoolId = schoolId;
    });

    // Invalidate dashboard state and trigger refresh
    ref.read(dashboardStateProvider.notifier).fetchDashboard();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active school context switched successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isChangingPassword = true;
      });

      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.post<Map<String, dynamic>>(
        '/auth/change-password',
        data: {
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        },
        mapper: (json) {
          return json as Map<String, dynamic>;
        },
      );

      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });

        result.when(
          onSuccess: (response) {
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password updated successfully.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          onFailure: (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to change password: ${failure.message}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      }
    }
  }

  void _showChangePasswordSheet() {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            MediaQuery.of(context).viewInsets.bottom + spacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Change Password',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: spacing.md),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_open_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing.sm),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'New password is required';
                    }
                    if (val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing.sm),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  validator: (val) {
                    if (val != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing.lg),
                ElevatedButton(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final authState = ref.watch(authStateProvider);
    final dashboardState = ref.watch(dashboardStateProvider);

    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'T',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      user.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),

            // Teacher Profile / Employment Details
            if (dashboardState is DashboardSuccess || dashboardState is DashboardRefreshing) ...[
              Text(
                'Employment Details',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing.sm),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Employee Code'),
                      subtitle: Text(
                        dashboardState is DashboardSuccess
                            ? (dashboardState as DashboardSuccess).data.teacherProfile.employeeCode
                            : (dashboardState as DashboardRefreshing).data.teacherProfile.employeeCode,
                      ),
                      trailing: const Icon(Icons.badge_outlined, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Mobile'),
                      subtitle: Text(
                        dashboardState is DashboardSuccess
                            ? (dashboardState as DashboardSuccess).data.teacherProfile.mobile
                            : (dashboardState as DashboardRefreshing).data.teacherProfile.mobile,
                      ),
                      trailing: const Icon(Icons.phone_outlined, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Status'),
                      subtitle: Text(
                        dashboardState is DashboardSuccess
                            ? (dashboardState as DashboardSuccess).data.teacherProfile.status
                            : (dashboardState as DashboardRefreshing).data.teacherProfile.status,
                      ),
                      trailing: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
            ],

            // Account Metadata Details
            Text(
              'Account Information',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.sm),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('User ID'),
                    subtitle: Text(user.id),
                    trailing: const Icon(Icons.fingerprint_rounded, size: 20),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Tenant ID'),
                    subtitle: Text(user.tenantId ?? ''),
                    trailing: const Icon(Icons.domain_rounded, size: 20),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Assigned Roles'),
                    subtitle: Text(user.roles.join(', ')),
                    trailing: const Icon(Icons.lock_person_rounded, size: 20),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.md),

            // Active School Context Switcher
            Text(
              'School Context Boundary',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.sm),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select active campus context. Student directory, attendance, and leave requests will filter dynamically.',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: spacing.md),
                    if (user.schools.isEmpty)
                      const Text(
                        'No school memberships associated with this account.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedSchoolId,
                        decoration: InputDecoration(
                          labelText: 'Active School',
                          prefixIcon: const Icon(Icons.location_city_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                        ),
                        items: user.schools.map((schoolId) {
                          final label = user.schoolNames[schoolId] ?? 'School: $schoolId';
                          return DropdownMenuItem(
                            value: schoolId,
                            child: Text(label, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal != null) {
                            _switchSchool(newVal);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),

            // Settings Action Buttons
            ElevatedButton.icon(
              onPressed: _showChangePasswordSheet,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Change Password'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(authStateProvider.notifier).logout();
              },
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: EdgeInsets.symmetric(vertical: spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
