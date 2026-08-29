import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/attendance_providers.dart';
import '../widgets/attendance_log_table.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/core/routing/routes.dart';

class AttendanceSessionDetailsScreen extends ConsumerWidget {
  final String sessionId;

  const AttendanceSessionDetailsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(child: Text('No school campus selected.')),
      );
    }

    final detailState = ref.watch(attendanceSessionDetailProvider(sessionId));
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

    void handleLock(String status) async {
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
              key: const Key('confirm_lock_detail_dialog_btn'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lock Session'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await ref
            .read(attendanceOperationsProvider.notifier)
            .lockSession(sessionId: sessionId);
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session locked successfully.')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Session Details'),
        leading: IconButton(
          key: const Key('details_back_btn'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.attendance),
        ),
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load session details: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('retry_load_session_details_btn'),
                onPressed: () => ref.refresh(attendanceSessionDetailProvider(sessionId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (session) {
          final className = getClassName(session.classId);
          final sectionName = getSectionName(session.sectionId);
          final subjectName = getSubjectName(session.subjectId);

          int total = session.attendances.length;
          int present = 0;
          int absent = 0;
          int lateCount = 0;
          int leave = 0;

          for (final log in session.attendances) {
            final s = log.attendanceStatus.toUpperCase();
            if (s == 'PRESENT' || s == 'ONLINE') present++;
            if (s == 'ABSENT') absent++;
            if (s == 'LATE') lateCount++;
            if (s == 'MEDICAL_LEAVE' || s == 'EXCUSED' || s == 'HALF_DAY') leave++;
          }

          final pct = total == 0 ? 0.0 : (present / total) * 100.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Metadata Card
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Session Details',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (session.status == 'LOCKED' ? Colors.grey : (session.status == 'SUBMITTED' ? Colors.green : Colors.orange)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                session.status,
                                style: TextStyle(
                                  color: session.status == 'LOCKED' ? Colors.grey : (session.status == 'SUBMITTED' ? Colors.green : Colors.orange),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text('Date: ${session.attendanceDate}', style: const TextStyle(fontSize: 15))),
                            Expanded(child: Text('Class & Section: $className - $sectionName', style: const TextStyle(fontSize: 15))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: Text('Subject: $subjectName', style: const TextStyle(fontSize: 15))),
                            Expanded(child: Text('Teacher ID: ${session.teacherId ?? "N/A"}', style: const TextStyle(fontSize: 15))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: Text('Marked By: ${session.markedBy ?? "N/A"}', style: const TextStyle(fontSize: 15))),
                            Expanded(
                              child: Text(
                                'Marked At: ${session.markedAt ?? "N/A"}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Aggregated counts bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Total', total.toString(), Colors.grey),
                      _buildSummaryStat('Present', present.toString(), Colors.green),
                      _buildSummaryStat('Absent', absent.toString(), Colors.red),
                      _buildSummaryStat('Late', lateCount.toString(), Colors.orange),
                      _buildSummaryStat('Leave', leave.toString(), Colors.purple),
                      _buildSummaryStat('Rate', '${pct.toStringAsFixed(1)}%', theme.colorScheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Locking operations bar
                if (session.status != 'LOCKED')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Banner(
                      message: 'UNLOCKED',
                      location: BannerLocation.topStart,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primaryContainer),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Admins can correct student logs until locked. Locking closes modifications.',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            ElevatedButton.icon(
                              key: const Key('lock_session_detail_btn'),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Lock Session'),
                              onPressed: () => handleLock(session.status),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                // Student logs list
                Text(
                  'Student Roster',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                AttendanceLogTable(
                  sessionId: session.id,
                  sessionStatus: session.status,
                  logs: session.attendances,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
