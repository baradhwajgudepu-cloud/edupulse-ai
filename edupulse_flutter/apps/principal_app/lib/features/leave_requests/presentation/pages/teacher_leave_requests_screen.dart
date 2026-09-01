import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/leave_requests_provider.dart';
import '../../data/models/leave_request_model.dart';
import '../../../dashboard/presentation/providers/active_school_provider.dart';

class TeacherLeaveRequestsScreen extends ConsumerStatefulWidget {
  const TeacherLeaveRequestsScreen({super.key});

  @override
  ConsumerState<TeacherLeaveRequestsScreen> createState() => _TeacherLeaveRequestsScreenState();
}

class _TeacherLeaveRequestsScreenState extends ConsumerState<TeacherLeaveRequestsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _rejectionController = TextEditingController();

  String _selectedStatus = 'PENDING';
  String _selectedType = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isLoadMore: true);
    }
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

  int _calculateDays(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  void _applyFilters() {
    ref.read(leaveRequestsStateProvider.notifier).setFilters(
          status: _selectedStatus,
          leaveType: _selectedType,
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  Future<void> _showApproveDialog(BuildContext context, LeaveRequest request) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave Request?'),
        content: Text(
          'Approve leave request for ${request.teacherName} from ${_formatDate(request.startDate)} to ${_formatDate(request.endDate)}?',
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
      final success = await ref.read(leaveRequestsStateProvider.notifier).approveLeave(request.id);
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

  Future<void> _showRejectDialog(BuildContext context, LeaveRequest request) async {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    _rejectionController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject leave request for ${request.teacherName} from ${_formatDate(request.startDate)} to ${_formatDate(request.endDate)}?',
            ),
            SizedBox(height: spacing.md),
            TextField(
              controller: _rejectionController,
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
              if (_rejectionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
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
          .read(leaveRequestsStateProvider.notifier)
          .rejectLeave(request.id, _rejectionController.text.trim());
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
    final state = ref.watch(leaveRequestsStateProvider);
    final activeSchoolId = ref.watch(activeSchoolIdProvider);

    // Calculate actual counts from currently loaded request list
    final pendingCount = state.requests.where((r) => r.status.toUpperCase() == 'PENDING').length;
    final approvedCount = state.requests.where((r) => r.status.toUpperCase() == 'APPROVED').length;
    final rejectedCount = state.requests.where((r) => r.status.toUpperCase() == 'REJECTED').length;
    final cancelledCount = state.requests.where((r) => r.status.toUpperCase() == 'CANCELLED').length;

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
        title: const Text('Teacher Leave Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isRefresh: true),
          ),
        ],
      ),
      body: activeSchoolId == null || activeSchoolId.isEmpty
          ? const Center(child: Text('Please select a school context.'))
          : Stack(
              children: [
                Column(
                  children: [
                    // Summary cards
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        crossAxisSpacing: spacing.sm,
                        mainAxisSpacing: spacing.sm,
                        childAspectRatio: 1.2,
                        children: [
                          _buildSummaryCard(context, 'Pending', pendingCount, Colors.amber.shade700),
                          _buildSummaryCard(context, 'Approved', approvedCount, Colors.green),
                          _buildSummaryCard(context, 'Rejected', rejectedCount, Colors.red),
                          _buildSummaryCard(context, 'Cancelled', cancelledCount, Colors.grey),
                        ],
                      ),
                    ),

                    // Filter block
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Leave Type',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                                DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
                                DropdownMenuItem(value: 'SICK', child: Text('Sick')),
                                DropdownMenuItem(value: 'EARNED', child: Text('Earned')),
                                DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedType = val);
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                                    : 'Dates',
                              ),
                              onPressed: _selectDateRange,
                            ),
                          ),
                          if (_startDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearDateRange,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      child: Row(
                        children: [
                          _buildFilterTab('PENDING', 'Pending'),
                          SizedBox(width: spacing.xs),
                          _buildFilterTab('APPROVED', 'Approved'),
                          SizedBox(width: spacing.xs),
                          _buildFilterTab('REJECTED', 'Rejected'),
                          SizedBox(width: spacing.xs),
                          _buildFilterTab('CANCELLED', 'Cancelled'),
                          SizedBox(width: spacing.xs),
                          _buildFilterTab('ALL', 'All'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Main list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isRefresh: true),
                        child: state.isLoading && state.requests.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : state.errorMessage != null && state.requests.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(state.errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () => ref
                                              .read(leaveRequestsStateProvider.notifier)
                                              .fetchRequests(isRefresh: true),
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : state.requests.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No leave requests found.',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: _scrollController,
                                        padding: EdgeInsets.all(spacing.md),
                                        itemCount: state.requests.length + (state.hasMore ? 1 : 0),
                                        separatorBuilder: (context, index) => SizedBox(height: spacing.md),
                                        itemBuilder: (context, index) {
                                          if (index == state.requests.length) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final item = state.requests[index];
                                          return _buildLeaveCard(context, item);
                                        },
                                      ),
                      ),
                    ),
                  ],
                ),
                if (state.isMutating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String label, int count, Color color) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.sm),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedStatus == value;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = value);
          _applyFilters();
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveRequest request) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color statusColor;
    switch (request.status.toUpperCase()) {
      case 'APPROVED':
        statusColor = Colors.green;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        break;
      case 'CANCELLED':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.amber.shade700;
    }

    final daysCount = _calculateDays(request.startDate, request.endDate);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () => context.push('/teacher-leaves/${request.id}'),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.teacherName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${request.teacherDesignation ?? 'Teacher'} | ${request.teacherDepartment ?? 'Staff'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(radius.sm),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      request.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: spacing.lg),

              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Type',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      Text(
                        request.leaveType,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(width: spacing.xl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      Text(
                        '$daysCount days',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: spacing.md),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dates',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                  Text(
                    '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: spacing.md),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                  Text(request.reason),
                ],
              ),

              if (request.reviewerRemarks != null && request.reviewerRemarks!.isNotEmpty) ...[
                SizedBox(height: spacing.md),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviewer Remarks:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        request.reviewerRemarks!,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (request.status.toUpperCase() == 'PENDING') ...[
                Divider(height: spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      onPressed: () => _showRejectDialog(context, request),
                    ),
                    SizedBox(width: spacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      onPressed: () => _showApproveDialog(context, request),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
