import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../providers/student_provider.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentsStateProvider.notifier).init();
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
      ref.read(studentsStateProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    _searchController.clear();
    await ref.read(studentsStateProvider.notifier).init();
  }

  void _onSearchChanged(String value) {
    ref.read(studentsStateProvider.notifier).setFilters(search: value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(studentsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all_rounded),
            tooltip: 'Clear Filters',
            onPressed: () {
              _searchController.clear();
              ref.read(studentsStateProvider.notifier).clearFilters();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, roll number...',
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
                SizedBox(height: spacing.sm),
                if (state is StudentsSuccess)
                  Row(
                    children: [
                      // Class Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: state.selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Class',
                            contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(radius.sm),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Classes'),
                            ),
                            ...state.discoveredClasses.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                )),
                          ],
                          onChanged: (val) {
                            ref.read(studentsStateProvider.notifier).setFilters(selectedClass: val);
                          },
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      // Section Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: state.selectedSection,
                          decoration: InputDecoration(
                            labelText: 'Section',
                            contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(radius.sm),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Sections'),
                            ),
                            ...state.discoveredSections.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                )),
                          ],
                          onChanged: (val) {
                            ref.read(studentsStateProvider.notifier).setFilters(selectedSection: val);
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Directory List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: switch (state) {
                StudentsInitial() => const Center(child: CircularProgressIndicator()),
                StudentsLoading() => const Center(child: CircularProgressIndicator()),
                StudentsError(:final message) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(spacing.lg),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          SizedBox(height: spacing.sm),
                          Text(
                            'Failed to load students',
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
                StudentsSuccess(:final students, :final hasReachedMax) => students.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey),
                              SizedBox(height: spacing.sm),
                              Text(
                                'No Students Found',
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                              ),
                              SizedBox(height: spacing.xs),
                              const Text(
                                'Try clearing filters or changing your search query.',
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
                        itemCount: students.length + (hasReachedMax ? 0 : 1),
                        separatorBuilder: (context, index) => SizedBox(height: spacing.xs),
                        itemBuilder: (context, index) {
                          if (index == students.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final student = students[index];
                          final statusColor = student.status == 'ACTIVE' ? Colors.green : Colors.orange;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius.md),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: student.photoUrl != null && student.photoUrl!.isNotEmpty
                                    ? NetworkImage(student.photoUrl!)
                                    : null,
                                child: student.photoUrl == null || student.photoUrl!.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Class ${student.className} - ${student.sectionName}'),
                                  Text(
                                    'Adm: ${student.admissionNumber} | Roll: ${student.rollNumber}',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  student.status,
                                  style: TextStyle(color: statusColor.shade900, fontSize: 10),
                                ),
                                backgroundColor: statusColor.shade100,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onTap: () {
                                context.push(AppRoutes.studentDetail.replaceAll(':id', student.id));
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
