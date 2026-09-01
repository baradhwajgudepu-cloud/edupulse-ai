import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../providers/teacher_provider.dart';

class TeacherListScreen extends ConsumerStatefulWidget {
  const TeacherListScreen({super.key});

  @override
  ConsumerState<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends ConsumerState<TeacherListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teachersStateProvider.notifier).fetchTeachers();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(teachersStateProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    _searchController.clear();
    await ref.read(teachersStateProvider.notifier).fetchTeachers(isRefresh: true);
  }

  void _onSearchChanged(String value) {
    ref.read(teachersStateProvider.notifier).search(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(teachersStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Teacher Directory'),
      ),
      body: Column(
        children: [
          // Search Control
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by teacher name or employee code...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: switch (state) {
                TeachersInitial() => const Center(child: CircularProgressIndicator()),
                TeachersLoading() => const Center(child: CircularProgressIndicator()),
                TeachersError(:final message) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(spacing.lg),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          SizedBox(height: spacing.sm),
                          Text(
                            'Failed to load teachers',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            message,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton.icon(
                            onPressed: _onRefresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                TeachersSuccess(:final teachers, :final hasReachedMax) => teachers.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.badge_outlined, size: 56, color: Colors.grey),
                              SizedBox(height: spacing.sm),
                              Text(
                                'No Teachers Found',
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                              ),
                              SizedBox(height: spacing.xs),
                              const Text(
                                'Try matching another search query.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                        itemCount: teachers.length + (hasReachedMax ? 0 : 1),
                        separatorBuilder: (context, index) => SizedBox(height: spacing.xs),
                        itemBuilder: (context, index) {
                          if (index == teachers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final teacher = teachers[index];
                          final statusColor = teacher.status == 'ACTIVE' ? Colors.green : Colors.orange;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius.md),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  teacher.firstName.isNotEmpty ? teacher.firstName[0] : 'T',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                teacher.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${teacher.designation} - ${teacher.department}'),
                                  Text(
                                    'Code: ${teacher.employeeCode} | Email: ${teacher.officialEmail}',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  teacher.status,
                                  style: TextStyle(color: statusColor.shade900, fontSize: 10),
                                ),
                                backgroundColor: statusColor.shade100,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onTap: () {
                                context.push(AppRoutes.teacherDetail.replaceAll(':id', teacher.id));
                              },
                            ),
                          );
                        },
                      ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
