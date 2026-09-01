import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/communication_provider.dart';
import 'package:edupulse_models/edupulse_models.dart';

class QueriesInboxScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const QueriesInboxScreen({super.key, this.studentId});

  @override
  ConsumerState<QueriesInboxScreen> createState() => _QueriesInboxScreenState();
}

class _QueriesInboxScreenState extends ConsumerState<QueriesInboxScreen> {
  final _searchController = TextEditingController();

  String? _selectedStatus;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(principalQueriesProvider.notifier).fetchRequests(studentId: widget.studentId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(principalQueriesProvider.notifier).fetchRequests(
          status: _selectedStatus == 'ALL' ? null : _selectedStatus,
          category: _selectedCategory == 'ALL' ? null : _selectedCategory,
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          studentId: widget.studentId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final queriesState = ref.watch(principalQueriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduPulse Connect Leadership Inbox'),
      ),
      body: Column(
        children: [
          // Filter & Search Bar
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              children: [
                // Search box
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by subject or creator...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _applyFilters,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                SizedBox(height: spacing.sm),
                Row(
                  children: [
                    // Status Selector
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus ?? 'ALL',
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                          DropdownMenuItem(value: 'ACKNOWLEDGED', child: Text('Acknowledged')),
                          DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                          DropdownMenuItem(value: 'WAITING_FOR_PARENT', child: Text('Waiting')),
                          DropdownMenuItem(value: 'ESCALATED', child: Text('Escalated')),
                          DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedStatus = val;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    // Category Selector
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory ?? 'ALL',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                          DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic')),
                          DropdownMenuItem(value: 'ATTENDANCE', child: Text('Attendance')),
                          DropdownMenuItem(value: 'BEHAVIORAL', child: Text('Behavioral')),
                          DropdownMenuItem(value: 'FINANCIAL', child: Text('Financial')),
                          DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Requests list
          Expanded(
            child: queriesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : queriesState.requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: theme.colorScheme.outline),
                            SizedBox(height: spacing.md),
                            Text(
                              'No requests matching filter criteria',
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _applyFilters(),
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          itemCount: queriesState.requests.length,
                          itemBuilder: (context, index) {
                            final req = queriesState.requests[index];
                            final statusColor = _getStatusColor(req.status);
                            final isEscalated = req.status.toUpperCase() == 'ESCALATED' ||
                                req.status.toUpperCase() == 'PRINCIPAL_REVIEW';

                            return Card(
                              margin: EdgeInsets.only(bottom: spacing.md),
                              elevation: isEscalated ? 2 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius.md),
                                side: BorderSide(
                                  color: isEscalated
                                      ? Colors.red
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  width: isEscalated ? 1.5 : 1,
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
                                          Row(
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
                                              if (isEscalated) ...[
                                                SizedBox(width: spacing.sm),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius: BorderRadius.circular(radius.sm),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.warning, size: 10, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'ESCALATED',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          _getPriorityBadge(req.priority, spacing, radius, theme),
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
                                          Icon(Icons.category_outlined, size: 14, color: theme.colorScheme.outline),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            req.category,
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                          ),
                                          SizedBox(width: spacing.md),
                                          Icon(Icons.assignment_ind_outlined, size: 14, color: theme.colorScheme.outline),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            req.assignedToId != null ? 'Assigned' : 'Unassigned',
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacing.sm),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          'Last Action: ${_formatDate(req.updatedAt)}',
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
