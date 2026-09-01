import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/attendance_models.dart';
import '../providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/core/routing/routes.dart';

class AttendanceSessionTable extends ConsumerWidget {
  final List<AttendanceSessionDto> sessions;

  const AttendanceSessionTable({super.key, required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));
    final subjectsState = ref.watch(subjectsProvider(schoolId));

    String getClassName(String classId) {
      final c = classState.classes.firstWhere(
        (x) => x.id == classId,
        orElse: () => ClassDto(
          id: '',
          tenantId: '',
          schoolId: '',
          academicYearId: '',
          name: 'N/A',
          code: '',
          level: 1,
          category: 'GENERAL',
          capacity: 0,
          status: 'ACTIVE',
          isActive: true,
          version: 1,
        ),
      );
      return c.name;
    }

    String getSectionName(String sectionId) {
      final s = sectionState.sections.firstWhere(
        (x) => x.id == sectionId,
        orElse: () => SectionDto(id: '', tenantId: '', schoolId: '', academicYearId: '', classId: '', name: 'N/A', code: '', capacity: 0, sortOrder: 0, status: '', isActive: true, version: 1),
      );
      return s.name;
    }

    String getSubjectName(String? subjectId) {
      if (subjectId == null) return 'N/A';
      final s = subjectsState.subjects.firstWhere(
        (x) => x.id == subjectId,
        orElse: () => SubjectDto(id: '', tenantId: '', schoolId: '', academicYearId: '', subjectCode: '', subjectName: 'N/A', category: '', subjectType: '', theoryMarks: 0, practicalMarks: 0, passMarks: 0, status: '', isActive: true, version: 1),
      );
      return s.subjectName;
    }

    void handleLock(AttendanceSessionDto session) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lock Attendance Session?'),
          content: const Text('This will prevent further teacher modifications to this attendance session.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_lock_dialog_btn'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lock Session'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await ref
            .read(attendanceOperationsProvider.notifier)
            .lockSession(sessionId: session.id);
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session locked successfully.')),
          );
        }
      }
    }

    void handleDelete(AttendanceSessionDto session) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Attendance Session?'),
          content: const Text('This will delete the attendance session and all student logs. This action cannot be undone.'),
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await ref
            .read(attendanceOperationsProvider.notifier)
            .deleteSession(sessionId: session.id);
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session deleted successfully.')),
          );
        }
      }
    }

    Color getStatusColor(String status) {
      switch (status.toUpperCase()) {
        case 'LOCKED':
          return Colors.grey;
        case 'SUBMITTED':
          return Colors.green;
        case 'DRAFT':
        default:
          return Colors.orange;
      }
    }

    Widget buildSessionCard(AttendanceSessionDto session) {
      final className = getClassName(session.classId);
      final sectionName = getSectionName(session.sectionId);
      final subjectName = getSubjectName(session.subjectId);
      final statusColor = getStatusColor(session.status);

      int present = 0;
      int absent = 0;
      int lateCount = 0;
      for (final log in session.attendances) {
        final s = log.attendanceStatus.toUpperCase();
        if (s == 'PRESENT' || s == 'ONLINE') present++;
        if (s == 'ABSENT') absent++;
        if (s == 'LATE') lateCount++;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    session.attendanceDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      session.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Class: $className - $sectionName'),
              Text('Subject: $subjectName'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('P: $present', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  Text('A: $absent', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  Text('L: $lateCount', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('View'),
                    onPressed: () {
                      context.go('${AppRoutes.attendance}/${session.id}');
                    },
                  ),
                  if (session.status != 'LOCKED') ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('Lock'),
                      onPressed: () => handleLock(session),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 18),
                      onPressed: () => handleDelete(session),
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            itemBuilder: (context, index) => buildSessionCard(sessions[index]),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(isDark ? Colors.grey[850] : Colors.grey[50]),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Class & Section')),
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('Teacher ID')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Present')),
                  DataColumn(label: Text('Absent')),
                  DataColumn(label: Text('Late')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: sessions.map((session) {
                  final className = getClassName(session.classId);
                  final sectionName = getSectionName(session.sectionId);
                  final subjectName = getSubjectName(session.subjectId);
                  final statusColor = getStatusColor(session.status);

                  int present = 0;
                  int absent = 0;
                  int lateCount = 0;
                  for (final log in session.attendances) {
                    final s = log.attendanceStatus.toUpperCase();
                    if (s == 'PRESENT' || s == 'ONLINE') present++;
                    if (s == 'ABSENT') absent++;
                    if (s == 'LATE') lateCount++;
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(session.attendanceDate)),
                      DataCell(Text('$className - $sectionName')),
                      DataCell(Text(subjectName)),
                      DataCell(Text(session.teacherId ?? 'N/A')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text(present.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text(absent.toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      DataCell(Text(lateCount.toString(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              key: Key('view_session_${session.id}'),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                              tooltip: 'View Details',
                              onPressed: () {
                                context.go('${AppRoutes.attendance}/${session.id}');
                              },
                            ),
                            if (session.status != 'LOCKED') ...[
                              IconButton(
                                key: Key('lock_session_${session.id}'),
                                icon: const Icon(Icons.lock_outline, size: 20),
                                tooltip: 'Lock Session',
                                onPressed: () => handleLock(session),
                              ),
                              IconButton(
                                key: Key('delete_session_${session.id}'),
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                                tooltip: 'Delete Session',
                                onPressed: () => handleDelete(session),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
