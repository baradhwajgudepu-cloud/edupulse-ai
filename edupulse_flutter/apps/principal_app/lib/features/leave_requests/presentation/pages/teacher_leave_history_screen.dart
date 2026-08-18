import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/leave_request_model.dart';
import '../providers/leave_requests_provider.dart';

class TeacherLeaveHistoryScreen extends ConsumerStatefulWidget {
  final String teacherId;

  const TeacherLeaveHistoryScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherLeaveHistoryScreen> createState() => _TeacherLeaveHistoryScreenState();
}

class _TeacherLeaveHistoryScreenState extends ConsumerState<TeacherLeaveHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedStatus = 'ALL';
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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(teacherLeaveHistoryStateProvider(widget.teacherId).notifier).fetchHistory(isLoadMore: true);
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
    ref.read(teacherLeaveHistoryStateProvider(widget.teacherId).notifier).setFilters(
          status: _selectedStatus,
          leaveType: _selectedType,
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final state = ref.watch(teacherLeaveHistoryStateProvider(widget.teacherId));

    // Resolve teacher name locally from any history entry or use placeholder
    final String teacherName = state.records.isNotEmpty ? state.records.first.teacherName : 'Teacher';

    return Scaffold(
      appBar: AppBar(
        title: Text('$teacherName Leave History'),
      ),
      body: Column(
        children: [
          // Filters block
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                              DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                              DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedStatus = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_rounded, size: 16),
                            label: Text(
                              _startDate != null && _endDate != null
                                  ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                                  : 'Select Dates',
                            ),
                            onPressed: _selectDateRange,
                          ),
                        ),
                        if (_startDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: _clearDateRange,
                            tooltip: 'Clear Date Filter',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List results
          Expanded(
            child: Stack(
              children: [
                if (state.isLoading && state.records.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (state.errorMessage != null && state.records.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(state.errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(teacherLeaveHistoryStateProvider(widget.teacherId).notifier)
                              .fetchHistory(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (state.records.isEmpty)
                  const Center(
                    child: Text(
                      'No attendance records found for the selected period.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  RefreshIndicator(
                    onRefresh: () => ref
                        .read(teacherLeaveHistoryStateProvider(widget.teacherId).notifier)
                        .fetchHistory(),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.all(spacing.md),
                      itemCount: state.records.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => SizedBox(height: spacing.md),
                      itemBuilder: (context, index) {
                        if (index == state.records.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final item = state.records[index];
                        return _buildHistoryCard(context, item);
                      },
                    ),
                  ),
                if (state.isLoadingMore)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Loading more logs...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, LeaveRequest item) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color color;
    switch (item.status.toUpperCase()) {
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

    final days = _calculateDays(item.startDate, item.endDate);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () => context.push('/teacher-leaves/${item.id}'),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.leaveType,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(radius.sm),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(
                '${_formatDate(item.startDate)} - ${_formatDate(item.endDate)} ($days days)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(item.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.reviewerRemarks != null && item.reviewerRemarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Remarks: ${item.reviewerRemarks!}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
