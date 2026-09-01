import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/communication_provider.dart';
import 'package:edupulse_models/edupulse_models.dart';
import '../../../../core/router/routes.dart';

class QueriesInboxScreen extends ConsumerStatefulWidget {
  const QueriesInboxScreen({super.key});

  @override
  ConsumerState<QueriesInboxScreen> createState() => _QueriesInboxScreenState();
}

class _QueriesInboxScreenState extends ConsumerState<QueriesInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherQueriesProvider.notifier).fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final queriesState = ref.watch(teacherQueriesProvider);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parent Queries Inbox'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'New'),
              Tab(text: 'Assigned'),
              Tab(text: 'In Progress'),
              Tab(text: 'Waiting'),
              Tab(text: 'Escalated'),
              Tab(text: 'Resolved'),
            ],
          ),
        ),
        body: queriesState.isLoading && queriesState.requests.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildTabContent('OPEN', queriesState.requests, spacing, radius, theme),
                  _buildTabContent('ACKNOWLEDGED', queriesState.requests, spacing, radius, theme),
                  _buildTabContent('IN_PROGRESS', queriesState.requests, spacing, radius, theme),
                  _buildTabContent('WAITING_FOR_PARENT', queriesState.requests, spacing, radius, theme),
                  _buildTabContent('ESCALATED', queriesState.requests, spacing, radius, theme),
                  _buildTabContent('RESOLVED', queriesState.requests, spacing, radius, theme),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.studentDirectory),
          icon: const Icon(Icons.people_rounded),
          label: const Text('Student Directory'),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    String targetStatus,
    List<CommunicationRequest> allRequests,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final filtered = allRequests.where((req) {
      final status = req.status.toUpperCase();
      if (targetStatus == 'OPEN') {
        return status == 'OPEN';
      } else if (targetStatus == 'ACKNOWLEDGED') {
        return status == 'ACKNOWLEDGED';
      } else if (targetStatus == 'IN_PROGRESS') {
        return status == 'IN_PROGRESS' || status == 'REOPENED';
      } else if (targetStatus == 'WAITING_FOR_PARENT') {
        return status == 'WAITING_FOR_PARENT';
      } else if (targetStatus == 'ESCALATED') {
        return status == 'ESCALATED' || status == 'PRINCIPAL_REVIEW';
      } else {
        return status == 'RESOLVED';
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: theme.colorScheme.outline),
            SizedBox(height: spacing.sm),
            Text(
              'No requests in this category',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(teacherQueriesProvider.notifier).fetchRequests(),
      child: ListView.builder(
        padding: EdgeInsets.all(spacing.md),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final req = filtered[index];
          final priorityColor = _getPriorityColor(req.priority);

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
                        Text(
                          'Category: ${req.category}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                          child: Text(
                            req.priority,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      req.subject,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 14, color: Colors.grey),
                            SizedBox(width: spacing.xs),
                            Text(
                              'Recipient: ${req.recipientType}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          _formatDate(req.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'NORMAL':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
