import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../domain/entities/student.dart';
import '../providers/my_classes_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Simple provider to load single student if extra is null (e.g. on direct deep links)
final studentDetailProvider = FutureProvider.family<StudentEntity, String>((ref, id) async {
  final authState = ref.read(authStateProvider);
  if (authState is! Authenticated) {
    throw Exception('User is not authenticated');
  }

  final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
  if (schoolId == null) {
    throw Exception('No school associated with this account');
  }

  final myClassesRemoteDatasource = ref.read(myClassesRemoteDatasourceProvider);
  
  final result = await myClassesRemoteDatasource.getStudent(
    schoolId: schoolId,
    studentId: id,
  );

  return result.when(
    onSuccess: (dto) => StudentEntity(
      id: dto.id,
      firstName: dto.firstName,
      middleName: dto.middleName,
      lastName: dto.lastName,
      gender: dto.gender,
      dateOfBirth: dto.dateOfBirth,
      bloodGroup: dto.bloodGroup,
      mobile: dto.mobile,
      email: dto.email,
      photoUrl: dto.photoUrl,
      admissionNumber: dto.admissionNumber,
      rollNumber: dto.rollNumber,
      status: dto.status,
      className: dto.className ?? 'Class',
      sectionName: dto.sectionName ?? 'Section',
    ),
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  final StudentEntity? student;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.student,
  });

  Color _getAvatarColor(String name, ThemeData theme) {
    final hash = name.codeUnits.fold(0, (prev, next) => prev + next);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    if (student != null) {
      return _buildScaffold(student!, theme, spacing, radius);
    }

    final future = ref.watch(studentDetailProvider(studentId));

    return future.when(
      data: (data) => _buildScaffold(data, theme, spacing, radius),
      loading: () => Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(elevation: 0, backgroundColor: theme.colorScheme.surface),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(elevation: 0, backgroundColor: theme.colorScheme.surface),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
                SizedBox(height: spacing.md),
                Text('Failed to Load Student Detail', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: spacing.xs),
                Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                SizedBox(height: spacing.lg),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(studentDetailProvider(studentId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    StudentEntity student,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final avatarColor = _getAvatarColor(student.fullName, theme);
    final initials = '${student.firstName.isNotEmpty ? student.firstName[0] : ''}${student.lastName.isNotEmpty ? student.lastName[0] : ''}';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student Profile'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          children: [
            // Header Profile Card
            _buildProfileHeaderCard(student, initials, avatarColor, theme, spacing, radius),
            SizedBox(height: spacing.md),
            // Enrollment Details Card
            _buildInfoCard(
              title: 'Academic Information',
              icon: Icons.school_rounded,
              theme: theme,
              spacing: spacing,
              radius: radius,
              items: [
                _buildInfoRow('Class & Section', '${student.className} - ${student.sectionName}', theme, spacing),
                _buildInfoRow('Roll Number', student.rollNumber.padLeft(2, '0'), theme, spacing),
                _buildInfoRow('Admission Number', student.admissionNumber, theme, spacing),
                _buildInfoRow('Enrollment Status', student.status, theme, spacing, highlight: true),
              ],
            ),
            SizedBox(height: spacing.md),
            // Personal Details Card
            _buildInfoCard(
              title: 'Personal Details',
              icon: Icons.person_rounded,
              theme: theme,
              spacing: spacing,
              radius: radius,
              items: [
                _buildInfoRow('Gender', student.gender, theme, spacing),
                _buildInfoRow('Date of Birth', student.dateOfBirth, theme, spacing),
                _buildInfoRow('Blood Group', student.bloodGroup ?? 'Not Provided', theme, spacing),
                _buildInfoRow('Contact Number', student.mobile ?? 'Not Provided', theme, spacing),
                _buildInfoRow('Email Address', student.email ?? 'Not Provided', theme, spacing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(
    StudentEntity student,
    String initials,
    Color avatarColor,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.lg, horizontal: spacing.md),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: avatarColor.withOpacity(0.1),
              backgroundImage: student.photoUrl != null && student.photoUrl!.isNotEmpty
                  ? NetworkImage(student.photoUrl!)
                  : null,
              child: student.photoUrl == null || student.photoUrl!.isEmpty
                  ? Text(
                      initials,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(height: spacing.md),
            Text(
              student.fullName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: spacing.xs),
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(radius.sm),
              ),
              child: Text(
                'Roll No: ${student.rollNumber}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
    required ThemeData theme,
    required AppSpacing spacing,
    required AppRadius radius,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                SizedBox(width: spacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeData theme,
    AppSpacing spacing, {
    bool highlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: spacing.md),
          Flexible(
            child: highlight
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
                    decoration: BoxDecoration(
                      color: value.toUpperCase() == 'ACTIVE'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        (theme.extension<AppRadius>() ?? const AppRadius.standard()).xs,
                      ),
                    ),
                    child: Text(
                      value,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: value.toUpperCase() == 'ACTIVE' ? Colors.green[800] : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
