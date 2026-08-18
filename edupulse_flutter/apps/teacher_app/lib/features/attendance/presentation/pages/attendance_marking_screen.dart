import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../domain/entities/attendance_enums.dart';
import '../../domain/entities/attendance_session_entity.dart';
import '../providers/attendance_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../my_classes/domain/entities/student.dart';

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final String timetableId;
  final String dateStr;

  const AttendanceMarkingScreen({
    super.key,
    required this.timetableId,
    required this.dateStr,
  });

  @override
  ConsumerState<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  final TextEditingController _searchController = TextEditingController();

  String get _resolvedDate {
    if (widget.dateStr.isNotEmpty) return widget.dateStr;
    return DateTime.now().toIso8601String().split('T')[0];
  }

  String get _providerKey => '${widget.timetableId}:$_resolvedDate';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceStateProvider(_providerKey).notifier).fetchAttendance();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dashboardState = ref.watch(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dashboardData = dashboardState is DashboardSuccess
        ? dashboardState.data
        : (dashboardState as DashboardRefreshing).data;

    final timetable = dashboardData.schedule.firstWhere(
      (entry) => entry.id == widget.timetableId,
      orElse: () => throw Exception('Timetable entry not found'),
    );

    final attendanceState = ref.watch(attendanceStateProvider(_providerKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTimetableHeader(timetable, theme, spacing, radius),
          Expanded(
            child: _buildStateBody(attendanceState, theme, spacing, radius),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableHeader(dynamic timetable, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final parsedDate = DateTime.tryParse(_resolvedDate) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(parsedDate);

    Color accentColor = theme.colorScheme.primary;
    if (timetable.displayColor != null && timetable.displayColor.isNotEmpty) {
      try {
        final hex = timetable.displayColor.replaceAll('#', '');
        accentColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${timetable.className} - ${timetable.sectionName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(radius.sm),
                    ),
                    child: Text(
                      timetable.subjectName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    'Period ${timetable.periodNumber} (${timetable.startTime} - ${timetable.endTime})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBody(AttendanceState state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    if (state is AttendanceLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state is AttendanceError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.md),
            ElevatedButton(
              onPressed: () => ref.read(attendanceStateProvider(_providerKey).notifier).fetchAttendance(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (state is AttendanceSuccess) {
      return _buildMarkingView(state, theme, spacing, radius);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMarkingView(AttendanceSuccess state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final isSubmitted = state.session?.status == AttendanceSessionStatus.SUBMITTED;
    final isLocked = state.session?.status == AttendanceSessionStatus.LOCKED;

    final dashboardState = ref.watch(dashboardStateProvider);
    bool isWeekdayMismatch = false;
    String slotDay = '';
    String selectedDay = '';

    if (dashboardState is DashboardSuccess || dashboardState is DashboardRefreshing) {
      final data = dashboardState is DashboardSuccess 
          ? dashboardState.data 
          : (dashboardState as DashboardRefreshing).data;
      final timetable = data.schedule.firstWhere(
        (entry) => entry.id == widget.timetableId,
        orElse: () => throw Exception('Timetable entry not found'),
      );
      slotDay = timetable.dayOfWeek.toUpperCase();
      final parsedDate = DateTime.tryParse(_resolvedDate);
      if (parsedDate != null) {
        selectedDay = DateFormat('EEEE').format(parsedDate).toUpperCase();
        if (slotDay != selectedDay) {
          isWeekdayMismatch = true;
        }
      }
    }

    return Column(
      children: [
        if (isWeekdayMismatch)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.amber.shade900,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    'Warning: Selected date ($_resolvedDate, $selectedDay) differs from timetable weekday ($slotDay).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isSubmitted || isLocked)
          Container(
            width: double.infinity,
            color: isLocked ? theme.colorScheme.errorContainer.withOpacity(0.3) : theme.colorScheme.secondaryContainer.withOpacity(0.3),
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: isLocked ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    isLocked 
                        ? 'This session is LOCKED. Attendance cannot be modified.'
                        : 'Attendance is SUBMITTED. Modifying records requires a correction reason.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isLocked ? theme.colorScheme.error : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildCounterSummary(state, theme, spacing, radius),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search student...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(attendanceStateProvider(_providerKey).notifier).searchLocal('');
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius.sm),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(attendanceStateProvider(_providerKey).notifier).searchLocal(val);
                  },
                ),
              ),
              if (!isLocked && !isSubmitted) ...[
                SizedBox(width: spacing.sm),
                TextButton.icon(
                  onPressed: () {
                    ref.read(attendanceStateProvider(_providerKey).notifier).markAllPresent();
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('All Present'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: state.filteredStudents.isEmpty
              ? Center(
                  child: Text(
                    state.query.isNotEmpty ? 'No matching students.' : 'No students enrolled.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                  itemCount: state.filteredStudents.length,
                  separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                  itemBuilder: (context, index) {
                    final student = state.filteredStudents[index];
                    final status = state.studentStatuses[student.id] ?? AttendanceStatus.PRESENT;
                    final hasRemarks = state.studentRemarks[student.id]?.isNotEmpty ?? false;

                    return _buildStudentCard(student, status, hasRemarks, isLocked, isSubmitted, theme, spacing, radius);
                  },
                ),
        ),
        if (!isLocked) _buildSubmitBar(state, theme, spacing),
      ],
    );
  }

  Widget _buildCounterSummary(AttendanceSuccess state, ThemeData theme, AppSpacing spacing, AppRadius radius) {
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCounterItem('Total', state.totalCount.toString(), theme.colorScheme.onSurfaceVariant, theme),
          _buildCounterItem('Present', state.presentCount.toString(), Colors.green, theme),
          _buildCounterItem('Absent', state.absentCount.toString(), Colors.red, theme),
          _buildCounterItem('Late', state.lateCount.toString(), Colors.orange, theme),
          if (state.otherCount > 0)
            _buildCounterItem('Other', state.otherCount.toString(), theme.colorScheme.primary, theme),
        ],
      ),
    );
  }

  Widget _buildCounterItem(String label, String count, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          count,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    StudentEntity student,
    AttendanceStatus status,
    bool hasRemarks,
    bool isLocked,
    bool isSubmitted,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    Color cardBorderColor = theme.colorScheme.outlineVariant.withOpacity(0.5);
    Color statusBadgeColor = theme.colorScheme.onSurfaceVariant;
    Color statusBgColor = theme.colorScheme.surfaceVariant.withOpacity(0.3);

    if (status == AttendanceStatus.PRESENT) {
      statusBadgeColor = Colors.green;
      statusBgColor = Colors.green.shade50;
    } else if (status == AttendanceStatus.ABSENT) {
      statusBadgeColor = Colors.red;
      statusBgColor = Colors.red.shade50;
      cardBorderColor = Colors.red.shade200;
    } else if (status == AttendanceStatus.LATE) {
      statusBadgeColor = Colors.orange;
      statusBgColor = Colors.orange.shade50;
    } else {
      statusBadgeColor = theme.colorScheme.primary;
      statusBgColor = theme.colorScheme.primaryContainer.withOpacity(0.2);
    }

    return InkWell(
      onTap: isLocked
          ? null
          : () {
              if (isSubmitted) {
                // Submitted session toggle triggers correction flow
                final newStatus = status == AttendanceStatus.PRESENT
                    ? AttendanceStatus.ABSENT
                    : AttendanceStatus.PRESENT;
                _showCorrectionDialog(student, newStatus);
              } else {
                ref.read(attendanceStateProvider(_providerKey).notifier).toggleStatus(student.id);
              }
            },
      borderRadius: BorderRadius.circular(radius.sm),
      child: Container(
        padding: EdgeInsets.all(spacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius.sm),
          border: Border.all(color: cardBorderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '${student.firstName[0]}${student.lastName[0]}'.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        student.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasRemarks) ...[
                        SizedBox(width: spacing.xs),
                        Icon(Icons.insert_comment_outlined, size: 12, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Roll No: ${student.rollNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(radius.sm),
              ),
              child: Text(
                status.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusBadgeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isLocked) ...[
              SizedBox(width: spacing.xs),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => _showMoreOptionsSheet(student, status, isSubmitted, theme, spacing, radius),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar(AttendanceSuccess state, ThemeData theme, AppSpacing spacing) {
    final isSaving = state.isSaving;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isSaving ? null : () => _showReviewConfirmation(state),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'APPROVE & SUBMIT',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
        ),
      ),
    );
  }

  void _showMoreOptionsSheet(
    StudentEntity student,
    AttendanceStatus currentStatus,
    bool isSubmitted,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final remarksController = TextEditingController(
      text: ref.read(attendanceStateProvider(_providerKey) as ProviderListenable<AttendanceSuccess>).studentRemarks[student.id] ?? '',
    );
    AttendanceStatus selectedStatus = currentStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: spacing.md,
                right: spacing.md,
                top: spacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + spacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    student.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Roll No: ${student.rollNumber} | Admission: ${student.admissionNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    'Select Status',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spacing.sm),
                  Wrap(
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: AttendanceStatus.values.map((status) {
                      final isSelected = selectedStatus == status;
                      return ChoiceChip(
                        label: Text(status.name),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() => selectedStatus = status);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    'Remarks (Optional)',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spacing.xs),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(
                      hintText: 'Enter remarks...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.sm)),
                      contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (isSubmitted) {
                          // Correction flow
                          _showCorrectionDialog(student, selectedStatus, remarks: remarksController.text);
                        } else {
                          // Draft save
                          ref.read(attendanceStateProvider(_providerKey).notifier).setStatus(
                            student.id,
                            selectedStatus,
                            remarks: remarksController.text,
                          );
                        }
                      },
                      child: const Text('Save Details'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCorrectionDialog(StudentEntity student, AttendanceStatus newStatus, {String? remarks}) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Correct Attendance'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changing ${student.fullName}\'s status to ${newStatus.name}.',
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.md),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Correction Reason*',
                    hintText: 'e.g. Marked present by mistake',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Correction reason is required.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final reason = reasonController.text.trim();
                  Navigator.pop(context);
                  ref.read(attendanceStateProvider(_providerKey).notifier).correctStudentAttendance(
                        studentId: student.id,
                        newStatus: newStatus,
                        correctionReason: reason,
                        remarks: remarks,
                      );
                }
              },
              child: const Text('Submit Correction'),
            ),
          ],
        );
      },
    );
  }

  void _showReviewConfirmation(AttendanceSuccess state) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve Attendance?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${state.totalCount} Students'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Present:'),
                  Text(state.presentCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Absent:'),
                  Text(state.absentCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Late:'),
                  Text(state.lateCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Once submitted, changes may require correction depending on permissions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(attendanceStateProvider(_providerKey).notifier).submitAttendance().then((_) {
                  // After successful submission, check state and navigate back
                  final newState = ref.read(attendanceStateProvider(_providerKey));
                  if (newState is! AttendanceError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attendance Submitted successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.pop();
                  }
                });
              },
              child: const Text('Approve & Submit'),
            ),
          ],
        );
      },
    );
  }
}
