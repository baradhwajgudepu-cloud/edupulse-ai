import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';

class UserDetailsScreen extends ConsumerWidget {
  final String userId;

  const UserDetailsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userDetailProvider(userId));
    final actionState = ref.watch(userActionProvider);

    // Watch action states for showing snackbars on success/error
    ref.listen<UserActionState>(userActionProvider, (prev, next) {
      if (next is UserActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } else if (next is UserActionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.message}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Account Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load user: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userDetailProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) {
          final isLocked = user.status.toUpperCase() == 'LOCKED';
          final isActive = user.status.toUpperCase() == 'ACTIVE';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card with name and status
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${user.firstName[0].toUpperCase()}${user.lastName[0].toUpperCase()}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${user.firstName} ${user.lastName}',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildStatusChip(context, user.status),
                                  if (user.isSuperuser) ...[
                                    Chip(
                                      label: const Text('SUPERUSER'),
                                      backgroundColor: theme.colorScheme.errorContainer,
                                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.email,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'User ID: ${user.id}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions Management Panel
                Text(
                  'Account Actions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (!isActive)
                          ElevatedButton.icon(
                            onPressed: actionState is UserActionLoading
                                ? null
                                : () => _confirmAction(
                                      context,
                                      ref,
                                      'Activate User Account?',
                                      'This will reactivate their login and API permissions.',
                                      () => ref.read(userActionProvider.notifier).activateUser(user.id),
                                    ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Activate'),
                          ),
                        if (isActive)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.errorContainer,
                              foregroundColor: theme.colorScheme.onErrorContainer,
                            ),
                            onPressed: actionState is UserActionLoading
                                ? null
                                : () => _confirmAction(
                                      context,
                                      ref,
                                      'Deactivate User Account?',
                                      'The user will be immediately blocked from logging in or using current tokens.',
                                      () => ref.read(userActionProvider.notifier).deactivateUser(user.id),
                                    ),
                            icon: const Icon(Icons.block),
                            label: const Text('Deactivate'),
                          ),
                        ElevatedButton.icon(
                          onPressed: actionState is UserActionLoading
                              ? null
                              : () => _confirmAction(
                                    context,
                                    ref,
                                    'Reset Password?',
                                    'Resetting will overwrite their password with a temporary credential. This action is recorded.',
                                    () => ref.read(userActionProvider.notifier).resetPassword(user.id),
                                  ),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Reset Password'),
                        ),
                        if (isLocked)
                          ElevatedButton.icon(
                            onPressed: actionState is UserActionLoading
                                ? null
                                : () => _confirmAction(
                                      context,
                                      ref,
                                      'Unlock User Account?',
                                      'This unlocks the account by clearing brute force lockout count limits.',
                                      () => ref.read(userActionProvider.notifier).unlockUser(user.id),
                                    ),
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Unlock Account'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Roles and Permissions Section
                Text(
                  'Assigned Roles & Permissions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...user.roles.map((role) {
                  final name = role is Map ? role['name']?.toString() ?? 'Role' : role.toString();
                  final code = role is Map ? role['code']?.toString() ?? 'ROLE' : role.toString();
                  final desc = role is Map ? role['description']?.toString() ?? '' : '';
                  final List<dynamic> permissions = role is Map && role['permissions'] != null
                      ? role['permissions'] as List<dynamic>
                      : [];

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text('$name ($code)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: desc.isNotEmpty ? Text(desc) : null,
                      leading: const Icon(Icons.verified_user),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Role Permissions (${permissions.length})',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              if (permissions.isEmpty)
                                const Text('No explicit permissions granted to this role.')
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: permissions.map((p) {
                                    final pName = p is Map ? p['name']?.toString() ?? '' : p.toString();
                                    final pCode = p is Map ? p['code']?.toString() ?? '' : p.toString();
                                    return Tooltip(
                                      message: pName,
                                      child: Chip(
                                        label: Text(pCode),
                                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // School affiliations
                Text(
                  'School Affiliations',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: user.schools.isEmpty
                        ? const Text('This user is not affiliated with any schools.')
                        : Column(
                            children: user.schools.map((school) {
                              final name = school is Map ? school['name']?.toString() ?? '' : school.toString();
                              final code = school is Map ? school['code']?.toString() ?? '' : '';
                              final id = school is Map ? school['id']?.toString() ?? '' : '';

                              return ListTile(
                                leading: const Icon(Icons.school),
                                title: Text(name),
                                subtitle: code.isNotEmpty ? Text('Code: $code') : null,
                                trailing: id.isNotEmpty
                                    ? Text(
                                        'ID: ${id.substring(0, 8)}...',
                                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                      )
                                    : null,
                              );
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Linked Students / Children Section
                Text(
                  'Linked Students / Children',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ref.watch(linkedStudentsProvider(user.email)).when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error loading linked students: $err',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                      data: (students) {
                        if (students.isEmpty) {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No student profiles linked to this parent user account.'),
                            ),
                          );
                        }
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: students.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final student = students[index];
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(
                                  '${student.firstName} ${student.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Admission: ${student.admissionNumber} • Class: ${student.className ?? "-"} • Section: ${student.sectionName ?? "-"} • Status: ${student.status}',
                                ),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('View Student'),
                                  onPressed: () {
                                    context.push('/students/${student.id}?school_id=${student.schoolId}');
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                const SizedBox(height: 24),

                // Metadata Section
                Text(
                  'Diagnostics & Metadata',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.0),
                              child: Text('Created At:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Text(_formatDate(user.createdAt)),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.0),
                              child: Text('Last Updated:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Text(_formatDate(user.updatedAt)),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.0),
                              child: Text('DB Version:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Text('${user.version}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final theme = Theme.of(context);
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.grey;
        break;
      case 'SUSPENDED':
        color = Colors.orange;
        break;
      case 'LOCKED':
        color = Colors.red;
        break;
      default:
        color = theme.colorScheme.onSurface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.5 * 255).round())),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _confirmAction(BuildContext context, WidgetRef ref, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
