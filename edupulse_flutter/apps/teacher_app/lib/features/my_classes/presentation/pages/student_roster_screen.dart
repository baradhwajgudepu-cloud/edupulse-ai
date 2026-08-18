import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../providers/my_classes_provider.dart';
import '../../domain/entities/student.dart';
import '../../../../core/router/routes.dart';

class StudentRosterScreen extends ConsumerStatefulWidget {
  final String classId;
  final String sectionId;
  final String className;
  final String sectionName;

  const StudentRosterScreen({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
  });

  @override
  ConsumerState<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends ConsumerState<StudentRosterScreen> {
  late final TextEditingController _searchController;
  late final String _providerKey;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _providerKey = '${widget.classId}:${widget.sectionId}';
    Future.microtask(() {
      ref.read(studentRosterStateProvider(_providerKey).notifier).fetchStudents();
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
    final state = ref.watch(studentRosterStateProvider(_providerKey));
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Roster - ${widget.className} (${widget.sectionName})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Column(
        children: [
          _buildSearchBox(theme, spacing, radius),
          Expanded(
            child: _buildBody(state, theme, spacing, radius),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          ref.read(studentRosterStateProvider(_providerKey).notifier).searchLocal(val);
        },
        decoration: InputDecoration(
          hintText: 'Search by name, roll, or admission #',
          prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(studentRosterStateProvider(_providerKey).notifier).searchLocal('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius.md),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius.md),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius.md),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    StudentRosterState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    if (state is StudentRosterLoading || state is StudentRosterInitial) {
      return _buildSkeletonLoader(spacing, radius);
    }

    if (state is StudentRosterError) {
      return _buildErrorState(state.message, theme, spacing, radius);
    }

    if (state is StudentRosterEmpty) {
      return _buildEmptyState(theme, spacing, radius);
    }

    List<StudentEntity> students = [];
    bool isRefreshing = false;

    if (state is StudentRosterSuccess) {
      students = state.filteredStudents;
    } else if (state is StudentRosterRefreshing) {
      students = state.filteredStudents;
      isRefreshing = true;
    }

    if (students.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoSearchResultsState(theme, spacing, radius);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(studentRosterStateProvider(_providerKey).notifier).fetchStudents(),
      child: Column(
        children: [
          if (isRefreshing)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              itemCount: students.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
              itemBuilder: (context, index) {
                final student = students[index];
                return _buildStudentRow(student, theme, spacing, radius);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(
    StudentEntity student,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final avatarColor = _getAvatarColor(student.fullName, theme);
    final initials = '${student.firstName.isNotEmpty ? student.firstName[0] : ''}${student.lastName.isNotEmpty ? student.lastName[0] : ''}';

    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.xs),
      onTap: () {
        context.push(
          '${AppRoutes.studentDetail}?studentId=${student.id}',
          extra: student,
        );
      },
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Roll number
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Text(
              student.rollNumber.padLeft(2, '0'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
          // Circle Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor.withOpacity(0.1),
            backgroundImage: student.photoUrl != null && student.photoUrl!.isNotEmpty
                ? NetworkImage(student.photoUrl!)
                : null,
            child: student.photoUrl == null || student.photoUrl!.isEmpty
                ? Text(
                    initials,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ],
      ),
      title: Text(
        student.fullName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        'Adm: ${student.admissionNumber}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSkeletonLoader(AppSpacing spacing, AppRadius radius) {
    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: 6,
      separatorBuilder: (context, index) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) {
        return Row(
          children: [
            Container(
              width: 24,
              height: 14,
              color: Colors.grey[200],
            ),
            SizedBox(width: spacing.sm),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 16,
                    color: Colors.grey[200],
                  ),
                  SizedBox(height: spacing.xs),
                  Container(
                    width: 80,
                    height: 12,
                    color: Colors.grey[200],
                  ),
                ],
              ),
            ),
          ],
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
              Icons.people_outline_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            SizedBox(height: spacing.md),
            Text(
              'No Students Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'No students found in this section.',
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

  Widget _buildNoSearchResultsState(
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
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            SizedBox(height: spacing.md),
            Text(
              'No Results Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'No matching students found.',
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
              'Failed to Load Roster',
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
                ref.read(studentRosterStateProvider(_providerKey).notifier).fetchStudents();
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
