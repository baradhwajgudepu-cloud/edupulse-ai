import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/student_directory_provider.dart';
import '../../../../core/router/routes.dart';

class StudentDirectoryScreen extends ConsumerStatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  ConsumerState<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends ConsumerState<StudentDirectoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentDirectoryStateProvider.notifier).fetchStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(studentDirectoryStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, roll no, class...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(studentDirectoryStateProvider.notifier).searchLocal('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
              ),
              onChanged: (val) {
                ref.read(studentDirectoryStateProvider.notifier).searchLocal(val);
                setState(() {});
              },
            ),
          ),

          // Main Directory List
          Expanded(
            child: Builder(
              builder: (context) {
                if (state is StudentDirectoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is StudentDirectoryError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                          SizedBox(height: spacing.md),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton.icon(
                            onPressed: () => ref.read(studentDirectoryStateProvider.notifier).fetchStudents(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is StudentDirectoryEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 48),
                        SizedBox(height: spacing.md),
                        Text(
                          'No students assigned under your care.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                List<dynamic> studentsList = [];
                String currentQuery = '';
                if (state is StudentDirectorySuccess) {
                  studentsList = state.filteredStudents;
                  currentQuery = state.query;
                } else if (state is StudentDirectoryRefreshing) {
                  studentsList = state.filteredStudents;
                  currentQuery = state.query;
                }

                if (studentsList.isEmpty && currentQuery.isNotEmpty) {
                  return Center(
                    child: Text('No results match "$currentQuery".'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(studentDirectoryStateProvider.notifier).fetchStudents(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: spacing.md),
                    itemCount: studentsList.length,
                    itemBuilder: (context, index) {
                      final student = studentsList[index];
                      final avatarColor = _getAvatarColor(student.fullName, theme);

                      return Card(
                        margin: EdgeInsets.only(bottom: spacing.sm),
                        elevation: 0,
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(spacing.md),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: avatarColor.withOpacity(0.1),
                            child: Text(
                              student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : 'S',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: avatarColor,
                              ),
                            ),
                          ),
                          title: Text(
                            student.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: spacing.xs),
                              Text(
                                'Class: ${student.className} | Sec: ${student.sectionName}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              Wrap(
                                spacing: spacing.xs,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(radius.xs),
                                    ),
                                    child: Text(
                                      'Roll: ${student.rollNumber}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(radius.xs),
                                    ),
                                    child: Text(
                                      'Adm: ${student.admissionNumber}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () {
                            context.push(
                              '${AppRoutes.studentDetail}?studentId=${student.id}',
                              extra: student,
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
