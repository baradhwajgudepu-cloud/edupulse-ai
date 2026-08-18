import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../providers/teacher_leave_provider.dart';
import '../widgets/leave_status_badge.dart';
import '../widgets/leave_type_badge.dart';

class TeacherLeaveDetailScreen extends ConsumerStatefulWidget {
  final String leaveId;

  const TeacherLeaveDetailScreen({
    super.key,
    required this.leaveId,
  });

  @override
  ConsumerState<TeacherLeaveDetailScreen> createState() => _TeacherLeaveDetailScreenState();
}

class _TeacherLeaveDetailScreenState extends ConsumerState<TeacherLeaveDetailScreen> {
  final _cancelReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherLeaveDetailProvider(widget.leaveId).notifier).fetchDetail();
    });
  }

  @override
  void dispose() {
    _cancelReasonController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null || dtStr.isEmpty) return '--';
    try {
      final parsed = DateTime.parse(dtStr).toLocal();
      return DateFormat('MMM d, yyyy hh:mm a').format(parsed);
    } catch (_) {
      return dtStr;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  void _showCancelDialog(BuildContext context) {
    _cancelReasonController.clear();
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cancel this leave request? Please provide a cancellation reason.'),
              SizedBox(height: spacing.md),
              TextField(
                controller: _cancelReasonController,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _cancelReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cancellation reason cannot be empty.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                ref.read(teacherLeaveCancelNotifierProvider.notifier).cancelLeave(
                      leaveId: widget.leaveId,
                      cancellationReason: reason,
                    );
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final state = ref.watch(teacherLeaveDetailProvider(widget.leaveId));
    final cancelState = ref.watch(teacherLeaveCancelNotifierProvider);

    ref.listen<TeacherLeaveCancelState>(teacherLeaveCancelNotifierProvider, (prev, next) {
      if (next is TeacherLeaveCancelSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request cancelled successfully.')),
        );
        ref.read(teacherLeaveCancelNotifierProvider.notifier).reset();
      } else if (next is TeacherLeaveCancelError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(teacherLeaveCancelNotifierProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request Details'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(teacherLeaveDetailProvider(widget.leaveId).notifier).fetchDetail(isSilent: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(spacing.lg),
            child: Builder(
              builder: (context) {
                switch (state) {
                  case TeacherLeaveDetailInitial():
                  case TeacherLeaveDetailLoading():
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  case TeacherLeaveDetailError(:final message):
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Text(
                              message,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            SizedBox(height: spacing.md),
                            ElevatedButton(
                              onPressed: () => ref.read(teacherLeaveDetailProvider(widget.leaveId).notifier).fetchDetail(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  case TeacherLeaveDetailLoaded(:final leave):
                    final isPending = leave.status == 'PENDING';
                    final isCancelled = leave.status == 'CANCELLED';
                    final isApproved = leave.status == 'APPROVED';
                    final isRejected = leave.status == 'REJECTED';
                    final isCancelLoading = cancelState is TeacherLeaveCancelLoading;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            LeaveTypeBadge(leaveType: leave.leaveType),
                            LeaveStatusBadge(status: leave.status),
                          ],
                        ),
                        SizedBox(height: spacing.lg),
                        _buildDetailItem(context, label: 'Date Range', value: '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}'),
                        _buildDetailItem(context, label: 'Duration', value: '${leave.durationDays} ${leave.durationDays == 1 ? "day" : "days"}'),
                        _buildDetailItem(context, label: 'Reason', value: leave.reason),
                        if (leave.remarks != null)
                          _buildDetailItem(context, label: 'Remarks', value: leave.remarks!),
                        _buildDetailItem(context, label: 'Requested Date', value: _formatDateTime(leave.requestedAt)),
                        if (isApproved || isRejected) ...[
                          const Divider(),
                          SizedBox(height: spacing.md),
                          Text(
                            'Review Details',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: spacing.sm),
                          _buildDetailItem(context, label: 'Reviewed Date', value: _formatDateTime(leave.reviewedAt)),
                          if (leave.reviewerRemarks != null)
                            _buildDetailItem(context, label: 'Reviewer Remarks', value: leave.reviewerRemarks!),
                        ],
                        if (isCancelled) ...[
                          const Divider(),
                          SizedBox(height: spacing.md),
                          Text(
                            'Cancellation Details',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: spacing.sm),
                          _buildDetailItem(context, label: 'Cancelled Date', value: _formatDateTime(leave.cancelledAt)),
                          if (leave.cancellationReason != null)
                            _buildDetailItem(context, label: 'Cancellation Reason', value: leave.cancellationReason!),
                        ],
                        if (isPending) ...[
                          SizedBox(height: spacing.xl),
                          ElevatedButton.icon(
                            onPressed: isCancelLoading ? null : () => _showCancelDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              disabledBackgroundColor: theme.colorScheme.error.withOpacity(0.5),
                            ),
                            icon: isCancelLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cancel_rounded),
                            label: const Text('Cancel Request'),
                          ),
                        ],
                      ],
                    );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
