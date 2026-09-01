import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
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

final parentExamsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  final apiClient = ref.read(apiClientProvider);
  
  final examResult = await apiClient.get(
    '/examinations/parent',
    queryParameters: {'school_id': schoolId},
    mapper: (json) => json as Map<String, dynamic>,
  );
  
  final marksResult = await apiClient.get(
    '/marks/student',
    queryParameters: {'school_id': schoolId},
    mapper: (json) => json as Map<String, dynamic>,
  );

  final List exams = examResult.when(
    onSuccess: (data) => (data['data'] as List?) ?? [],
    onFailure: (_) => [],
  );

  final List marks = marksResult.when(
    onSuccess: (data) => (data['data'] as List?) ?? [],
    onFailure: (_) => [],
  );

  final List<Map<String, dynamic>> combined = [];
  for (final exam in exams) {
    final scheduleId = exam['id'] as String?;
    final examId = exam['exam_id'] as String?;
    
    final matchingMark = marks.firstWhere(
      (m) => m['exam_schedule_id'] == scheduleId || m['examination_id'] == examId,
      orElse: () => null,
    );

    combined.add({
      'schedule': exam,
      'mark': matchingMark,
    });
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

    // Get selected student context
    String studentName = 'Rahul Sharma';
    final authState = ref.watch(authStateProvider);
    String schoolId = '16730f87-bf8d-44e0-acf9-4b055a778b58';
    if (authState is Authenticated) {
      schoolId = authState.user.schools.firstOrNull ?? schoolId;
    }
    final dbState = ref.watch(dashboardStateProvider);
    if (dbState is DashboardSuccess) {
      final selected = dbState.data.selectedStudent;
      if (selected != null) {
        studentName = selected.fullName;
      }
    }

    final examsAsync = ref.watch(parentExamsProvider(schoolId));

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
            onRefresh: () => ref.refresh(parentExamsProvider(schoolId).future),
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
                              Text(
                                'Exam: $dateStr',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
