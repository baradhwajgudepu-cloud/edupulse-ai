import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/working_hours_providers.dart';

class TimetableCapacityCard extends ConsumerWidget {
  final String schoolId;
  final String academicYearId;
  final String? classId;
  final String? sectionId;
  final VoidCallback onConfigureWorkingHours;
  final VoidCallback onOptimizeTimetable;
  final VoidCallback onReviewSubjects;

  const TimetableCapacityCard({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    this.classId,
    this.sectionId,
    required this.onConfigureWorkingHours,
    required this.onOptimizeTimetable,
    required this.onReviewSubjects,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capacityAsync = ref.watch(timetableCapacityProvider((
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    )));

    return capacityAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (cap) {
        final isShortfall = cap.isShortfall;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isShortfall ? Colors.amber.shade700 : theme.colorScheme.outlineVariant,
              width: isShortfall ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          color: isShortfall
              ? Colors.amber.shade50.withValues(alpha: 0.7)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Metrics + Configure Hours Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Icon(
                            isShortfall ? Icons.warning_amber_rounded : Icons.pie_chart_outline,
                            color: isShortfall ? Colors.amber.shade900 : theme.colorScheme.primary,
                            size: 22,
                          ),
                          Text(
                            'Weekly Timetable Capacity',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isShortfall ? Colors.amber.shade900 : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isShortfall ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isShortfall ? Colors.red.shade400 : Colors.green.shade400,
                              ),
                            ),
                            child: Text(
                              isShortfall ? 'SHORTFALL: -${cap.shortfallPeriods} PERIODS' : 'CAPACITY BALANCED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isShortfall ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ),
                          if (cap.isExtendedHoursEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.more_time, size: 14, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Extended Hours (+${cap.extendedHoursPotentialCapacity}p)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Configure School Hours'),
                      onPressed: onConfigureWorkingHours,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metrics Row
                Row(
                  children: [
                    _buildMetricChip(
                      context,
                      label: 'Available Periods',
                      value: '${cap.availableWeeklyCapacity}',
                      subLabel: '${cap.workingDaysCount} days × ${cap.periodsPerDay} p/day',
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      context,
                      label: 'Required Demand',
                      value: '${cap.totalRequiredPeriods}',
                      subLabel: '${cap.officialSubjectsCount} board + ${cap.schoolAddedSubjectsCount} school subjects',
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      context,
                      label: isShortfall ? 'Period Deficit' : 'Unallocated Slots',
                      value: isShortfall ? '${cap.shortfallPeriods}' : '${cap.remainingCapacity}',
                      valueColor: isShortfall ? Colors.red.shade800 : Colors.green.shade800,
                      subLabel: isShortfall ? 'Exceeds working hours' : 'Free/activity periods',
                    ),
                  ],
                ),

                // Shortfall Warning Banner with Remediation Actions
                if (isShortfall) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cap.shortfallWarningMessage ??
                                    'Timetable Capacity Shortfall: Required periods exceed available school hours.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Remediation Options:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ActionChip(
                              avatar: const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
                              label: const Text('Optimize Existing Timetable'),
                              backgroundColor: Colors.white,
                              onPressed: onOptimizeTimetable,
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.more_time, size: 16, color: Colors.blue),
                              label: const Text('Add Working Hours'),
                              backgroundColor: Colors.white,
                              onPressed: onConfigureWorkingHours,
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.list_alt, size: 16, color: Colors.deepPurple),
                              label: const Text('Review Subject Periods'),
                              backgroundColor: Colors.white,
                              onPressed: onReviewSubjects,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String value,
    required String subLabel,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(subLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
