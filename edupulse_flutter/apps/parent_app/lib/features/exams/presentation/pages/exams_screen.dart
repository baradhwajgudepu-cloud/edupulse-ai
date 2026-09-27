import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
  try {
    final parsed = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy').format(parsed);
  } catch (_) {
    return dateStr;
  }
}

typedef ParentExamParam = ({String schoolId, String studentId});

final parentExamsProvider = FutureProvider.family<List<Map<String, dynamic>>, ParentExamParam>((ref, param) async {
  final apiClient = ref.read(apiClientProvider);
  
  final timetableResult = await apiClient.get(
    '/marks/parent/student/${param.studentId}/timetable',
    queryParameters: {'school_id': param.schoolId},
    mapper: (json) => json as Map<String, dynamic>,
  );
  
  final marksResult = await apiClient.get(
    '/marks/parent/student/${param.studentId}',
    queryParameters: {'school_id': param.schoolId},
    mapper: (json) => json as Map<String, dynamic>,
  );

  final List timetableSlots = timetableResult.when(
    onSuccess: (data) => (data['data'] as List?) ?? [],
    onFailure: (_) => [],
  );

  final List publishedExams = marksResult.when(
    onSuccess: (data) => (data['data'] as List?) ?? [],
    onFailure: (_) => [],
  );

  final List<Map<String, dynamic>> combined = [];

  for (final slot in timetableSlots) {
    final scheduleMap = slot as Map<String, dynamic>;
    final examId = scheduleMap['examination_id'] as String?;
    final subjectId = scheduleMap['subject_id'] as String?;
    final subjectName = scheduleMap['subject_name'] as String?;

    Map<String, dynamic>? matchingMark;
    for (final exam in publishedExams) {
      if (exam['examination_id'] == examId) {
        final subMarks = (exam['subject_marks'] as List?) ?? [];
        for (final sm in subMarks) {
          if (sm['subject_id'] == subjectId ||
              (subjectName != null && sm['subject_name'] == subjectName)) {
            matchingMark = sm as Map<String, dynamic>;
            break;
          }
        }
      }
      if (matchingMark != null) break;
    }

    combined.add({
      'schedule': scheduleMap,
      'mark': matchingMark,
    });
  }

  // Also include any published exam subject marks not present in upcoming timetable
  for (final exam in publishedExams) {
    final examName = exam['exam_name'] as String? ?? 'Examination';
    final examId = exam['examination_id'] as String?;
    final subMarks = (exam['subject_marks'] as List?) ?? [];
    for (final sm in subMarks) {
      final subjectId = sm['subject_id'] as String?;
      final subjectName = sm['subject_name'] as String?;
      final alreadyAdded = combined.any((c) {
        final s = c['schedule'] as Map<String, dynamic>;
        return s['examination_id'] == examId &&
            (s['subject_id'] == subjectId || s['subject_name'] == subjectName);
      });
      if (!alreadyAdded) {
        combined.add({
          'schedule': {
            'examination_id': examId,
            'exam_name': examName,
            'subject_id': subjectId,
            'subject_name': subjectName,
            'subject_code': sm['subject_code'] as String?,
            'exam_date': sm['exam_date'] ?? 'N/A',
            'start_time': 'Completed',
            'end_time': '',
            'room_number': 'N/A',
            'max_marks': sm['maximum_marks'] ?? 100,
            'pass_marks': sm['pass_marks'] ?? 35,
          },
          'mark': sm,
        });
      }
    }
  }

  return combined;
});

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final authState = ref.watch(authStateProvider);
    final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull : null;

    final dbState = ref.watch(dashboardStateProvider);
    if (dbState is! DashboardSuccess || dbState.data.selectedStudent == null) {
      if (dbState is DashboardLoading || dbState is DashboardInitial) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Exams & Results'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Exams & Results'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 64, color: theme.colorScheme.outline),
              SizedBox(height: spacing.md),
              Text(
                'No student selected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (schoolId == null || schoolId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Exams & Results'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: theme.colorScheme.outline),
              SizedBox(height: spacing.md),
              Text(
                'No school profile associated',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final selected = dbState.data.selectedStudent!;
    final studentName = selected.fullName;
    final examsAsync = ref.watch(parentExamsProvider((schoolId: schoolId, studentId: selected.id)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams & Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: examsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment_outlined, size: 64, color: theme.colorScheme.outline),
                SizedBox(height: spacing.md),
                Text(
                  'Failed to load exam details',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(err.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (exams) {
          if (exams.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assessment_outlined, size: 64, color: theme.colorScheme.outline),
                    SizedBox(height: spacing.md),
                    Text(
                      'No examinations scheduled',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(parentExamsProvider((schoolId: schoolId, studentId: selected.id)).future),
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                // Banner context
                Container(
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.face_rounded, color: theme.colorScheme.onSecondaryContainer),
                      SizedBox(width: spacing.sm),
                      Text(
                        'Student: $studentName',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.md),

                // AI Academic Trajectory Card
                Container(
                  padding: EdgeInsets.all(spacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(radius.sm),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph_rounded, color: Color(0xFF0D9488), size: 24),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Academic Trajectory & Forecast',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trajectory prediction evaluates historical exam cycles to project performance bands and highlight subject strengths.',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.md),

                ...exams.map((item) {
                  final schedule = item['schedule'] as Map<String, dynamic>;
                  final mark = item['mark'] as Map<String, dynamic>?;

                  final dateStrRaw = schedule['exam_date'] as String? ?? 'N/A';
                  final dateStr = formatDate(dateStrRaw);
                  final startTime = schedule['start_time'] as String? ?? 'N/A';
                  final endTime = schedule['end_time'] as String? ?? 'N/A';
                  final room = schedule['room_number'] as String? ?? 'N/A';
                  final maxMarks = schedule['max_marks'] as num? ?? 100;
                  final passMarks = schedule['pass_marks'] as num? ?? 35;

                  final marksObtained = mark?['marks_obtained'] as num?;
                  final remarks = mark?['remarks'] as String? ?? 'N/A';
                  final resultStatus = mark?['result_status'] as String? ?? 'N/A';

                  return Card(
                    margin: EdgeInsets.only(bottom: spacing.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${displaySubjectName(
                                    subjectName: schedule['subject_name'] as String?,
                                    subjectCode: schedule['subject_code'] as String?,
                                    subjectId: schedule['subject_id'] as String?,
                                  )} • $dateStr',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (marksObtained != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                                  decoration: BoxDecoration(
                                    color: marksObtained >= passMarks
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    border: Border.all(
                                      color: marksObtained >= passMarks ? Colors.green : Colors.red,
                                    ),
                                    borderRadius: BorderRadius.circular(radius.sm),
                                  ),
                                  child: Text(
                                    marksObtained >= passMarks ? 'PASS' : 'FAIL',
                                    style: TextStyle(
                                      color: marksObtained >= passMarks ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(),
                          SizedBox(height: spacing.xs),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 18, color: Colors.grey),
                              SizedBox(width: spacing.sm),
                              Text('Time: $startTime - $endTime'),
                            ],
                          ),
                          SizedBox(height: spacing.xs),
                          Row(
                            children: [
                              const Icon(Icons.room_rounded, size: 18, color: Colors.grey),
                              SizedBox(width: spacing.sm),
                              Text('Room Number: $room'),
                            ],
                          ),
                          SizedBox(height: spacing.xs),
                          Row(
                            children: [
                              const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Colors.grey),
                              SizedBox(width: spacing.sm),
                              Text('Max Marks: $maxMarks | Pass Marks: $passMarks'),
                            ],
                          ),
                          if (marksObtained != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(spacing.sm),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(radius.sm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Marks Obtained', style: theme.textTheme.bodySmall),
                                      Text(
                                        '$marksObtained / $maxMarks',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: marksObtained >= passMarks ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Status / Remarks', style: theme.textTheme.bodySmall),
                                      Text(
                                        '$resultStatus ($remarks)',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'Results: Awaiting publication',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
