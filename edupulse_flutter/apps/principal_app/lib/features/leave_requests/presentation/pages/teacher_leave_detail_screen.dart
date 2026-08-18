import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/leave_request_model.dart';
import '../providers/leave_requests_provider.dart';

class TeacherLeaveDetailScreen extends ConsumerStatefulWidget {
  final String leaveId;

  const TeacherLeaveDetailScreen({super.key, required this.leaveId});

  @override
  ConsumerState<TeacherLeaveDetailScreen> createState() => _TeacherLeaveDetailScreenState();
}

class _TeacherLeaveDetailScreenState extends ConsumerState<TeacherLeaveDetailScreen> {
  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateTimeStr);
      return DateFormat('dd MMM yyyy hh:mm a').format(dt);
    } catch (_) {
      return dateTimeStr;
    }
  }

  int _calculateDays(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _handleApprove(LeaveRequest request) async {
    final theme = Theme.of(context);
    _remarksController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teacher: ${request.teacherName}'),
            Text('Leave: ${request.leaveType}'),
            Text('Dates: ${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                hintText: 'Reviewer remarks (optional)',
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(teacherLeaveDetailProvider(widget.leaveId).notifier)
          .reviewRequest('APPROVE', _remarksController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Leave request approved successfully.' : 'Failed to approve leave request.'),
            backgroundColor: success ? Colors.green : theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(LeaveRequest request) async {
    final theme = Theme.of(context);
    _remarksController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teacher: ${request.teacherName}'),
            Text('Leave: ${request.leaveType}'),
            Text('Dates: ${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                hintText: 'Rejection reason is required',
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              if (_remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason for rejection is required.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(teacherLeaveDetailProvider(widget.leaveId).notifier)
          .reviewRequest('REJECT', _remarksController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Leave request rejected successfully.' : 'Failed to reject leave request.'),
            backgroundColor: success ? Colors.red : theme.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(teacherLeaveDetailProvider(widget.leaveId));

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && state.request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Request Details')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                SizedBox(height: spacing.md),
                Text(state.errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                SizedBox(height: spacing.md),
                ElevatedButton(
                  onPressed: () => ref.read(teacherLeaveDetailProvider(widget.leaveId).notifier).fetchDetail(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final request = state.request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Request Details')),
        body: const Center(child: Text('Leave request could not be found.')),
      );
    }

    final days = _calculateDays(request.startDate, request.endDate);
    final isPending = request.status.toUpperCase() == 'PENDING';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request Details'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(spacing.md),
            children: [
              // Error feedback from review action
              if (state.errorMessage != null) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
                SizedBox(height: spacing.md),
              ],

              // Success feedback from review action
              if (state.reviewSuccessMessage != null) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Text(
                      state.reviewSuccessMessage!,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: spacing.md),
              ],

              // Profile Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.teacherName,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.teacherDesignation ?? 'Teacher'} | ${request.teacherDepartment ?? 'Staff'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          _buildStatusBadge(context, request.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // Details section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Information',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      _buildDetailRow(context, label: 'Leave Type', value: request.leaveType),
                      SizedBox(height: spacing.sm),
                      _buildDetailRow(context, label: 'Start Date', value: _formatDate(request.startDate)),
                      SizedBox(height: spacing.sm),
                      _buildDetailRow(context, label: 'End Date', value: _formatDate(request.endDate)),
                      SizedBox(height: spacing.sm),
                      _buildDetailRow(context, label: 'Duration', value: '$days days'),
                      SizedBox(height: spacing.sm),
                      _buildDetailRow(context, label: 'Requested At', value: _formatDateTime(request.requestedAt)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // Reason
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason for Leave',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      Text(request.reason, style: theme.textTheme.bodyMedium),
                      if (request.remarks != null && request.remarks!.isNotEmpty) ...[
                        SizedBox(height: spacing.md),
                        Text(
                          'Additional Remarks',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 4),
                        Text(request.remarks!, style: theme.textTheme.bodyMedium),
                      ]
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),

              // Review / Cancel info
              if (request.status.toUpperCase() == 'APPROVED' || request.status.toUpperCase() == 'REJECTED')
                Card(
                  color: request.status.toUpperCase() == 'APPROVED'
                      ? Colors.green.shade50.withValues(alpha: 0.3)
                      : Colors.red.shade50.withValues(alpha: 0.3),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Decision Details',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow(
                          context,
                          label: 'Reviewed At',
                          value: request.reviewedAt != null ? _formatDateTime(request.reviewedAt!) : 'N/A',
                        ),
                        if (request.reviewerRemarks != null && request.reviewerRemarks!.isNotEmpty) ...[
                          SizedBox(height: spacing.sm),
                          _buildDetailRow(
                            context,
                            label: 'Remarks',
                            value: request.reviewerRemarks!,
                          ),
                        ]
                      ],
                    ),
                  ),
                ),

              if (request.status.toUpperCase() == 'CANCELLED')
                Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancellation Details',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow(
                          context,
                          label: 'Cancelled At',
                          value: request.cancelledAt != null ? _formatDateTime(request.cancelledAt!) : 'N/A',
                        ),
                        if (request.cancellationReason != null && request.cancellationReason!.isNotEmpty) ...[
                          SizedBox(height: spacing.sm),
                          _buildDetailRow(
                            context,
                            label: 'Reason',
                            value: request.cancellationReason!,
                          ),
                        ]
                      ],
                    ),
                  ),
                ),

              SizedBox(height: spacing.lg),

              // Buttons row for pending review
              if (isPending)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: EdgeInsets.symmetric(vertical: spacing.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject Leave'),
                        onPressed: state.isReviewing ? null : () => _handleReject(request),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: spacing.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve Leave'),
                        onPressed: state.isReviewing ? null : () => _handleApprove(request),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: spacing.md),

              // View history button
              OutlinedButton.icon(
                icon: const Icon(Icons.history_rounded),
                label: const Text('View Leave History'),
                onPressed: () {
                  context.push('/teacher-leaves/teacher/${request.teacherId}/history');
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: spacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                ),
              ),
            ],
          ),
          if (state.isReviewing)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color color;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        color = Colors.green;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      case 'CANCELLED':
        color = Colors.grey;
        break;
      default:
        color = Colors.amber.shade700;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
