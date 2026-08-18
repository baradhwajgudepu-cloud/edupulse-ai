import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';

import '../providers/my_classes_provider.dart';
import '../../domain/entities/teacher_class_group.dart';
import '../../../../core/router/routes.dart';

class MyClassesScreen extends ConsumerStatefulWidget {
  const MyClassesScreen({super.key});

  @override
  ConsumerState<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends ConsumerState<MyClassesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myClassesStateProvider);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final local = EduLocalization.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          local?.translate('my_classes') ?? 'My Classes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _buildBody(state, theme, spacing, radius),
    );
  }

  Widget _buildBody(
    MyClassesState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    if (state is MyClassesLoading || state is MyClassesInitial) {
      return _buildSkeletonLoader(spacing, radius);
    }

    if (state is MyClassesError) {
      return _buildErrorState(state.message, theme, spacing, radius);
    }

    if (state is MyClassesEmpty) {
      return _buildEmptyState(theme, spacing, radius);
    }

    List<TeacherClassGroupEntity> classes = [];
    bool isRefreshing = false;

    if (state is MyClassesSuccess) {
      classes = state.classes;
    } else if (state is MyClassesRefreshing) {
      classes = state.classes;
      isRefreshing = true;
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myClassesStateProvider.notifier).fetchClasses(),
      child: Column(
        children: [
          if (isRefreshing)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(spacing.md),
              itemCount: classes.length,
              separatorBuilder: (context, index) => SizedBox(height: spacing.md),
              itemBuilder: (context, index) {
                final group = classes[index];
                return _buildClassCard(group, theme, spacing, radius);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    TeacherClassGroupEntity group,
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
            '${AppRoutes.classDetail}?classId=${group.classId}&sectionId=${group.sectionId}&className=${Uri.encodeComponent(group.className)}&sectionName=${Uri.encodeComponent(group.sectionName)}',
            extra: group,
          );
        },
        borderRadius: BorderRadius.circular(radius.md),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${group.className} - ${group.sectionName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              (() {
                final uniqueAssignments = <String, TeacherSubjectAssignmentEntity>{};
                for (final a in group.assignments) {
                  uniqueAssignments[a.subjectId] = a;
                }
                final displayAssignments = uniqueAssignments.values.toList();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayAssignments.length} ${displayAssignments.length == 1 ? 'Subject Assigned' : 'Subjects Assigned'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    Wrap(
                      spacing: spacing.xs,
                      runSpacing: spacing.xs,
                      children: displayAssignments.map((assignment) {
                        final colorHex = assignment.displayColor;
                        Color accentColor = theme.colorScheme.primary;
                        if (colorHex != null && colorHex.isNotEmpty) {
                          try {
                            final hex = colorHex.replaceAll('#', '');
                            accentColor = Color(int.parse('FF$hex', radix: 16));
                          } catch (_) {}
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.sm,
                            vertical: spacing.xs / 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(radius.sm),
                            border: Border.all(
                              color: accentColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (assignment.isClassTeacher) ...[
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: accentColor,
                                ),
                                SizedBox(width: spacing.xs / 2),
                              ],
                              Text(
                                assignment.subjectName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              })(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(AppSpacing spacing, AppRadius radius) {
    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: 3,
      separatorBuilder: (context, index) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 20,
                  color: Colors.grey[300],
                ),
                SizedBox(height: spacing.sm),
                Container(
                  width: 120,
                  height: 14,
                  color: Colors.grey[300],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 90,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(radius.sm),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(radius.sm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            SizedBox(height: spacing.md),
            Text(
              'No Classes Assigned',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'No classes are currently assigned to you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String message,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: spacing.md),
            Text(
              'Failed to Load Classes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(myClassesStateProvider.notifier).fetchClasses();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
