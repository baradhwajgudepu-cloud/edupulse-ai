import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/student_provider.dart';
import '../../data/models/student_model.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String id;

  const StudentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final state = ref.watch(studentsStateProvider);
    Student? student;

    if (state is StudentsSuccess) {
      try {
        student = state.students.firstWhere((s) => s.id == id);
      } catch (_) {
        // Handle student not in list
      }
    }

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              SizedBox(height: spacing.sm),
              const Text('Student not found.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(student.fullName),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Identity Header Card
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
                      backgroundImage: student.photoUrl != null && student.photoUrl!.isNotEmpty
                          ? NetworkImage(student.photoUrl!)
                          : null,
                      child: student.photoUrl == null || student.photoUrl!.isEmpty
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            'Class ${student.className} - ${student.sectionName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                            decoration: BoxDecoration(
                              color: student.status == 'ACTIVE' ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(radius.sm),
                            ),
                            child: Text(
                              student.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: student.status == 'ACTIVE' ? Colors.green.shade900 : Colors.orange.shade900,
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
            
            // Academic Info Section
            Text('Academic Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.assignment_ind, 'Admission Number', student.admissionNumber),
                  _buildDetailTile(Icons.format_list_numbered, 'Roll Number', student.rollNumber),
                  _buildDetailTile(Icons.calendar_today, 'Admission Date', student.admissionDate),
                ],
              ),
            ),
            
            SizedBox(height: spacing.md),
            
            // Demographic Info Section
            Text('Personal Profile', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.md),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.cake, 'Date of Birth', student.dateOfBirth),
                  _buildDetailTile(Icons.transgender, 'Gender', student.gender),
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
                  _buildDetailTile(Icons.phone, 'Mobile Number', student.mobile ?? 'Not provided'),
                  _buildDetailTile(Icons.email, 'Email Address', student.email ?? 'Not provided'),
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
