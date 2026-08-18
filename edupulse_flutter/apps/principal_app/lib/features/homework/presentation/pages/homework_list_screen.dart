import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/homework_provider.dart';

class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeworkStateProvider.notifier).fetchHomeworks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(homeworkStateProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeworkStateProvider.notifier).fetchHomeworks(isRefresh: true),
        child: switch (state) {
          HomeworkInitial() => const Center(child: CircularProgressIndicator()),
          HomeworkLoading() => const Center(child: CircularProgressIndicator()),
          HomeworkError(:final message) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(spacing.lg),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    SizedBox(height: spacing.sm),
                    const Text('Failed to load homework logs.'),
                    Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    SizedBox(height: spacing.md),
                    ElevatedButton(
                      onPressed: () => ref.read(homeworkStateProvider.notifier).fetchHomeworks(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          HomeworkSuccess(:final homeworks) => homeworks.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: spacing.sm),
                        const Text('No homework assignments recorded.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(spacing.md),
                  itemCount: homeworks.length,
                  separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                  itemBuilder: (context, index) {
                    final homework = homeworks[index];
                    
                    final Color priorityColor = homework.priority == 'HIGH'
                        ? Colors.red
                        : homework.priority == 'MEDIUM'
                            ? Colors.orange
                            : Colors.blue;
                            
                    final Color statusColor = homework.status == 'PUBLISHED'
                        ? Colors.green
                        : homework.status == 'DRAFT'
                            ? Colors.amber
                            : Colors.grey;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius.md),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Title & Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    homework.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(radius.sm),
                                  ),
                                  child: Text(
                                    homework.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: spacing.xs),
                            
                            // Subtitle Metadata: Subject & Due Date
                            Text(
                              'Subject ID: ${homework.subjectId.substring(0, 8)} | Due Date: ${homework.dueDate}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.black54),
                            ),
                            
                            SizedBox(height: spacing.sm),
                            
                            // Description
                            Text(
                              homework.description,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                            ),
                            
                            const Divider(height: 20),
                            
                            // Footer: Priority Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.label_important_outline, size: 16, color: priorityColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Priority: ${homework.priority}',
                                      style: TextStyle(
                                        color: priorityColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.description_outlined, size: 18, color: theme.colorScheme.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        },
      ),
    );
  }
}
