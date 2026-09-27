import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/portal_permissions.dart';
import '../providers/attendance_providers.dart';
import '../../data/models/attendance_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';
import 'attendance_correction_dialog.dart';

class AttendanceRegisterView extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToMarkTab;
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onFiltersCleared;

  const AttendanceRegisterView({
    super.key,
    this.onNavigateToMarkTab,
    this.onBackToDashboard,
    this.onFiltersCleared,
  });

  @override
  ConsumerState<AttendanceRegisterView> createState() => _AttendanceRegisterViewState();
}

class _AttendanceRegisterViewState extends ConsumerState<AttendanceRegisterView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceRegisterProvider.notifier).fetchRegister();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF2563EB), // Blue
      Color(0xFF0D9488), // Teal
      Color(0xFF7C3AED), // Purple
      Color(0xFFD97706), // Amber
      Color(0xFFE11D48), // Rose
      Color(0xFF0284C7), // Sky
      Color(0xFF4F46E5), // Indigo
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _formatStatus(String s) {
    switch (s.toUpperCase()) {
      case 'PRESENT':
        return 'Present';
      case 'ABSENT':
        return 'Absent';
      case 'LATE':
        return 'Late';
      case 'HALF_DAY':
        return 'Half Day';
      case 'EXCUSED':
        return 'Excused';
      case 'MEDICAL_LEAVE':
        return 'Medical Leave';
      default:
        return s;
    }
  }

  String _formatDateChip(DateTime start, DateTime? end) {
    if (end == null || (start.year == end.year && start.month == end.month && start.day == end.day)) {
      return DateFormat('dd MMM yyyy').format(start);
    }
    return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
  }

  void _showRecordDetails(AttendanceLogDto item, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment_ind_outlined, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Attendance Record Details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildDetailRow('Student Name', item.studentName ?? '-', isBold: true),
                  _buildDetailRow('Admission No', item.admissionNumber ?? '-'),
                  if (item.studentRollNumber != null && item.studentRollNumber!.isNotEmpty)
                    _buildDetailRow('Roll Number', item.studentRollNumber!),
                  _buildDetailRow('Class & Section', '${item.className ?? ""} ${item.sectionName ?? ""}'.trim()),
                  _buildDetailRow('Date', item.attendanceDate),
                  _buildDetailRow('Session Type', item.sessionType.replaceAll('_', ' ')),
                  _buildDetailRow('Status', item.attendanceStatus, isStatus: true, isDark: isDark),
                  _buildDetailRow('Attendance Source', item.attendanceSource),
                  _buildDetailRow('Reason', item.attendanceReason != 'UNKNOWN' ? item.attendanceReason.replaceAll('_', ' ') : 'None specified'),
                  if (item.remarks != null && item.remarks!.isNotEmpty)
                    _buildDetailRow('Remarks', item.remarks!),
                  if (item.markedByName != null && item.markedByName!.isNotEmpty)
                    _buildDetailRow('Marked By', item.markedByName!),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Attendance'),
              onPressed: () {
                Navigator.of(context).pop();
                _editRecord(item);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editRecord(AttendanceLogDto item) async {
    final permissions = ref.read(portalPermissionsProvider);
    if (!permissions.canAccessAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not authorized to edit attendance.')),
      );
      return;
    }

    final sessionId = item.attendanceSessionId.isNotEmpty ? item.attendanceSessionId : item.id;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AttendanceCorrectionDialog(
        sessionId: sessionId,
        studentId: item.studentId,
        studentName: item.studentName ?? 'Student',
        currentStatus: item.attendanceStatus,
        initialRemarks: item.remarks,
      ),
    );

    if (updated == true && mounted) {
      ref.read(attendanceRegisterProvider.notifier).fetchRegister();
      ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
      ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance record corrected for ${item.studentName ?? "Student"}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isStatus = false, bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: isStatus
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(value, isDark),
                  )
                : Text(
                    value.isEmpty ? '-' : value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final registerState = ref.watch(attendanceRegisterProvider);
    final registerNotifier = ref.read(attendanceRegisterProvider.notifier);

    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final availableSections = sectionsState.sections.where((s) {
      if (registerState.classId != null) {
        return s.classId == registerState.classId;
      }
      return true;
    }).toList();

    final cardBgColor = isDark ? const Color(0xFF1E2430) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);

    final classMap = {for (final c in classesState.classes) c.id: c.name};
    final sectionMap = {for (final s in sectionsState.sections) s.id: s.name};

    final hasActiveFilters = registerState.status != null ||
        registerState.startDate != null ||
        registerState.classId != null ||
        registerState.sectionId != null ||
        registerState.search.trim().isNotEmpty;

    String emptyTitle = 'No attendance records found';
    String emptySubtitle = 'Try changing or clearing your filters to view more records.';
    if (hasActiveFilters) {
      final statusLabel = registerState.status != null ? _formatStatus(registerState.status!).toLowerCase() : 'attendance';
      String dateStr = '';
      if (registerState.startDate != null) {
        if (registerState.endDate != null &&
            registerState.startDate!.year == registerState.endDate!.year &&
            registerState.startDate!.month == registerState.endDate!.month &&
            registerState.startDate!.day == registerState.endDate!.day) {
          dateStr = ' for ${DateFormat('dd MMM yyyy').format(registerState.startDate!)}';
        } else if (registerState.endDate != null) {
          dateStr = ' for ${DateFormat('dd MMM yyyy').format(registerState.startDate!)} - ${DateFormat('dd MMM yyyy').format(registerState.endDate!)}';
        } else {
          dateStr = ' for ${DateFormat('dd MMM yyyy').format(registerState.startDate!)}';
        }
      }
      emptyTitle = 'No $statusLabel records$dateStr.';
      emptySubtitle = 'Try changing the filters or clear all filters.';
    }

    // Calculate Summary Statistics dynamically from currently loaded records
    final records = registerState.records;
    final loadedCount = records.length;
    final presentCount = records.where((r) => r.attendanceStatus.toUpperCase() == 'PRESENT').length;
    final absentCount = records.where((r) => r.attendanceStatus.toUpperCase() == 'ABSENT').length;
    final lateCount = records.where((r) => ['LATE', 'HALF_DAY'].contains(r.attendanceStatus.toUpperCase())).length;
    final leaveCount = records.where((r) => ['EXCUSED', 'MEDICAL_LEAVE', 'ON_LEAVE', 'LEAVE'].contains(r.attendanceStatus.toUpperCase())).length;

    String calcPercent(int count) {
      if (loadedCount == 0) return '';
      return '(${((count / loadedCount) * 100).toStringAsFixed(0)}%)';
    }

    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PAGE HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (widget.onBackToDashboard != null) ...[
                    IconButton(
                      key: const Key('register_back_to_dashboard_btn'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to Dashboard',
                      onPressed: widget.onBackToDashboard,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Register',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View, search and manage student attendance records',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.onBackToDashboard != null) ...[
                    OutlinedButton.icon(
                      key: const Key('register_back_to_dashboard_outline_btn'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Dashboard'),
                      onPressed: widget.onBackToDashboard,
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'Refresh Records',
                    icon: const Icon(Icons.refresh),
                    onPressed: registerState.isLoading
                        ? null
                        : () => registerNotifier.fetchRegister(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. ATTENDANCE SUMMARY CARDS
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1080
                  ? (constraints.maxWidth - (4 * 12)) / 5
                  : constraints.maxWidth >= 640
                      ? (constraints.maxWidth - (2 * 12)) / 3
                      : constraints.maxWidth;

              final cards = [
                _buildSummaryCard(
                  title: 'Total Records',
                  value: registerState.total.toString(),
                  subtitle: '${records.length} loaded',
                  icon: Icons.groups_outlined,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  width: cardWidth,
                ),
                _buildSummaryCard(
                  title: 'Present',
                  value: presentCount.toString(),
                  subtitle: calcPercent(presentCount),
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF16A34A),
                  isDark: isDark,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  width: cardWidth,
                ),
                _buildSummaryCard(
                  title: 'Absent',
                  value: absentCount.toString(),
                  subtitle: calcPercent(absentCount),
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  width: cardWidth,
                ),
                _buildSummaryCard(
                  title: 'Late / Half Day',
                  value: lateCount.toString(),
                  subtitle: calcPercent(lateCount),
                  icon: Icons.access_time_rounded,
                  color: const Color(0xFFEA580C),
                  isDark: isDark,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  width: cardWidth,
                ),
                _buildSummaryCard(
                  title: 'On Leave',
                  value: leaveCount.toString(),
                  subtitle: calcPercent(leaveCount),
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  width: cardWidth,
                ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. FILTER AREA
          Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Attendance Register Filters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Export CSV'),
                          onPressed: registerState.records.isEmpty
                              ? null
                              : () => registerNotifier.exportCsv(),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Clear Filters'),
                          onPressed: () {
                            _searchController.clear();
                            registerNotifier.setSearch('');
                            registerNotifier.setFilters();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search field
                    SizedBox(
                      width: 270,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by student name, admission no, or roll no...',
                          hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    registerNotifier.setSearch('');
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (val) => registerNotifier.setSearch(val.trim()),
                      ),
                    ),

                    // Class Filter
                    SizedBox(
                      width: 170,
                      child: SafeDropdownButtonFormField<String>(
                        isExpanded: true,
                        value: registerState.classId,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                          ...classesState.classes.map((c) {
                            return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                          }),
                        ],
                        onChanged: (val) {
                          registerNotifier.setFilters(
                            classId: val,
                            sectionId: null,
                            startDate: registerState.startDate,
                            endDate: registerState.endDate,
                            status: registerState.status,
                          );
                        },
                      ),
                    ),

                    // Section Filter
                    SizedBox(
                      width: 160,
                      child: SafeDropdownButtonFormField<String>(
                        isExpanded: true,
                        value: registerState.sectionId,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                          ...availableSections.map((s) {
                            return DropdownMenuItem<String>(value: s.id, child: Text(s.name));
                          }),
                        ],
                        onChanged: (val) {
                          registerNotifier.setFilters(
                            classId: registerState.classId,
                            sectionId: val,
                            startDate: registerState.startDate,
                            endDate: registerState.endDate,
                            status: registerState.status,
                          );
                        },
                      ),
                    ),

                    // Status Filter
                    SizedBox(
                      width: 160,
                      child: SafeDropdownButtonFormField<String>(
                        isExpanded: true,
                        value: registerState.status,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem<String>(value: null, child: Text('All Statuses')),
                          DropdownMenuItem<String>(value: 'PRESENT', child: Text('Present')),
                          DropdownMenuItem<String>(value: 'ABSENT', child: Text('Absent')),
                          DropdownMenuItem<String>(value: 'LATE', child: Text('Late')),
                          DropdownMenuItem<String>(value: 'HALF_DAY', child: Text('Half Day')),
                          DropdownMenuItem<String>(value: 'EXCUSED', child: Text('Excused')),
                          DropdownMenuItem<String>(value: 'MEDICAL_LEAVE', child: Text('Medical Leave')),
                        ],
                        onChanged: (val) {
                          registerNotifier.setFilters(
                            classId: registerState.classId,
                            sectionId: registerState.sectionId,
                            startDate: registerState.startDate,
                            endDate: registerState.endDate,
                            status: val,
                          );
                        },
                      ),
                    ),

                    // Date Range
                    SizedBox(
                      width: 210,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: borderColor),
                        ),
                        icon: const Icon(Icons.calendar_month_outlined, size: 16),
                        label: Text(
                          registerState.startDate != null && registerState.endDate != null
                              ? '${DateFormat('MM/dd').format(registerState.startDate!)} - ${DateFormat('MM/dd').format(registerState.endDate!)}'
                              : 'Select Date Range',
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: registerState.startDate != null && registerState.endDate != null
                                ? DateTimeRange(start: registerState.startDate!, end: registerState.endDate!)
                                : null,
                          );
                          if (range != null) {
                            registerNotifier.setFilters(
                              classId: registerState.classId,
                              sectionId: registerState.sectionId,
                              startDate: range.start,
                              endDate: range.end,
                              status: registerState.status,
                            );
                          }
                        },
                      ),
                    ),

                    // Bulk Attendance Correction
                    FilledButton.icon(
                      key: const Key('bulk_attendance_correction_btn'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                      label: const Text('Bulk Attendance Correction', style: TextStyle(fontSize: 12.5)),
                      onPressed: () {
                        final permissions = ref.read(portalPermissionsProvider);
                        if (!permissions.canAccessAttendance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You are not authorized to edit attendance.')),
                          );
                          return;
                        }
                        if (registerState.classId == null || registerState.sectionId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a Class and Section above to perform bulk correction.'),
                            ),
                          );
                          return;
                        }
                        ref.read(dailyAttendanceMarkProvider.notifier).setSelection(
                          classId: registerState.classId,
                          sectionId: registerState.sectionId,
                          attendanceDate: registerState.startDate ?? DateTime.now(),
                        );
                        if (widget.onNavigateToMarkTab != null) {
                          widget.onNavigateToMarkTab!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Switch to "Mark Attendance" tab to complete bulk edits.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error banner
          if (registerState.error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      registerState.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => registerNotifier.fetchRegister(),
                    child: const Text('Retry', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ACTIVE FILTERS BANNER
          if (hasActiveFilters) ...[
            Container(
              key: const Key('active_filters_banner'),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Active Filters:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (registerState.status != null)
                          InputChip(
                            key: const Key('filter_chip_status'),
                            avatar: const Icon(Icons.check_circle_outline, size: 14),
                            label: Text(
                              'Status: ${_formatStatus(registerState.status!)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              registerNotifier.setFilters(
                                classId: registerState.classId,
                                sectionId: registerState.sectionId,
                                startDate: registerState.startDate,
                                endDate: registerState.endDate,
                                status: null,
                              );
                            },
                          ),
                        if (registerState.startDate != null)
                          InputChip(
                            key: const Key('filter_chip_date'),
                            avatar: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              _formatDateChip(registerState.startDate!, registerState.endDate),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              registerNotifier.setFilters(
                                classId: registerState.classId,
                                sectionId: registerState.sectionId,
                                startDate: null,
                                endDate: null,
                                status: registerState.status,
                              );
                            },
                          ),
                        if (registerState.classId != null)
                          InputChip(
                            key: const Key('filter_chip_class'),
                            avatar: const Icon(Icons.school, size: 14),
                            label: Text(
                              'Class: ${classMap[registerState.classId] ?? registerState.classId}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              registerNotifier.setFilters(
                                classId: null,
                                sectionId: null,
                                startDate: registerState.startDate,
                                endDate: registerState.endDate,
                                status: registerState.status,
                              );
                            },
                          ),
                        if (registerState.sectionId != null)
                          InputChip(
                            key: const Key('filter_chip_section'),
                            avatar: const Icon(Icons.class_outlined, size: 14),
                            label: Text(
                              'Section: ${sectionMap[registerState.sectionId] ?? registerState.sectionId}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              registerNotifier.setFilters(
                                classId: registerState.classId,
                                sectionId: null,
                                startDate: registerState.startDate,
                                endDate: registerState.endDate,
                                status: registerState.status,
                              );
                            },
                          ),
                        if (registerState.search.isNotEmpty)
                          InputChip(
                            key: const Key('filter_chip_search'),
                            avatar: const Icon(Icons.search, size: 14),
                            label: Text(
                              'Search: "${registerState.search}"',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              _searchController.clear();
                              registerNotifier.setSearch('');
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const Key('banner_clear_all_btn'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      _searchController.clear();
                      registerNotifier.setSearch('');
                      registerNotifier.setFilters();
                      if (widget.onFiltersCleared != null) {
                        widget.onFiltersCleared!();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],

          // 4. DATA TABLE CARD
          Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top control bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${registerState.records.isEmpty ? 0 : registerState.skip + 1} to '
                        '${registerState.skip + registerState.records.length} of ${registerState.total} records',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                      if (registerState.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Table content
                if (registerState.isLoading && registerState.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text('Loading attendance records...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else if (registerState.records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasActiveFilters ? Icons.filter_list_off : Icons.search_off_rounded,
                              size: 30,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            emptySubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                          if (hasActiveFilters) ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              key: const Key('empty_state_clear_filters_btn'),
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Clear Filters'),
                              onPressed: () {
                                _searchController.clear();
                                registerNotifier.setSearch('');
                                registerNotifier.setFilters();
                                if (widget.onFiltersCleared != null) {
                                  widget.onFiltersCleared!();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 960),
                      child: DataTable(
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        headingRowHeight: 44,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 64,
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? const Color(0xFF151923) : const Color(0xFFF8FAFC),
                        ),
                        dividerThickness: 1,
                        columns: const [
                          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Adm No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Class & Sec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Reason & Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: List.generate(registerState.records.length, (index) {
                          final item = registerState.records[index];
                          final rowNumber = registerState.skip + index + 1;
                          final studentName = item.studentName ?? '-';
                          final avatarColor = _getAvatarColor(studentName);
                          final initials = _getInitials(studentName);

                          final classSecText = '${item.className ?? ""} ${item.sectionName ?? ""}'.trim();

                          return DataRow(
                            cells: [
                              // 1. #
                              DataCell(
                                Text(
                                  '$rowNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ),

                              // 2. Date
                              DataCell(
                                Text(
                                  item.attendanceDate,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ),

                              // 3. Adm No
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.admissionNumber ?? '-',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                      color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ),

                              // 4. Student Name (with Avatar & Roll Number)
                              DataCell(
                                SizedBox(
                                  width: 190,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: avatarColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: avatarColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              studentName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (item.studentRollNumber != null && item.studentRollNumber!.isNotEmpty)
                                              Text(
                                                'Roll: ${item.studentRollNumber}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 5. Class & Sec
                              DataCell(
                                Text(
                                  classSecText.isEmpty ? '-' : classSecText,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),

                              // 6. Session
                              DataCell(
                                _buildSessionBadge(item.sessionType, isDark),
                              ),

                              // 7. Status
                              DataCell(
                                _buildStatusBadge(item.attendanceStatus, isDark),
                              ),

                              // 8. Reason & Remarks
                              DataCell(
                                SizedBox(
                                  width: 170,
                                  child: Text(
                                    [
                                      if (item.attendanceReason != 'UNKNOWN') item.attendanceReason.replaceAll('_', ' '),
                                      if (item.remarks != null && item.remarks!.isNotEmpty) item.remarks!,
                                    ].join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),

                              // 9. Actions
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: Key('edit_attendance_${item.id}'),
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit Attendance',
                                      onPressed: () => _editRecord(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                                      tooltip: 'View Record Details',
                                      onPressed: () => _showRecordDetails(item, isDark),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),

                // Pagination Footer
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF171D27) : const Color(0xFFFAFAFA),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${(registerState.skip / registerState.limit).floor() + 1} of '
                        '${registerState.total == 0 ? 1 : ((registerState.total - 1) / registerState.limit).floor() + 1}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: borderColor),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('Previous', style: TextStyle(fontSize: 12)),
                            onPressed: registerState.skip == 0 || registerState.isLoading
                                ? null
                                : () {
                                    final newSkip = (registerState.skip - registerState.limit).clamp(0, registerState.total);
                                    registerNotifier.fetchRegister(skip: newSkip);
                                  },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: borderColor),
                            ),
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('Next', style: TextStyle(fontSize: 12)),
                            onPressed: registerState.skip + registerState.records.length >= registerState.total || registerState.isLoading
                                ? null
                                : () {
                                    final newSkip = registerState.skip + registerState.limit;
                                    registerNotifier.fetchRegister(skip: newSkip);
                                  },
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBgColor,
    required Color borderColor,
    required double width,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBadge(String sessionType, bool isDark) {
    final upper = sessionType.toUpperCase();
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (upper) {
      case 'MORNING':
        bg = Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.amber[300]! : const Color(0xFFB45309);
        icon = Icons.wb_sunny_outlined;
        label = 'MORNING';
        break;
      case 'AFTERNOON':
        bg = Colors.blue.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.blue[300]! : const Color(0xFF1D4ED8);
        icon = Icons.wb_twilight_outlined;
        label = 'AFTERNOON';
        break;
      case 'FULL_DAY':
      case 'FULL DAY':
      default:
        bg = Colors.teal.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.teal[300]! : const Color(0xFF0F766E);
        icon = Icons.calendar_today_outlined;
        label = upper.replaceAll('_', ' ');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    Color dotColor;

    switch (status.toUpperCase()) {
      case 'PRESENT':
        bg = Colors.green.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.green[300]! : const Color(0xFF15803D);
        dotColor = const Color(0xFF16A34A);
        break;
      case 'ABSENT':
        bg = Colors.red.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.red[300]! : const Color(0xFFB91C1C);
        dotColor = const Color(0xFFDC2626);
        break;
      case 'LATE':
        bg = Colors.orange.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.orange[300]! : const Color(0xFFC2410C);
        dotColor = const Color(0xFFEA580C);
        break;
      case 'HALF_DAY':
        bg = Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15);
        fg = isDark ? Colors.amber[300]! : const Color(0xFFB45309);
        dotColor = const Color(0xFFD97706);
        break;
      case 'EXCUSED':
      case 'MEDICAL_LEAVE':
      case 'ON_LEAVE':
      case 'LEAVE':
        bg = Colors.purple.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.purple[300]! : const Color(0xFF7E22CE);
        dotColor = const Color(0xFF9333EA);
        break;
      default:
        bg = Colors.grey.withValues(alpha: isDark ? 0.2 : 0.12);
        fg = isDark ? Colors.grey[400]! : const Color(0xFF475569);
        dotColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
