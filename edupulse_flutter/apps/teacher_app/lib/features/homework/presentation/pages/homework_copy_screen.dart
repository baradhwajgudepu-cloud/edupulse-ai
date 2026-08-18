import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';

import '../providers/homework_provider.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';

class HomeworkCopyScreen extends ConsumerStatefulWidget {
  final String homeworkId;

  const HomeworkCopyScreen({
    super.key,
    required this.homeworkId,
  });

  @override
  ConsumerState<HomeworkCopyScreen> createState() => _HomeworkCopyScreenState();
}

class _HomeworkCopyScreenState extends ConsumerState<HomeworkCopyScreen> {
  final List<String> _selectedSectionIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeworkDetailProvider(widget.homeworkId).notifier).fetchDetails();
      ref.read(myClassesStateProvider.notifier).fetchClasses();
    });
  }

  Future<void> _submitCopy(String schoolId) async {
    if (_selectedSectionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class section.')),
      );
      return;
    }

    final notifier = ref.read(homeworkFormNotifierProvider.notifier);
    final success = await notifier.copyToSections(
      homeworkId: widget.homeworkId,
      targetSectionIds: _selectedSectionIds,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully copied homework to ${_selectedSectionIds.length} sections!')),
      );
      context.pop(true); // Return to details screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final local = EduLocalization.of(context);

    final detailState = ref.watch(homeworkDetailProvider(widget.homeworkId));
    final classesState = ref.watch(myClassesStateProvider);
    final formState = ref.watch(homeworkFormNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy Homework'),
        elevation: 0,
      ),
      body: _buildContent(detailState, classesState, formState, theme, spacing, radius, local),
    );
  }

  Widget _buildContent(
    HomeworkDetailState detailState,
    MyClassesState classesState,
    HomeworkFormState formState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    if (detailState is HomeworkDetailLoading || classesState is MyClassesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detailState is HomeworkDetailError) {
      return Center(child: Text(detailState.message));
    }

    if (detailState is HomeworkDetailSuccess && (classesState is MyClassesSuccess || classesState is MyClassesRefreshing)) {
      final homework = detailState.homework;
      final classes = classesState is MyClassesSuccess
          ? classesState.classes
          : (classesState as MyClassesRefreshing).classes;

      // Extract sections with same subject, skipping source section
      final targetSections = classes.where((cg) {
        if (cg.classId == homework.classId && cg.sectionId == homework.sectionId) {
          return false;
        }
        return cg.assignments.any((asg) => asg.subjectId == homework.subjectId);
      }).toList();

      if (targetSections.isEmpty) {
        return Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 48, color: theme.colorScheme.primary),
              SizedBox(height: spacing.md),
              Text(
                'No other sections available',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing.xs),
              Text(
                'You do not teach this subject in any other class sections.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copy assignment to other sections:',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'Subject: ${homework.title}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.md),
            if (formState is HomeworkFormError) ...[
              Container(
                padding: EdgeInsets.all(spacing.md),
                margin: EdgeInsets.only(bottom: spacing.md),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(radius.sm),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  formState.message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: targetSections.length,
                itemBuilder: (context, index) {
                  final cg = targetSections[index];
                  final isSelected = _selectedSectionIds.contains(cg.sectionId);

                  return CheckboxListTile(
                    title: Text('${cg.className} - ${cg.sectionName}'),
                    subtitle: const Text('Same Subject Taught'),
                    value: isSelected,
                    onChanged: formState is HomeworkFormSubmitting
                        ? null
                        : (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSectionIds.add(cg.sectionId);
                              } else {
                                _selectedSectionIds.remove(cg.sectionId);
                              }
                            });
                          },
                  );
                },
              ),
            ),
            SizedBox(height: spacing.md),
            if (formState is HomeworkFormSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _submitCopy(homework.schoolId),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text('Copy to ${_selectedSectionIds.length} Selected Sections'),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
