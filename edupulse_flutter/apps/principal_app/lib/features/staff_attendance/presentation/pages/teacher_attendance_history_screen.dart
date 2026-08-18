import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/staff_attendance_model.dart';
import '../providers/staff_attendance_provider.dart';

class TeacherAttendanceHistoryScreen extends ConsumerStatefulWidget {
  final String teacherId;

  const TeacherAttendanceHistoryScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherAttendanceHistoryScreen> createState() => _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState extends ConsumerState<TeacherAttendanceHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).fetchHistory(isLoadMore: true);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final state = ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId));
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: state.startDate != null && state.endDate != null
          ? DateTimeRange(start: state.startDate!, end: state.endDate!)
          : null,
    );

    if (picked != null) {
      ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final historyState = ref.watch(teacherAttendanceHistoryStateProvider(widget.teacherId));
    final dailyState = ref.watch(staffAttendanceStateProvider);

    // Look up teacher name
    final teacherName = dailyState.summary?.records
            .firstWhere((r) => r.teacherId == widget.teacherId, orElse: () => StaffDailyAttendanceReportItem(
              teacherId: widget.teacherId,
              teacherName: 'Teacher',
              attendanceStatus: 'ABSENT',
              isMockedLocation: false,
            ))
            .teacherName ??
        'Teacher';

    return Scaffold(
      appBar: AppBar(
        title: Text('$teacherName History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).fetchHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Range Filter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        historyState.startDate != null && historyState.endDate != null
                            ? '${DateFormat('dd MMM').format(historyState.startDate!)} - ${DateFormat('dd MMM yyyy').format(historyState.endDate!)}'
                            : 'All Records',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (historyState.startDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).setDateRange(null, null);
                        },
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: const Text('Filter'),
                      onPressed: () => _selectDateRange(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main list
          Expanded(
            child: Builder(
              builder: (context) {
                if (historyState.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (historyState.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                          SizedBox(height: spacing.md),
                          Text(
                            historyState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton(
                            onPressed: () => ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).fetchHistory(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (historyState.records.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: theme.colorScheme.outline),
                          SizedBox(height: spacing.md),
                          Text(
                            'No attendance records found for the selected period.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.all(spacing.md),
                  itemCount: historyState.records.length + (historyState.hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => SizedBox(height: spacing.md),
                  itemBuilder: (context, index) {
                    if (index == historyState.records.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: spacing.md),
                        child: Center(
                          child: historyState.isLoadingMore
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: () => ref.read(teacherAttendanceHistoryStateProvider(widget.teacherId).notifier).fetchHistory(isLoadMore: true),
                                  child: const Text('Load More'),
                                ),
                        ),
                      );
                    }

                    final record = historyState.records[index];
                    return _buildHistoryCard(context, record);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, StaffAttendanceHistoryItem record) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color statusColor;
    switch (record.status) {
      case 'PRESENT':
        statusColor = Colors.green;
        break;
      case 'ABSENT':
        statusColor = Colors.red;
        break;
      case 'LATE':
        statusColor = Colors.amber.shade700;
        break;
      case 'HALF_DAY':
        statusColor = Colors.orange;
        break;
      case 'ON_LEAVE':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = theme.colorScheme.outline;
    }

    // Format Date
    String formattedDate = record.attendanceDate;
    try {
      final parsed = DateTime.parse(record.attendanceDate);
      formattedDate = DateFormat('dd MMM yyyy (EEEE)').format(parsed);
    } catch (_) {}

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(radius.sm),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (record.isMockedLocation) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Text(
                      'Mock location detected during verification.',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (record.checkInTime != null) ...[
              _buildLogItem(
                context,
                label: 'Check-In',
                time: record.checkInTime!,
                coords: record.checkInLatitude != null && record.checkInLongitude != null
                    ? '${record.checkInLatitude!.toStringAsFixed(5)}, ${record.checkInLongitude!.toStringAsFixed(5)}'
                    : null,
                distance: record.checkInDistanceMeters,
              ),
              if (record.checkOutTime != null) ...[
                const SizedBox(height: 8),
                _buildLogItem(
                  context,
                  label: 'Check-Out',
                  time: record.checkOutTime!,
                  coords: record.checkOutLatitude != null && record.checkOutLongitude != null
                      ? '${record.checkOutLatitude!.toStringAsFixed(5)}, ${record.checkOutLongitude!.toStringAsFixed(5)}'
                      : null,
                  distance: record.checkOutDistanceMeters,
                ),
              ],
              if (record.durationSeconds != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duration',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      _formatDuration(record.durationSeconds!),
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ] else
              Text(
                'No attendance log for this day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
            if (record.remarks != null && record.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: ${record.remarks}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(
    BuildContext context, {
    required String label,
    required String time,
    required String? coords,
    required double? distance,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(time),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (coords != null)
                Text(
                  coords,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                ),
              if (distance != null)
                Text(
                  '${distance.toStringAsFixed(1)} m from school',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(String isoDateTime) {
    try {
      final dt = DateTime.parse(isoDateTime);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return isoDateTime;
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
