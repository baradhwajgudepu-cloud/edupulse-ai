import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Local state for avatar image preview / customization
  String? _customAvatarUrl;

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile Photo',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('Use Avatar Preset: Blue'),
                  onTap: () {
                    setState(() => _customAvatarUrl = 'avatar_blue');
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Avatar updated successfully')),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.face, color: Colors.white),
                  ),
                  title: const Text('Use Avatar Preset: Teal'),
                  onTap: () {
                    setState(() => _customAvatarUrl = 'avatar_teal');
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Avatar updated successfully')),
                    );
                  },
                ),
                if (_customAvatarUrl != null)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    title: const Text('Remove Custom Photo'),
                    textColor: Colors.red,
                    onTap: () {
                      setState(() => _customAvatarUrl = null);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Avatar removed')),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            bool hasMinLength(String p) => p.length >= 8;
            bool hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
            bool hasLower(String p) => RegExp(r'[a-z]').hasMatch(p);
            bool hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p);
            bool hasSpecial(String p) => RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p);
            bool isStrong(String p) =>
                hasMinLength(p) && hasUpper(p) && hasLower(p) && hasDigit(p) && hasSpecial(p);

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text('Change Password'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (localError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              localError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please enter current password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.password),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please enter new password';
                            if (!isStrong(val)) return 'Password does not meet strength rules';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        // Strength checklist
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _ruleChip('8+ chars', hasMinLength(newPasswordController.text)),
                            _ruleChip('Uppercase', hasUpper(newPasswordController.text)),
                            _ruleChip('Lowercase', hasLower(newPasswordController.text)),
                            _ruleChip('Number', hasDigit(newPasswordController.text)),
                            _ruleChip('Special (!@#)', hasSpecial(newPasswordController.text)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please confirm new password';
                            if (val != newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (currentPasswordController.text == newPasswordController.text) {
                            setDialogState(() {
                              localError = 'New password cannot be identical to current password.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          try {
                            final changePasswordUseCase = ref.read(changePasswordUseCaseProvider);
                            final result = await changePasswordUseCase(
                              currentPassword: currentPasswordController.text,
                              newPassword: newPasswordController.text,
                            );

                            result.when(
                              onSuccess: (_) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password changed successfully.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              onFailure: (failure) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  localError = failure.message;
                                });
                              },
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              localError = 'Failed to update password: $e';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _ruleChip(String label, bool passed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: passed ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: passed ? Colors.green : Colors.grey.shade400,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check : Icons.circle_outlined,
            size: 10,
            color: passed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: passed ? FontWeight.bold : FontWeight.normal,
              color: passed ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of EduPulse?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
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
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final authState = ref.watch(authStateProvider);
    final dashboardState = ref.watch(dashboardStateProvider);

    final user = authState is Authenticated ? authState.user : null;
    final fullName = user?.fullName.trim().isNotEmpty == true ? user!.fullName : 'Parent / Guardian';
    final email = user?.email ?? 'N/A';
    final schoolName = user?.schoolNames.values.firstOrNull ??
        (user?.schools.isNotEmpty == true ? user!.schools.first : 'EduPulse School');

    // Students from dashboard state
    final List<StudentProfile> students = switch (dashboardState) {
      DashboardSuccess(:final data) => data.students,
      _ => [],
    };
    final StudentProfile? selectedStudent = switch (dashboardState) {
      DashboardSuccess(:final data) => data.selectedStudent,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Profile Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: _customAvatarUrl == 'avatar_teal'
                              ? Colors.teal
                              : (_customAvatarUrl == 'avatar_blue'
                                  ? Colors.blueAccent
                                  : theme.colorScheme.primary),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        InkWell(
                          onTap: _showAvatarOptions,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      fullName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Parent / Guardian',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    const Divider(),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        Icon(Icons.account_balance, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schoolName,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),

            // 2. Multi-Child Switcher Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Linked Children',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (students.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${students.length} ${students.length == 1 ? "Child" : "Children"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Text(
              'Switch between your children to view attendance, report cards, and fee ledgers.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),

            if (students.isEmpty)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No children records linked. Please contact the school office.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...students.map((child) {
                final isSelected = selectedStudent?.id == child.id;
                return Card(
                  margin: EdgeInsets.only(bottom: spacing.sm),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius.md),
                    side: BorderSide(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        ref.read(dashboardStateProvider.notifier).selectStudent(child);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${child.fullName}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(radius.md),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                            child: Text(
                              child.firstName.isNotEmpty ? child.firstName[0].toUpperCase() : 'S',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        child.fullName,
                                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 12, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Class: ${child.className} • Sec: ${child.sectionName} | Adm: ${child.admissionNumber}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            SizedBox(height: spacing.lg),

            // 3. Security & Settings Section
            Text(
              'Security & Preferences',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.sm),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update your login password securely'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.photo_outlined),
                    title: const Text('Update Profile Photo'),
                    subtitle: const Text('Select an avatar preset or photo'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _showAvatarOptions,
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),

            // 4. Sign Out Action
            OutlinedButton.icon(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: spacing.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
              ),
            ),
            SizedBox(height: spacing.lg),
          ],
        ),
      ),
    );
  }
}
