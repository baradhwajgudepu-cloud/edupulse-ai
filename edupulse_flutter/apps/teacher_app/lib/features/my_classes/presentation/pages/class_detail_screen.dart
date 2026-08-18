import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../domain/entities/teacher_class_group.dart';
import '../../../../core/router/routes.dart';
import '../providers/my_classes_provider.dart';

class ClassDetailScreen extends ConsumerWidget {
  final String classId;
  final String sectionId;
  final String className;
  final String sectionName;
  final TeacherClassGroupEntity? group;

  const ClassDetailScreen({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    // If group wasn't passed via extra, try to locate it in the provider success state
    TeacherClassGroupEntity? resolvedGroup = group;
    if (resolvedGroup == null) {
      final myClassesState = ref.read(myClassesStateProvider);
      if (myClassesState is MyClassesSuccess) {
        try {
          resolvedGroup = myClassesState.classes.firstWhere(
            (g) => g.classId == classId && g.sectionId == sectionId,
          );
        } catch (_) {}
      }
    }

    final isClassTeacher = resolvedGroup?.assignments.any((a) => a.isClassTeacher) ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '$className - $sectionName',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: resolvedGroup == null
          ? _buildNotFoundState(theme, spacing, radius, context)
          : SingleChildScrollView(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(resolvedGroup, isClassTeacher, theme, spacing, radius),
                  SizedBox(height: spacing.md),
                  _buildRosterActionCard(context, theme, spacing, radius),
                  SizedBox(height: spacing.lg),
                  Text(
                    'Assigned Subjects',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  _buildSubjectsList(resolvedGroup.assignments, theme, spacing, radius),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(
    TeacherClassGroupEntity group,
    bool isClassTeacher,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.class_rounded,
                color: theme.colorScheme.onPrimary,
                size: 28,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${group.className} - ${group.sectionName}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  if (isClassTeacher)
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: spacing.xs / 2),
                        Text(
                          'Class Teacher',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Subject Teacher',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterActionCard(
    BuildContext context,
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
      child: InkWell(
        onTap: () {
          context.push(
            '${AppRoutes.studentRoster}?classId=$classId&sectionId=$sectionId&className=${Uri.encodeComponent(className)}&sectionName=${Uri.encodeComponent(sectionName)}',
          );
        },
        borderRadius: BorderRadius.circular(radius.md),
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.people_alt_rounded,
                color: theme.colorScheme.secondary,
                size: 24,
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Student Roster',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: spacing.xs / 2),
                    Text(
                      'Roster profiles, codes, and details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsList(
    List<TeacherSubjectAssignmentEntity> assignments,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignments.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final subject = assignments[index];
        final colorHex = subject.displayColor;
        Color accentColor = theme.colorScheme.primary;
        if (colorHex != null && colorHex.isNotEmpty) {
          try {
            final hex = colorHex.replaceAll('#', '');
            accentColor = Color(int.parse('FF$hex', radix: 16));
          } catch (_) {}
        }

        return Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(radius.xs),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subjectName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subject.subjectCode.isNotEmpty) ...[
                      SizedBox(height: spacing.xs / 2),
                      Text(
                        subject.subjectCode,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (subject.isClassTeacher)
                Chip(
                  label: const Text('Class Teacher'),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotFoundState(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: spacing.md),
            Text(
              'Class Group Not Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'No class assignments match this query parameters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.lg),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
