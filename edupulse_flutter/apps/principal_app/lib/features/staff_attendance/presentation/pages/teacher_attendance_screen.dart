import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/staff_attendance_provider.dart';
import '../../data/models/staff_attendance_model.dart';
import '../../../dashboard/presentation/providers/active_school_provider.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends ConsumerState<TeacherAttendanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, PRESENT, ABSENT, LATE, LEAVE

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, StaffAttendanceState state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 305)),
    );
    if (picked != null && picked != state.selectedDate) {
      ref.read(staffAttendanceStateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(staffAttendanceStateProvider);
    final activeSchoolId = ref.watch(activeSchoolIdProvider);

    // Filter and search logic
    List<StaffDailyAttendanceReportItem> filteredRecords = [];
    if (state.summary != null) {
      filteredRecords = state.summary!.records.where((record) {
        // Search filter
        final nameMatch = record.teacherName.toLowerCase().contains(_searchQuery.toLowerCase());
        final deptMatch = (record.department ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesSearch = nameMatch || deptMatch;

        // Status filter
        if (_selectedFilter == 'ALL') return matchesSearch;
        if (_selectedFilter == 'PRESENT') {
          return matchesSearch && record.attendanceStatus == 'PRESENT';
        }
        if (_selectedFilter == 'ABSENT') {
          return matchesSearch && record.attendanceStatus == 'ABSENT';
        }
        if (_selectedFilter == 'LATE') {
          return matchesSearch && record.attendanceStatus == 'LATE';
        }
        if (_selectedFilter == 'HALF_DAY') {
          return matchesSearch && record.attendanceStatus == 'HALF_DAY';
        }
        if (_selectedFilter == 'LEAVE') {
          return matchesSearch && record.attendanceStatus == 'ON_LEAVE';
        }
        if (_selectedFilter == 'NOT_MARKED') {
          return matchesSearch && record.attendanceStatus == 'NOT_MARKED';
        }
        return matchesSearch;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () => context.push('/geofence'),
            tooltip: 'Geofence Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(staffAttendanceStateProvider.notifier).fetchAttendance(isRefresh: true),
          ),
        ],
      ),
      body: activeSchoolId == null || activeSchoolId.isEmpty
          ? const Center(child: Text('Please select a school context.'))
          : RefreshIndicator(
              onRefresh: () => ref.read(staffAttendanceStateProvider.notifier).fetchAttendance(isRefresh: true),
              child: ListView(
                padding: EdgeInsets.all(spacing.md),
                children: [
                  // Date selector row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(state.selectedDate),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: const Text('Change'),
                        onPressed: () => _selectDate(context, state),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),

                  // Loading or error state
                  if (state.isLoading)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(radius.md),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (state.errorMessage != null)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: EdgeInsets.all(spacing.md),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    )
                  else if (state.summary != null) ...[
                    // KPI stats grid
                    _buildKpiGrid(context, state.summary!),
                    SizedBox(height: spacing.lg),

                    // Search & filters
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search teachers by name or department...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                      ),
                    ),
                    SizedBox(height: spacing.md),

                    // Filters chip row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${state.summary!.records.length})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('PRESENT', 'Present (${state.summary!.presentCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('ABSENT', 'Absent (${state.summary!.absentCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('LATE', 'Late (${state.summary!.lateCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('HALF_DAY', 'Half Day (${state.summary!.halfDayCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('LEAVE', 'On Leave (${state.summary!.onLeaveCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('NOT_MARKED', 'Not Marked (${state.summary!.notMarkedCount})'),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.md),

                    // Records list
                    if (filteredRecords.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: spacing.xl),
                        child: const Center(
                          child: Text(
                            'No attendance records match your filters.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredRecords.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredRecords[index];
                          return _buildTeacherRow(context, item);
                        },
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String filterType, String label) {
    final isSelected = _selectedFilter == filterType;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filterType);
      },
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, StaffDailyAttendanceSummary summary) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Present',
                  value: summary.presentCount.toString(),
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Late',
                  value: summary.lateCount.toString(),
                  color: Colors.amber,
                ),
              ),
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Half Day',
                  value: summary.halfDayCount.toString(),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          Divider(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Absent',
                  value: summary.absentCount.toString(),
                  color: Colors.red,
                ),
              ),
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'On Leave',
                  value: summary.onLeaveCount.toString(),
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Not Marked',
                  value: summary.notMarkedCount.toString(),
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Divider(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Total Teachers',
                  value: summary.totalTeachers.toString(),
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: _buildKpiItem(
                  context,
                  title: 'Attendance Rate',
                  value: '${summary.attendanceRate}%',
                  color: theme.colorScheme.primary,
                  isKpiRate: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    bool isKpiRate = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        if (isKpiRate) ...[
          const SizedBox(height: 2),
          Text(
            'Frontend-derived KPI',
            style: TextStyle(
              fontSize: 8,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTeacherRow(BuildContext context, StaffDailyAttendanceReportItem item) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    Color statusColor;
    switch (item.attendanceStatus) {
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
      case 'NOT_MARKED':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = theme.colorScheme.outline;
    }

    return InkWell(
      onTap: () {
        context.push('/teacher-attendance/${item.teacherId}');
      },
      borderRadius: BorderRadius.circular(radius.sm),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.teacherName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${item.designation ?? 'Teacher'} | ${item.department ?? 'Staff'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.isMockedLocation) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 10, color: theme.colorScheme.error),
                          const SizedBox(width: 4),
                          Text(
                            'Mock location detected',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (item.checkInTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.login, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(item.checkInTime!),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (item.checkInDistanceMeters != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${item.checkInDistanceMeters!.toStringAsFixed(0)}m)',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                        if (item.checkOutTime != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.logout, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(item.checkOutTime!),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          if (item.checkOutDistanceMeters != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${item.checkOutDistanceMeters!.toStringAsFixed(0)}m)',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                  if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Remarks: ${item.remarks}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
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
                item.attendanceStatus.replaceAll('_', ' '),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
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
}
