import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';

import '../../../../core/router/routes.dart';
import '../../domain/entities/homework_entity.dart';
import '../providers/homework_provider.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';

class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
      _fetchHomeworks();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _fetchHomeworks();
    }
  }

  HomeworkStatus _getStatusForTabIndex(int index) {
    switch (index) {
      case 0:
        return HomeworkStatus.PUBLISHED;
      case 1:
        return HomeworkStatus.DRAFT;
      case 2:
        return HomeworkStatus.ARCHIVED;
      default:
        return HomeworkStatus.PUBLISHED;
    }
  }

  void _fetchHomeworks() {
    final status = _getStatusForTabIndex(_tabController.index);
    final search = _searchController.text.trim();
    
    ref.read(homeworkListProvider.notifier).fetchHomeworks(
      status: status,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      subjectId: _selectedSubjectId,
      search: search.isEmpty ? null : search,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final local = EduLocalization.of(context);

    final homeworkState = ref.watch(homeworkListProvider);
    final classesState = ref.watch(myClassesStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(local?.translate('homework') ?? 'Homework Assignments'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Drafts'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter section
          _buildFilterBar(classesState, theme, spacing, radius, local),
          
          // Search section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title or description...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchHomeworks();
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
              ),
              onChanged: (_) => _fetchHomeworks(),
            ),
          ),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _fetchHomeworks();
              },
              child: _buildListContent(homeworkState, classesState, theme, spacing, radius, local),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push(AppRoutes.homeworkCreate);
          if (result == true) {
            _fetchHomeworks();
          }
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(
    MyClassesState classesState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    List<TeacherClassGroupEntity> classGroups = [];
    if (classesState is MyClassesSuccess) {
      classGroups = classesState.classes;
    } else if (classesState is MyClassesRefreshing) {
      classGroups = classesState.classes;
    }

    // Extract subjects
    final Set<String> subjectIds = {};
    final List<Map<String, String>> subjects = [];
    for (final cg in classGroups) {
      for (final asg in cg.assignments) {
        if (!subjectIds.contains(asg.subjectId)) {
          subjectIds.add(asg.subjectId);
          subjects.add({'id': asg.subjectId, 'name': asg.subjectName});
        }
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          // Class Filter
          DropdownButton<String>(
            hint: const Text('All Classes'),
            value: _selectedClassId == null ? null : '$_selectedClassId:$_selectedSectionId',
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Classes'),
              ),
              ...classGroups.map((cg) {
                return DropdownMenuItem<String>(
                  value: '${cg.classId}:${cg.sectionId}',
                  child: Text('${cg.className} - ${cg.sectionName}'),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                if (val == null) {
                  _selectedClassId = null;
                  _selectedSectionId = null;
                } else {
                  final parts = val.split(':');
                  _selectedClassId = parts[0];
                  _selectedSectionId = parts[1];
                }
              });
              _fetchHomeworks();
            },
          ),
          SizedBox(width: spacing.md),
          // Subject Filter
          DropdownButton<String>(
            hint: const Text('All Subjects'),
            value: _selectedSubjectId,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Subjects'),
              ),
              ...subjects.map((sub) {
                return DropdownMenuItem<String>(
                  value: sub['id'],
                  child: Text(sub['name']!),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedSubjectId = val;
              });
              _fetchHomeworks();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(
    HomeworkListState state,
    MyClassesState classesState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    if (state is HomeworkListLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is HomeworkListError) {
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
                onPressed: _fetchHomeworks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is HomeworkListSuccess) {
      final list = state.homeworks;
      if (list.isEmpty) {
        return _buildEmptyState(theme, spacing, local);
      }

      return ListView.separated(
        padding: EdgeInsets.all(spacing.md),
        itemCount: list.length,
        separatorBuilder: (_, __) => SizedBox(height: spacing.md),
        itemBuilder: (context, index) {
          final homework = list[index];
          return _buildHomeworkCard(homework, classesState, theme, spacing, radius, local);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(ThemeData theme, AppSpacing spacing, EduLocalization? local) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            SizedBox(height: spacing.lg),
            Text(
              'No Homework Assignments',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'Create tasks for your students by tapping the + button.',
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

  Widget _buildHomeworkCard(
    HomeworkEntity homework,
    MyClassesState classesState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    // Resolve display names
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

    final formattedDueDate = DateFormat('dd MMM yyyy').format(homework.dueDate);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          final result = await context.push('${AppRoutes.homeworkDetail}?id=${homework.id}');
          if (result == true) {
            _fetchHomeworks();
          }
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(radius.xs),
                    ),
                    child: Text(
                      subjectName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildPriorityBadge(homework.priority, theme, radius),
                ],
              ),
              SizedBox(height: spacing.sm),
              Text(
                homework.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                homework.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.md),
              const Divider(height: 1),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.class_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      SizedBox(width: spacing.xs),
                      Text(
                        '$className - $sectionName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      SizedBox(width: spacing.xs),
                      Text(
                        'Due: $formattedDueDate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(HomeworkPriority priority, ThemeData theme, AppRadius radius) {
    Color color;
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius.xs),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        priority.name,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
