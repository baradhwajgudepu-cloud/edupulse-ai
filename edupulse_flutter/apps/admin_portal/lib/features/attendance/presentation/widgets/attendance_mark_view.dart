import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/portal_permissions.dart';
import '../providers/attendance_providers.dart';
import '../../data/models/attendance_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/utils/dropdown_safety.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AttendanceMarkView extends ConsumerStatefulWidget {
  const AttendanceMarkView({super.key});

  @override
  ConsumerState<AttendanceMarkView> createState() => _AttendanceMarkViewState();
}

class _AttendanceMarkViewState extends ConsumerState<AttendanceMarkView> {
  // Pre-cached, immutable status-specific reason items for O(1) roster rendering performance
  static final Map<String, List<DropdownMenuItem<String>>> _cachedStatusReasonItems = {
    for (final entry in DropdownSafety.statusAllowedReasons.entries)
      entry.key: entry.value.map((code) => DropdownMenuItem<String>(
        value: code,
        child: Text(DropdownSafety.getReasonLabel(code), style: const TextStyle(fontSize: 11)),
      )).toList(),
  };

  static List<DropdownMenuItem<String>> _getReasonItems(String status, String? currentReason) {
    final baseList = _cachedStatusReasonItems[status] ?? _cachedStatusReasonItems['ABSENT']!;
    final normalized = DropdownSafety.normalizeAttendanceReason(currentReason);
    if (!baseList.any((item) => item.value == normalized)) {
      return [
        ...baseList,
        DropdownMenuItem<String>(
          value: normalized,
          child: Text(DropdownSafety.getReasonLabel(normalized), style: const TextStyle(fontSize: 11)),
        ),
      ];
    }
    return baseList;
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final permissions = ref.watch(portalPermissionsProvider);
    final isTeacher = permissions.isTeacher;

    final markState = ref.watch(dailyAttendanceMarkProvider);
    final markNotifier = ref.read(dailyAttendanceMarkProvider.notifier);

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));

    // Auto-select active academic year if not yet selected
    final selectedAyId = ref.watch(selectedAcademicYearIdProvider);
    if (markState.academicYearId == null) {
      if (selectedAyId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          markNotifier.setSelection(academicYearId: selectedAyId);
        });
      } else if (ayState.years.isNotEmpty) {
        final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          markNotifier.setSelection(academicYearId: current.id);
        });
      }
    }

    // Teacher assignment scoping
    final teacherAssignmentsAsync = isTeacher ? ref.watch(teacherAttendanceAssignmentsProvider(schoolId)) : null;
    final teacherAssignments = teacherAssignmentsAsync?.value ?? [];

    // Filter classes by selected academic year and teacher assignment
    final availableClasses = classesState.classes.where((c) {
      if (markState.academicYearId != null && c.academicYearId != markState.academicYearId) {
        return false;
      }
      if (isTeacher) {
        final assignedClassIds = teacherAssignments.map((a) => a.classId).toSet();
        return assignedClassIds.contains(c.id);
      }
      return true;
    }).toList();

    // Filter sections for currently selected class and teacher assignment
    final availableSections = sectionsState.sections.where((s) {
      if (markState.classId != null && s.classId != markState.classId) {
        return false;
      }
      if (isTeacher) {
        final assignedSectionIds = teacherAssignments
            .where((a) => a.classId == markState.classId)
            .map((a) => a.sectionId)
            .toSet();
        return assignedSectionIds.contains(s.id);
      }
      return true;
    }).toList();

    // Empty state for teacher with no assigned classes
    if (isTeacher && (teacherAssignmentsAsync?.hasValue ?? false) && availableClasses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No classes are currently assigned to you for attendance marking.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your school administrator or timetable coordinator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Roster summary counts
    int countPresent = 0;
    int countAbsent = 0;
    int countLate = 0;
    int countOther = 0;
    int selectedCount = 0;

    for (final s in markState.roster) {
      if (s.isSelected) selectedCount++;
      switch (s.status) {
        case 'PRESENT':
          countPresent++;
          break;
        case 'ABSENT':
          countAbsent++;
          break;
        case 'LATE':
          countLate++;
          break;
        default:
          countOther++;
          break;
      }
    }

    final allSelected = markState.roster.isNotEmpty && selectedCount == markState.roster.length;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Class, Date & Session',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Academic Year
                      SizedBox(
                        width: 180,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: markState.academicYearId,
                          decoration: const InputDecoration(
                            labelText: 'Academic Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: ayState.years.map((y) {
                            return DropdownMenuItem<String>(
                              value: y.id,
                              child: Text(y.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            markNotifier.setSelection(academicYearId: val, classId: null, sectionId: null);
                          },
                        ),
                      ),

                      // Class
                      SizedBox(
                        width: 170,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: markState.classId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: availableClasses.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            markNotifier.setSelection(classId: val, sectionId: null);
                          },
                        ),
                      ),

                      // Section
                      SizedBox(
                        width: 160,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: markState.sectionId,
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: availableSections.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(s.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            markNotifier.setSelection(sectionId: val);
                          },
                        ),
                      ),

                      // Date Picker
                      SizedBox(
                        width: 180,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(markState.attendanceDate)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: markState.attendanceDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              markNotifier.setSelection(attendanceDate: picked);
                            }
                          },
                        ),
                      ),

                      // Session Type
                      SizedBox(
                        width: 160,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: markState.sessionType,
                          decoration: const InputDecoration(
                            labelText: 'Session',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'FULL_DAY', child: Text('Full Day')),
                            DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                            DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              markNotifier.setSelection(sessionType: val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Messages
          if (markState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      markState.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (markState.successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      markState.successMessage!,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Locked Session Banner
          if (markState.isLocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'This attendance session is LOCKED. Records are archived and cannot be edited directly.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Action Bar & Roster KPIs
          if (markState.roster.isNotEmpty) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Summary counts
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _chip('Total: ${markState.roster.length}', Colors.grey[700]!, isDark ? Colors.grey[850]! : Colors.grey[200]!),
                        const SizedBox(width: 8),
                        _chip('Present: $countPresent', Colors.green[800]!, Colors.green.withValues(alpha: 0.15)),
                        const SizedBox(width: 8),
                        _chip('Absent: $countAbsent', Colors.red[800]!, Colors.red.withValues(alpha: 0.15)),
                        const SizedBox(width: 8),
                        _chip('Late: $countLate', Colors.orange[800]!, Colors.orange.withValues(alpha: 0.15)),
                        const SizedBox(width: 8),
                        _chip('Leave: $countOther', Colors.purple[800]!, Colors.purple.withValues(alpha: 0.15)),
                      ],
                    ),

                    // Quick Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('Mark All Present'),
                          onPressed: markState.isLocked ? null : () => markNotifier.markAllPresent(),
                        ),
                        const SizedBox(width: 8),
                        if (selectedCount > 0) ...[
                          PopupMenuButton<String>(
                            tooltip: 'Set status for $selectedCount selected students',
                            child: Chip(
                              avatar: const Icon(Icons.arrow_drop_down, size: 18),
                              label: Text('Mark Selected ($selectedCount)'),
                              backgroundColor: theme.colorScheme.primaryContainer,
                            ),
                            onSelected: (status) => markNotifier.markSelectedStatus(status),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'PRESENT', child: Text('Mark Present')),
                              PopupMenuItem(value: 'ABSENT', child: Text('Mark Absent')),
                              PopupMenuItem(value: 'LATE', child: Text('Mark Late')),
                              PopupMenuItem(value: 'HALF_DAY', child: Text('Mark Half-Day')),
                              PopupMenuItem(value: 'EXCUSED', child: Text('Mark Excused')),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Student Roster Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allSelected,
                          tristate: selectedCount > 0 && !allSelected,
                          onChanged: markState.isLocked
                              ? null
                              : (val) => markNotifier.toggleSelectAll(val ?? false),
                        ),
                        const SizedBox(
                          width: 80,
                          child: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(
                          width: 110,
                          child: Text('Adm No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Expanded(
                          flex: 4,
                          child: Text('Attendance Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text('Reason & Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  // Table Body
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: markState.roster.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = markState.roster[index];
                      return Container(
                        color: student.isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.05)
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: student.isSelected,
                              onChanged: markState.isLocked
                                  ? null
                                  : (_) => markNotifier.toggleSelectStudent(student.studentId),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                student.rollNumber.isNotEmpty ? student.rollNumber : '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                student.admissionNumber,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                student.studentName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            // Status Chips
                            Expanded(
                              flex: 4,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _statusChip(student.studentId, 'PRESENT', 'P', Colors.green, student.status, markNotifier, markState.isLocked),
                                  _statusChip(student.studentId, 'ABSENT', 'A', Colors.red, student.status, markNotifier, markState.isLocked),
                                  _statusChip(student.studentId, 'LATE', 'L', Colors.orange, student.status, markNotifier, markState.isLocked),
                                  _statusChip(student.studentId, 'HALF_DAY', 'HD', Colors.amber[800]!, student.status, markNotifier, markState.isLocked),
                                  _statusChip(student.studentId, 'EXCUSED', 'EX', Colors.purple, student.status, markNotifier, markState.isLocked),
                                ],
                              ),
                            ),
                            // Reason / Remarks Dropdown
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  if (student.status != 'PRESENT') ...[
                                    Expanded(
                                      child: SafeDropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: DropdownSafety.normalizeAttendanceReason(student.reason),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: _getReasonItems(student.status, student.reason),
                                        fallbackValue: DropdownSafety.reasonUnknown,
                                        onChanged: markState.isLocked
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  markNotifier.updateStudentStatus(
                                                    student.studentId,
                                                    student.status,
                                                    reason: val,
                                                  );
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: Icon(
                                      student.remarks.isNotEmpty ? Icons.comment : Icons.add_comment_outlined,
                                      size: 18,
                                      color: student.remarks.isNotEmpty ? theme.colorScheme.primary : Colors.grey,
                                    ),
                                    tooltip: student.remarks.isNotEmpty ? student.remarks : 'Add remarks',
                                    onPressed: markState.isLocked
                                        ? null
                                        : () => _editRemarksDialog(context, student, markNotifier),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button Bar
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: markState.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  markState.isSaving ? 'Submitting...' : 'Save & Submit Attendance',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: markState.isSaving || markState.isLocked
                    ? null
                    : () async {
                        await markNotifier.submitAttendance();
                      },
              ),
            ),
          ] else if (markState.isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.group_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'Please select Class and Section above to load student roster.',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Widget _statusChip(
    String studentId,
    String statusValue,
    String label,
    Color color,
    String currentStatus,
    DailyAttendanceMarkNotifier notifier,
    bool isLocked,
  ) {
    final isSelected = currentStatus == statusValue;
    return InkWell(
      onTap: isLocked ? null : () => notifier.updateStudentStatus(studentId, statusValue),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: isSelected ? 1.5 : 1.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Future<void> _editRemarksDialog(
    BuildContext context,
    StudentRosterItem student,
    DailyAttendanceMarkNotifier notifier,
  ) async {
    final controller = TextEditingController(text: student.remarks);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Remarks for ${student.studentName}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter attendance remarks...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      notifier.updateStudentStatus(
        student.studentId,
        student.status,
        remarks: controller.text.trim(),
      );
    }
    controller.dispose();
  }
}
