import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';


class StudentResultDetailScreen extends ConsumerWidget {
  final String studentId;

  const StudentResultDetailScreen({
    super.key,
    required this.studentId,
  });

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B':
      case 'C':
        return Colors.blue;
      case 'D':
      case 'E':
        return Colors.orange;
      case 'F':
      default:
        return Colors.red;
    }
  }

  Color _getPromotionColor(String status) {
    switch (status.toUpperCase()) {
      case 'PROMOTED':
        return Colors.green;
      case 'CONDITIONALLY_PROMOTED':
        return Colors.blue;
      case 'PROMOTION_UNDER_REVIEW':
        return Colors.amber.shade800;
      case 'DETAINED':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(studentResultDetailProvider(studentId));
    final historyAsync = ref.watch(studentAcademicHistoryProvider(studentId));
    final reportCardsState = ref.watch(resultsReportCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Result Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: detailAsync.when(
        data: (preview) {
          final reportCardList = reportCardsState.maybeWhen(
            data: (cards) => cards,
            orElse: () => const <ReportCardDto>[],
          );
          ReportCardDto? reportCard;
          for (final card in reportCardList) {
            if (card.studentId == studentId) {
              reportCard = card;
              break;
            }
          }


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Validation Banner
                if (!preview.isValid) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Text(
                                'Incomplete or Invalid Report Card Data',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...preview.missingReasons.map(
                            (reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0, left: 32.0),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 6, color: theme.colorScheme.onErrorContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double parentWidth = constraints.maxWidth;
                    final isWide = parentWidth > 800;

                    final infoWidget = Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.face, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Student Details',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow('Student Name', preview.studentName, theme),
                            _buildInfoRow('Admission No', preview.admissionNumber, theme),
                            _buildInfoRow('Roll Number', preview.rollNumber, theme),
                            _buildInfoRow('Class Name', preview.className, theme),
                            _buildInfoRow('Section Name', preview.sectionName, theme),
                          ],
                        ),
                      ),
                    );

                    final summaryWidget = Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Academic Summary',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            LayoutBuilder(
                              builder: (context, boxConstraints) {
                                final double cardWidth = boxConstraints.maxWidth > 500 ? (boxConstraints.maxWidth - 32) / 3 : (boxConstraints.maxWidth - 16) / 2;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Percentage',
                                        value: '${preview.overallPercentage}%',
                                        icon: Icons.percent,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Overall Grade',
                                        value: preview.overallGrade,
                                        icon: Icons.grade,
                                        color: _getGradeColor(preview.overallGrade),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildSummaryCard(
                                        context,
                                        label: 'Attendance',
                                        value: '${preview.attendancePresent}/${preview.attendanceTotal} (${preview.attendancePercentage}%)',
                                        icon: Icons.calendar_today,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Promotion Status:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getPromotionColor(preview.promotionStatus).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _getPromotionColor(preview.promotionStatus)),
                                  ),
                                  child: Text(
                                    preview.promotionStatus.replaceAll('_', ' '),
                                    style: TextStyle(
                                      color: _getPromotionColor(preview.promotionStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: infoWidget),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: summaryWidget),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          infoWidget,
                          const SizedBox(height: 16),
                          summaryWidget,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Chronological History & Trends & Progression Sections from history API
                historyAsync.when(
                  data: (history) {
                    if (history.examinations.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Performance History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('No examination history available for this student.'),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                      );
                    }

                    // Dynamically map subject grades across examinations
                    final Map<String, Map<String, String>> subjectProgress = {};
                    final List<String> examNames = history.examinations.map((e) => e.examinationName).toList();
                    for (final exam in history.examinations) {
                      for (final sub in exam.subjectMarks) {
                        subjectProgress.putIfAbsent(sub.subjectName, () => {});
                        subjectProgress[sub.subjectName]![exam.examinationName] = sub.marksObtained != null ? sub.marksObtained!.toStringAsFixed(0) : 'ABS';
                      }
                    }
                    final List<String> subjects = subjectProgress.keys.toList()..sort();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trend Section
                        Text(
                          'Academic Performance Trend',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: history.examinations.map((exam) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          exam.examinationName,
                                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: exam.percentage / 100.0,
                                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            color: theme.colorScheme.primary,
                                            minHeight: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${exam.percentage.toStringAsFixed(1)}%',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getGradeColor(exam.grade).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          exam.grade,
                                          style: TextStyle(
                                            color: _getGradeColor(exam.grade),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),

                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Subject Performance Matrix
                        Text(
                          'Subject Performance',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: [
                                  const DataColumn(label: Text('Subject')),
                                  ...examNames.map((name) => DataColumn(
                                    label: Text(name),
                                  )).toList(),
                                ],
                                rows: subjects.map((subName) {
                                  final progress = subjectProgress[subName]!;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(subName)),
                                      ...examNames.map((name) {
                                        final val = progress[name] ?? '-';
                                        return DataCell(Text(val));
                                      }).toList(),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Expandable Examination summaries
                        Text(
                          'Academic Performance History',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...history.examinations.map((exam) {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                exam.examinationName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Total: ${exam.totalObtainedMarks.toStringAsFixed(0)} / ${exam.totalMaxMarks}  |  Percentage: ${exam.percentage}%  |  Grade: ${exam.grade}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Subject')),
                                        DataColumn(label: Text('Max Marks')),
                                        DataColumn(label: Text('Marks Obtained')),
                                        DataColumn(label: Text('Grade')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Remarks')),
                                      ],
                                      rows: exam.subjectMarks.map((sub) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(sub.subjectName)),
                                            DataCell(Text(sub.maxMarks.toString())),
                                            DataCell(Text(sub.marksObtained?.toString() ?? 'ABSENT')),
                                            DataCell(Text(
                                              sub.grade,
                                              style: TextStyle(
                                                color: _getGradeColor(sub.grade),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )),
                                            DataCell(Text(sub.status)),
                                            DataCell(Text(sub.remarks ?? '')),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading academic history...'),
                        ],
                      ),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Unable to load academic history.',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(studentAcademicHistoryProvider(studentId));
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Auditor Remarks Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment_outlined, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Signatures & Remarks',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          'Teacher Remarks',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.teacherRemarks ?? 'No remarks provided.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Principal Remarks',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.principalRemarks ?? 'No remarks provided.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // AI Analytics & Predictions Card
                if (reportCard != null && reportCard.aiMetrics.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'AI Predictive Analytics',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Risk Level', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(
                                      reportCard.aiMetrics['risk_level'] ?? 'LOW',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: (reportCard.aiMetrics['risk_level'] == 'HIGH') ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Academic Trend', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(
                                      reportCard.aiMetrics['overall_trend'] ?? 'STABLE',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: (reportCard.aiMetrics['overall_trend'] == 'IMPROVING') 
                                            ? Colors.green 
                                            : ((reportCard.aiMetrics['overall_trend'] == 'DECLINING') ? Colors.red : Colors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('AI Performance Insights', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            reportCard.aiMetrics['ai_narrative'] ?? 'Insights not computed yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading results detail: $err', style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(studentResultDetailProvider(studentId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
