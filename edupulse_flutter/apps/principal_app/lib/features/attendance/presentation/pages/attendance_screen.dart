import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String _selectedFilter = 'ALL'; // ALL, PRESENT, ABSENT, LATE, HALFDAY

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceStateProvider.notifier).fetchAttendance();
      // Pre-fetch students to resolve names
      ref.read(studentsStateProvider.notifier).init();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final state = ref.read(attendanceStateProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != state.selectedDate) {
      ref.read(attendanceStateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final state = ref.watch(attendanceStateProvider);
    final studentsState = ref.watch(studentsStateProvider);

    // Create a student name lookup map
    final Map<String, String> studentNames = {};
    if (studentsState is StudentsSuccess) {
      for (final s in studentsState.students) {
        studentNames[s.id] = s.fullName;
      }
    }

    final filteredRecords = state.records.where((r) {
      if (_selectedFilter == 'ALL') return true;
      return r.status == _selectedFilter;
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(attendanceStateProvider.notifier).fetchAttendance(isRefresh: true),
        child: Column(
          children: [
            // Selected Date Banner
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Date: ${DateFormat('dd MMM yyyy').format(state.selectedDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Change'),
                  ),
                ],
              ),
            ),

            if (state.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.errorMessage != null)
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(spacing.lg),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                        SizedBox(height: spacing.sm),
                        const Text('Failed to load attendance logs.'),
                        Text(state.errorMessage!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                        SizedBox(height: spacing.md),
                        ElevatedButton(
                          onPressed: () => ref.read(attendanceStateProvider.notifier).fetchAttendance(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.records.isEmpty)
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey),
                        SizedBox(height: spacing.sm),
                        const Text('No attendance records marked for this date.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // KPI Overview Dashboard Grid
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: spacing.sm,
                        mainAxisSpacing: spacing.sm,
                        childAspectRatio: 1.3,
                        children: [
                          _buildKpiCard(theme, radius, 'Rate', '${state.attendancePercentage.toStringAsFixed(1)}%', theme.colorScheme.primary),
                          _buildKpiCard(theme, radius, 'Present', '${state.presentCount}', Colors.green),
                          _buildKpiCard(theme, radius, 'Absent', '${state.absentCount}', Colors.red),
                          _buildKpiCard(theme, radius, 'Late', '${state.lateCount}', Colors.orange),
                          _buildKpiCard(theme, radius, 'Half Day', '${state.halfDayCount}', Colors.purple),
                          _buildKpiCard(theme, radius, 'Total', '${state.totalCount}', Colors.blueGrey),
                        ],
                      ),
                    ),

                    // Filter Selection Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${state.totalCount})'),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('PRESENT', 'Present (${state.presentCount})', Colors.green),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('ABSENT', 'Absent (${state.absentCount})', Colors.red),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('LATE', 'Late (${state.lateCount})', Colors.orange),
                          SizedBox(width: spacing.xs),
                          _buildFilterChip('HALFDAY', 'Halfday (${state.halfDayCount})', Colors.purple),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.sm),

                    // Student Records List
                    Expanded(
                      child: filteredRecords.isEmpty
                          ? Center(
                              child: Text(
                                'No records matching "$_selectedFilter"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                              itemCount: filteredRecords.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final record = filteredRecords[index];
                                final name = studentNames[record.studentId] ?? 'Student #${record.studentId.substring(0, 6)}';
                                final Color statusColor = record.status == 'PRESENT'
                                    ? Colors.green
                                    : record.status == 'ABSENT'
                                        ? Colors.red
                                        : record.status == 'LATE'
                                            ? Colors.orange
                                            : Colors.purple;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      record.status == 'PRESENT'
                                          ? Icons.check_circle_outline
                                          : record.status == 'ABSENT'
                                              ? Icons.cancel_outlined
                                              : record.status == 'LATE'
                                                  ? Icons.access_time
                                                  : Icons.hourglass_bottom,
                                      color: statusColor,
                                    ),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ID: ${record.studentId}'),
                                  trailing: Container(
                                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(radius.sm),
                                    ),
                                    child: Text(
                                      record.status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(ThemeData theme, AppRadius radius, String title, String value, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterVal, String label, [Color? activeColor]) {
    final isSelected = _selectedFilter == filterVal;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filterVal;
          });
        }
      },
      selectedColor: activeColor?.withValues(alpha: 0.2) ?? Colors.blueGrey.shade100,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? (activeColor ?? Colors.black87) : Colors.black54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
