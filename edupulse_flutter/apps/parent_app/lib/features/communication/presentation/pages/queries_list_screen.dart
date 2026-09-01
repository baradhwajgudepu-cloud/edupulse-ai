import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/communication_provider.dart';

class QueriesListScreen extends ConsumerStatefulWidget {
  const QueriesListScreen({super.key});

  @override
  ConsumerState<QueriesListScreen> createState() => _QueriesListScreenState();
}

class _QueriesListScreenState extends ConsumerState<QueriesListScreen> {
  StudentProfile? _selectedStudent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardState = ref.read(dashboardStateProvider);
      if (dashboardState is DashboardSuccess && dashboardState.data.students.isNotEmpty) {
        setState(() {
          _selectedStudent = dashboardState.data.selectedStudent ?? dashboardState.data.students.first;
        });
        ref.read(queriesListProvider.notifier).fetchRequests(studentId: _selectedStudent?.id);
      } else {
        ref.read(queriesListProvider.notifier).fetchRequests();
      }
    });
  }

  void _onStudentChanged(StudentProfile? student) {
    if (student != null) {
      setState(() {
        _selectedStudent = student;
      });
      ref.read(queriesListProvider.notifier).fetchRequests(studentId: student.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dashboardState = ref.watch(dashboardStateProvider);
    final queriesState = ref.watch(queriesListProvider);

    List<StudentProfile> students = [];
    if (dashboardState is DashboardSuccess) {
      students = dashboardState.data.students;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduPulse Connect'),
      ),
      body: Column(
        children: [
          // Student Dropdown Selector
          if (students.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.face_rounded, color: Colors.grey),
                  SizedBox(width: spacing.sm),
                  Text('Child: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StudentProfile>(
                        value: _selectedStudent,
                        items: students.map((std) {
                          return DropdownMenuItem(
                            value: std,
                            child: Text(std.fullName),
                          );
                        }).toList(),
                        onChanged: _onStudentChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Error Message
          if (queriesState.errorMessage != null)
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Text(
                queriesState.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // List of Queries
          Expanded(
            child: queriesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : queriesState.requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                            SizedBox(height: spacing.md),
                            Text(
                              'No communication requests found',
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(queriesListProvider.notifier)
                            .fetchRequests(studentId: _selectedStudent?.id),
                        child: ListView.builder(
                          padding: EdgeInsets.all(spacing.md),
                          itemCount: queriesState.requests.length,
                          itemBuilder: (context, index) {
                            final req = queriesState.requests[index];
                            final statusColor = _getStatusColor(req.status);

                            return Card(
                              margin: EdgeInsets.only(bottom: spacing.md),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius.md),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(radius.md),
                                onTap: () => context.push('/communication/details/${req.id}'),
                                child: Padding(
                                  padding: EdgeInsets.all(spacing.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(radius.sm),
                                            ),
                                            child: Text(
                                              req.status,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              _getPriorityBadge(req.priority, spacing, radius, theme),
                                              if (req.unreadMessagesCount > 0) ...[
                                                SizedBox(width: spacing.sm),
                                                Badge(label: Text(req.unreadMessagesCount.toString())),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacing.sm),
                                      Text(
                                        req.subject,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: spacing.xs),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            'To: ${req.recipientType}',
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                          ),
                                          SizedBox(width: spacing.md),
                                          Icon(Icons.category_outlined, size: 14, color: theme.colorScheme.outline),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            req.category,
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacing.sm),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          'Updated: ${_formatDate(req.updatedAt)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.outline,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/communication/new'),
        label: const Text('New Request'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.blue;
      case 'ACKNOWLEDGED':
        return Colors.teal;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'WAITING_FOR_PARENT':
        return Colors.deepPurple;
      case 'ESCALATED':
        return Colors.red;
      case 'RESOLVED':
        return Colors.green;
      case 'REOPENED':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget _getPriorityBadge(String priority, AppSpacing spacing, AppRadius radius, ThemeData theme) {
    Color color;
    switch (priority.toUpperCase()) {
      case 'URGENT':
        color = Colors.red;
        break;
      case 'HIGH':
        color = Colors.orange;
        break;
      case 'NORMAL':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
