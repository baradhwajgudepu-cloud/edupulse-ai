import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import '../providers/school_setup_providers.dart';

class SchoolSetupProgressCard extends ConsumerStatefulWidget {
  const SchoolSetupProgressCard({super.key});

  @override
  ConsumerState<SchoolSetupProgressCard> createState() => _SchoolSetupProgressCardState();
}

class _SchoolSetupProgressCardState extends ConsumerState<SchoolSetupProgressCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schoolsState = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final selectedSchool = schoolsState.schools.where((s) => s.id == selectedSchoolId).firstOrNull;

    if (selectedSchool == null || selectedSchoolId == null) return const SizedBox.shrink();

    final progressAsync = ref.watch(schoolSetupProgressProvider(selectedSchoolId));

    // Fallback steps if loading or network error
    final fallbackSteps = [
      _SetupStep(title: 'School Profile', description: 'Institution details & branding', isCompleted: true, route: AppRoutes.schoolSetup, actionLabel: 'View'),
      _SetupStep(title: 'Principal Account', description: 'Administrator credentials & scope', isCompleted: true, route: AppRoutes.users, actionLabel: 'View'),
      _SetupStep(title: 'Academic Year', description: 'Current session & instructional calendar', isCompleted: false, route: '${AppRoutes.schools}/$selectedSchoolId/academic-years', actionLabel: 'Configure'),
      const _SetupStep(title: 'Classes & Sections', description: 'Grade levels and academic streams', isCompleted: false, route: AppRoutes.classes, actionLabel: 'Add Classes'),
      const _SetupStep(title: 'Teachers & Staff', description: 'Faculty roster & designations', isCompleted: false, route: AppRoutes.teachers, actionLabel: 'Add Staff'),
      const _SetupStep(title: 'Students & Guardians', description: 'Student roster & parent contacts', isCompleted: false, route: AppRoutes.students, actionLabel: 'Add Students'),
      const _SetupStep(title: 'Fee Configuration', description: 'Fee structures & payment terms', isCompleted: false, route: AppRoutes.fees, actionLabel: 'Configure'),
      const _SetupStep(title: 'Attendance & Timetable', description: 'Attendance tracking & slots', isCompleted: false, route: AppRoutes.attendance, actionLabel: 'Configure'),
    ];

    final steps = progressAsync.valueOrNull != null
        ? progressAsync.value!.steps
            .map((s) => _SetupStep(
                  title: s.title,
                  description: s.description,
                  isCompleted: s.isCompleted,
                  route: s.route,
                  actionLabel: s.actionLabel,
                ))
            .toList()
        : fallbackSteps;

    final completedCount = progressAsync.valueOrNull?.completedCount ?? steps.where((s) => s.isCompleted).length;
    final totalSteps = progressAsync.valueOrNull?.totalSteps ?? steps.length;
    final progressPct = progressAsync.valueOrNull?.progressPercentage ?? (completedCount / totalSteps * 100).round();

    if (progressPct >= 100) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch_outlined, color: Color(0xFF0F766E), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Setup Progress: $completedCount / $totalSteps completed ($progressPct%)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Progressive setup is resumable. Incomplete steps never block daily school operations.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isExpanded ? 'Hide Steps' : 'View Steps'),
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completedCount / totalSteps,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressPct > 60 ? const Color(0xFF059669) : const Color(0xFF0F766E),
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final step = steps[idx];
                  return Row(
                    children: [
                      Icon(
                        step.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 18,
                        color: step.isCompleted ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: step.isCompleted ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              step.description,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(step.route),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              step.isCompleted ? 'Review' : step.actionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: step.isCompleted ? const Color(0xFF64748B) : const Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: step.isCompleted ? const Color(0xFF64748B) : const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupStep {
  final String title;
  final String description;
  final bool isCompleted;
  final String route;
  final String actionLabel;

  const _SetupStep({
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.route,
    required this.actionLabel,
  });
}
