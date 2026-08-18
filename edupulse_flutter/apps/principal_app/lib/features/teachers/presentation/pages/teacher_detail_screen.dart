import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/teacher_provider.dart';
import '../../data/models/teacher_model.dart';

class TeacherDetailScreen extends ConsumerWidget {
  final String id;

  const TeacherDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final state = ref.watch(teachersStateProvider);
    Teacher? teacher;

    if (state is TeachersSuccess) {
      try {
        teacher = state.teachers.firstWhere((t) => t.id == id);
      } catch (_) {
        // Handle teacher not in list
      }
    }

    if (teacher == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              SizedBox(height: spacing.sm),
              const Text('Teacher not found.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(teacher.fullName),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher Identity Header Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.lg),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        teacher.firstName.isNotEmpty ? teacher.firstName[0] : 'T',
                        style: TextStyle(
                          fontSize: 32,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            '${teacher.designation} - ${teacher.department}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                            decoration: BoxDecoration(
                              color: teacher.status == 'ACTIVE' ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(radius.sm),
                            ),
                            child: Text(
                              teacher.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: teacher.status == 'ACTIVE' ? Colors.green.shade900 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: spacing.md),

            // Professional Profile Section
            Text('Professional Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.badge, 'Employee Code', teacher.employeeCode),
                  _buildDetailTile(Icons.perm_identity_rounded, 'Staff Code', teacher.staffCode),
                  _buildDetailTile(Icons.school, 'Qualification', teacher.qualification),
                  _buildDetailTile(Icons.work_history, 'Joining Date', teacher.joiningDate),
                  _buildDetailTile(Icons.handshake_rounded, 'Employment Type', teacher.employmentType),
                ],
              ),
            ),

            SizedBox(height: spacing.md),

            // Contact Info Section
            Text('Contact Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.phone, 'Official Mobile', teacher.mobile),
                  _buildDetailTile(Icons.email, 'Official Email', teacher.officialEmail),
                ],
              ),
            ),

            SizedBox(height: spacing.md),

            // Emergency Contacts
            Text('Emergency Contact', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.contact_phone_rounded, 'Contact Person', teacher.emergencyContactName ?? 'Not specified'),
                  _buildDetailTile(Icons.phone_android_rounded, 'Contact Phone', teacher.emergencyContactMobile ?? 'Not specified'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      dense: true,
    );
  }
}
