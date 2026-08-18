import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';

import '../../../../core/router/routes.dart';
import '../../domain/entities/homework_entity.dart';
import '../providers/homework_provider.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';

class HomeworkDetailScreen extends ConsumerStatefulWidget {
  final String homeworkId;

  const HomeworkDetailScreen({
    super.key,
    required this.homeworkId,
  });

  @override
  ConsumerState<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends ConsumerState<HomeworkDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeworkDetailProvider(widget.homeworkId).notifier).fetchDetails();
    });
  }

  void _confirmPublish(BuildContext context, HomeworkDetailNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish Homework'),
        content: const Text('Are you sure you want to publish this homework assignment? Once published, notifications will be queued for parents/students.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await notifier.publish();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Homework published successfully!')),
                );
              }
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, HomeworkDetailNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework? This action is not reversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await notifier.delete();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Homework deleted successfully!')),
                );
                context.pop(true); // Return true to trigger list refresh
              }
            },
            child: const Text('Delete'),
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
    final local = EduLocalization.of(context);

    final detailState = ref.watch(homeworkDetailProvider(widget.homeworkId));
    final classesState = ref.watch(myClassesStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework Details'),
        elevation: 0,
        actions: [
          if (detailState is HomeworkDetailSuccess) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final result = await context.push('${AppRoutes.homeworkEdit}?id=${widget.homeworkId}');
                if (result == true) {
                  ref.read(homeworkDetailProvider(widget.homeworkId).notifier).fetchDetails();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, ref.read(homeworkDetailProvider(widget.homeworkId).notifier)),
            ),
          ]
        ],
      ),
      body: _buildBody(detailState, classesState, theme, spacing, radius, local),
    );
  }

  Widget _buildBody(
    HomeworkDetailState state,
    MyClassesState classesState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    if (state is HomeworkDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is HomeworkDetailError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: spacing.md),
              Text(
                state.message,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.md),
              ElevatedButton(
                onPressed: () => ref.read(homeworkDetailProvider(widget.homeworkId).notifier).fetchDetails(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is HomeworkDetailSuccess) {
      final homework = state.homework;
      
      // Resolve names
      String className = 'Class';
      String sectionName = 'Section';
      String subjectName = 'Subject';

      if (classesState is MyClassesSuccess || classesState is MyClassesRefreshing) {
        final groups = classesState is MyClassesSuccess
            ? classesState.classes
            : (classesState as MyClassesRefreshing).classes;

        final match = groups.firstWhere(
          (g) => g.classId == homework.classId && g.sectionId == homework.sectionId,
          orElse: () => TeacherClassGroupEntity(
            classId: homework.classId,
            className: 'Class',
            sectionId: homework.sectionId,
            sectionName: 'Section',
            assignments: const [],
          ),
        );

        className = match.className;
        sectionName = match.sectionName;

        final asgMatch = match.assignments.firstWhere(
          (asg) => asg.subjectId == homework.subjectId,
          orElse: () => TeacherSubjectAssignmentEntity(
            id: homework.teacherSubjectAssignmentId,
            subjectId: homework.subjectId,
            subjectName: 'Subject',
            subjectCode: '',
            displayColor: null,
            isClassTeacher: false,
          ),
        );
        subjectName = asgMatch.subjectName;
      }

      final formattedDueDate = DateFormat('EEEE, dd MMMM yyyy').format(homework.dueDate);
      final formattedCreatedDate = DateFormat('dd MMM yyyy, hh:mm a').format(homework.createdAt);

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and priority badges
            Row(
              children: [
                _buildStatusBadge(homework.status, theme, radius),
                SizedBox(width: spacing.sm),
                _buildPriorityBadge(homework.priority, theme, radius),
              ],
            ),
            SizedBox(height: spacing.md),
            
            // Title
            Text(
              homework.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.md),
            const Divider(),
            SizedBox(height: spacing.md),
            
            // Key Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.school_rounded,
                    'Target Class',
                    '$className - $sectionName',
                    theme,
                    spacing,
                    radius,
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: _buildInfoTile(
                    Icons.menu_book_rounded,
                    'Subject',
                    subjectName,
                    theme,
                    spacing,
                    radius,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.event_rounded,
                    'Due Date',
                    formattedDueDate,
                    theme,
                    spacing,
                    radius,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // Optional metrics
            if (homework.estimatedMinutes != null) ...[
              _buildInfoTile(
                Icons.timer_rounded,
                'Estimated Effort Time',
                '${homework.estimatedMinutes} minutes',
                theme,
                spacing,
                radius,
              ),
              SizedBox(height: spacing.lg),
            ],

            if (homework.attachmentUrl != null && homework.attachmentUrl!.isNotEmpty) ...[
              _buildInfoTile(
                Icons.attachment_rounded,
                'Attachment Link',
                homework.attachmentUrl!,
                theme,
                spacing,
                radius,
                isLink: true,
              ),
              SizedBox(height: spacing.lg),
            ],

            // Description
            Text(
              'Description / Instructions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.sm),
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    homework.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            
            // Metadata
            Text(
              'Created on: $formattedCreatedDate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.xl),

            // Main Actions Drawer
            if (homework.status == HomeworkStatus.DRAFT) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmPublish(context, ref.read(homeworkDetailProvider(widget.homeworkId).notifier)),
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publish Assignment Now'),
                ),
              ),
            ] else if (homework.status == HomeworkStatus.PUBLISHED) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('${AppRoutes.homeworkCopy}?id=${homework.id}');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy to other Class Sections'),
                ),
              ),
            ]
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusBadge(HomeworkStatus status, ThemeData theme, AppRadius radius) {
    Color color = Colors.grey;
    switch (status) {
      case HomeworkStatus.DRAFT:
        color = Colors.amber;
        break;
      case HomeworkStatus.PUBLISHED:
        color = Colors.green;
        break;
      case HomeworkStatus.ARCHIVED:
        color = Colors.blueGrey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: Text(
        status.name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(HomeworkPriority priority, ThemeData theme, AppRadius radius) {
    Color color = Colors.blue;
    switch (priority) {
      case HomeworkPriority.LOW:
        color = Colors.green;
        break;
      case HomeworkPriority.NORMAL:
        color = Colors.blue;
        break;
      case HomeworkPriority.HIGH:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: Text(
        priority.name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius, {
    bool isLink = false,
  }) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLink ? Colors.blue : null,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
