import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/academic_provider.dart';
import '../../data/models/academic_models.dart';

class AcademicHeatmapView extends ConsumerWidget {
  final VoidCallback onSwitchToRecoveryTab;

  const AcademicHeatmapView({
    super.key,
    required this.onSwitchToRecoveryTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(academicStateProvider);
    final heatmap = state.academicHeatmap;

    if (state.isRecoveryLoading && heatmap == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (heatmap == null || heatmap.cells.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_view_rounded, size: 56, color: Colors.grey),
              SizedBox(height: spacing.md),
              const Text(
                'No syllabus progress records found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: spacing.sm),
              ElevatedButton.icon(
                onPressed: () => ref.read(academicStateProvider.notifier).fetchAcademicHeatmap(isRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Heatmap'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = heatmap.summary;
    final totalSubjects = (summary['total_subjects'] as num?)?.toInt() ?? heatmap.cells.length;
    final onTrackCount = (summary['on_track'] as num?)?.toInt() ?? 0;
    final atRiskCount = (summary['at_risk'] as num?)?.toInt() ?? 0;
    final delayedCount = (summary['delayed'] as num?)?.toInt() ?? 0;
    final avgCompletion = (summary['average_completion'] as num?)?.toDouble() ?? 0.0;

    final filter = state.selectedHeatmapFilter;
    final filteredCells = heatmap.cells.where((c) {
      if (filter == 'ON_TRACK') return c.status == 'ON_TRACK';
      if (filter == 'AT_RISK') return c.status == 'AT_RISK';
      if (filter == 'DELAYED') return c.status == 'DELAYED';
      if (filter == 'RECOVERY') return c.recoveryPlanActive;
      return true;
    }).toList();

    final Map<String, List<AcademicHeatmapCell>> groupedByClass = {};
    for (final cell in filteredCells) {
      final key = cell.className.isNotEmpty ? cell.className : 'Class';
      groupedByClass.putIfAbsent(key, () => []).add(cell);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(academicStateProvider.notifier).fetchAcademicHeatmap(isRefresh: true);
        await ref.read(academicStateProvider.notifier).fetchRecoveryPlans(isRefresh: true);
      },
      child: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          _buildKpiBanner(
            context,
            totalSubjects,
            onTrackCount,
            atRiskCount,
            delayedCount,
            avgCompletion,
            spacing,
            radius,
            theme,
          ),
          SizedBox(height: spacing.md),
          _buildFilterChips(ref, filter, state.recoveryPlans.length),
          SizedBox(height: spacing.md),
          if (state.absenceImpact != null) ...[
            _buildAbsenceImpactBanner(context, state.absenceImpact!, spacing, radius, theme, onSwitchToRecoveryTab),
            SizedBox(height: spacing.md),
          ],
          if (filteredCells.isEmpty)
            Container(
              padding: EdgeInsets.all(spacing.xl),
              alignment: Alignment.center,
              child: Text(
                'No subjects match the selected filter ($filter)',
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            ...groupedByClass.entries.map((entry) {
              return _buildClassGroupSection(context, entry.key, entry.value, spacing, radius, theme, onSwitchToRecoveryTab);
            }),
        ],
      ),
    );
  }

  Widget _buildKpiBanner(
    BuildContext context,
    int total,
    int onTrack,
    int atRisk,
    int delayed,
    double avgCompletion,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Color(0xFF0D9488), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Institutional Syllabus Health Matrix',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${avgCompletion.toStringAsFixed(1)}% Avg Coverage',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (avgCompletion / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
              minHeight: 6,
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              _buildBadge('$total Subjects', Icons.subject, const Color(0xFF0F766E)),
              const SizedBox(width: 8),
              _buildBadge('$onTrack On Track', Icons.check_circle_outline, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildBadge('$atRisk At Risk', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildBadge('$delayed Delayed', Icons.error_outline_rounded, const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, String currentFilter, int recoveryCount) {
    final filters = [
      {'key': 'ALL', 'label': 'All Subjects'},
      {'key': 'ON_TRACK', 'label': 'On Track'},
      {'key': 'AT_RISK', 'label': 'At Risk'},
      {'key': 'DELAYED', 'label': 'Delayed'},
      {'key': 'RECOVERY', 'label': 'Recovery Active ($recoveryCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = currentFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF0D9488),
              checkmarkColor: Colors.white,
              onSelected: (_) {
                ref.read(academicStateProvider.notifier).setHeatmapFilter(f['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAbsenceImpactBanner(
    BuildContext context,
    TeacherAbsenceImpact impact,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
    VoidCallback onSwitchToRecoveryTab,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Absence Impact: ${impact.teacherName} (${impact.absenceDate})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                ),
              ),
              TextButton(
                onPressed: onSwitchToRecoveryTab,
                child: const Text('View Plans →', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${impact.totalMissedPeriods} period(s) missed across ${impact.affectedClasses.length} class(es). Forecast shift identified.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );
  }

  Widget _buildClassGroupSection(
    BuildContext context,
    String className,
    List<AcademicHeatmapCell> cells,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
    VoidCallback onSwitchToRecoveryTab,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                className,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${cells.length} subjects',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: cells.map((cell) {
                  return SizedBox(
                    width: isWide ? (constraints.maxWidth - spacing.sm) / 2 : constraints.maxWidth,
                    child: _buildHeatmapCellCard(context, cell, spacing, radius, theme, onSwitchToRecoveryTab),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCellCard(
    BuildContext context,
    AcademicHeatmapCell cell,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
    VoidCallback onSwitchToRecoveryTab,
  ) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (cell.status.toUpperCase()) {
      case 'ON_TRACK':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'On Track';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'AT_RISK':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'At Risk (+${cell.delayDays}d)';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'DELAYED':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Delayed (+${cell.delayDays}d)';
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'AHEAD':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'Ahead';
        statusIcon = Icons.trending_up;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = cell.status;
        statusIcon = Icons.circle_outlined;
    }

    return InkWell(
      onTap: () => _showCellDetailModal(context, cell, onSwitchToRecoveryTab),
      borderRadius: BorderRadius.circular(radius.md),
      child: Container(
        padding: EdgeInsets.all(spacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius.md),
          border: Border.all(
            color: cell.recoveryPlanActive ? const Color(0xFF0D9488) : theme.colorScheme.outlineVariant,
            width: cell.recoveryPlanActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cell.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (cell.teacherName != null && cell.teacherName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Teacher: ${cell.teacherName}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            SizedBox(height: spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cell.completionPercentage.toStringAsFixed(1)}% covered',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (cell.forecastDate != null)
                  Text(
                    'Exp: ${cell.forecastDate}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (cell.completionPercentage / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 5,
              ),
            ),
            if (cell.recoveryPlanActive) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 10, color: Color(0xFF0D9488)),
                    SizedBox(width: 4),
                    Text(
                      'AI Recovery Active',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCellDetailModal(
    BuildContext context,
    AcademicHeatmapCell cell,
    VoidCallback onSwitchToRecoveryTab,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cell.subjectName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${cell.className} ${cell.sectionName} • ${cell.teacherName ?? "Teacher Assigned"}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow('Completion Progress', '${cell.completionPercentage.toStringAsFixed(1)}%'),
              _buildDetailRow('Pacing Health Status', cell.status),
              _buildDetailRow('Delay Shift', '${cell.delayDays} day(s)'),
              if (cell.targetDate != null)
                _buildDetailRow('Target Completion Date', cell.targetDate!),
              if (cell.forecastDate != null)
                _buildDetailRow('Projected Completion Date', cell.forecastDate!),
              _buildDetailRow('Active Recovery Plan', cell.recoveryPlanActive ? 'Yes' : 'No'),
              const SizedBox(height: 16),
              if (cell.recoveryPlanActive)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSwitchToRecoveryTab();
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Review / Edit Recovery Plan'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class RecoveryPlansListView extends ConsumerWidget {
  const RecoveryPlansListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(academicStateProvider);

    if (state.isRecoveryLoading && state.recoveryPlans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.recoveryPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey),
              SizedBox(height: spacing.md),
              const Text(
                'No active syllabus recovery plans.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: spacing.xs),
              const Text(
                'When teacher absences occur or pacing shifts behind target dates, AI recovery proposals will appear here for Principal review.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(height: spacing.md),
              ElevatedButton.icon(
                onPressed: () => ref.read(academicStateProvider.notifier).fetchRecoveryPlans(isRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Plans'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(academicStateProvider.notifier).fetchRecoveryPlans(isRefresh: true),
      child: ListView.separated(
        padding: EdgeInsets.all(spacing.md),
        itemCount: state.recoveryPlans.length,
        separatorBuilder: (_, __) => SizedBox(height: spacing.md),
        itemBuilder: (context, index) {
          final plan = state.recoveryPlans[index];
          return RecoveryPlanCard(plan: plan);
        },
      ),
    );
  }
}

class RecoveryPlanCard extends ConsumerStatefulWidget {
  final SyllabusRecoveryPlan plan;

  const RecoveryPlanCard({super.key, required this.plan});

  @override
  ConsumerState<RecoveryPlanCard> createState() => _RecoveryPlanCardState();
}

class _RecoveryPlanCardState extends ConsumerState<RecoveryPlanCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final plan = widget.plan;

    final hasConflict = plan.items.any((item) => item.conflictStatus == 'CONFLICT_DETECTED');
    final isApproved = plan.status == 'APPROVED';
    final isRejected = plan.status == 'REJECTED';

    Color statusColor;
    switch (plan.status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        break;
      case 'EDITED':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
        side: BorderSide(
          color: hasConflict ? const Color(0xFFEF4444) : theme.colorScheme.outlineVariant,
          width: hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.subjectName ?? 'Subject',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              plan.status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${plan.className ?? "Class"} ${plan.sectionName ?? ""} • Teacher: ${plan.teacherName ?? "Primary"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          plan.reason,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('Current: ${plan.currentCompletion.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      if (plan.targetCompletionDate != null)
                        Text('Target: ${plan.targetCompletionDate}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      if (plan.forecastCompletionDate != null)
                        Text('Shifted Forecast: ${plan.forecastCompletionDate}', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                      if (plan.newForecastDate != null)
                        Text('Recovered Forecast: ${plan.newForecastDate}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),
            if (hasConflict) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Timetable conflict detected in candidate slot(s). Please edit slots or regenerate before approving.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Text(
                'Candidate Recovery Slots (4 Phases)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...plan.items.map((item) => _buildSlotItem(context, item, plan.id, isApproved)),
              const SizedBox(height: 12),
              if (!isApproved && !isRejected)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      onPressed: () => _showRejectDialog(context, plan.id),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(academicStateProvider.notifier).regenerateRecoveryPlan(planId: plan.id),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Regenerate'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasConflict ? Colors.grey : const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: hasConflict
                          ? null
                          : () => _confirmApproval(context, plan.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve & Apply'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotItem(BuildContext context, RecoveryPlanItem item, String planId, bool isPlanApproved) {
    final isConflict = item.conflictStatus == 'CONFLICT_DETECTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isConflict ? const Color(0xFFFFF1F2) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConflict ? const Color(0xFFFDA4AF) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.phase.replaceAll('PHASE_', 'P'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.date} • Period ${item.periodNumber}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    if (isConflict)
                      const Icon(Icons.error_outline, size: 14, color: Colors.red)
                    else
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                  ],
                ),
                Text(
                  'Topic: ${item.topicName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (isConflict && item.conflictMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.conflictMessage!,
                      style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (!isPlanApproved)
            IconButton(
              icon: const Icon(Icons.edit_calendar_rounded, size: 18),
              tooltip: 'Edit Slot & Re-validate',
              onPressed: () => _showEditSlotDialog(context, planId, item),
            ),
        ],
      ),
    );
  }

  void _showEditSlotDialog(BuildContext context, String planId, RecoveryPlanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => EditRecoverySlotDialog(planId: planId, item: item),
    );
  }

  void _showRejectDialog(BuildContext context, String planId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Recovery Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please specify remarks or reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. Reschedule after examination term',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(academicStateProvider.notifier).rejectRecoveryPlan(planId, remarks: controller.text);
            },
            child: const Text('Reject Plan'),
          ),
        ],
      ),
    );
  }

  void _confirmApproval(BuildContext context, String planId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Recovery Plan'),
        content: const Text(
          'Approving this plan will commit the proposed recovery periods into the active school timetable and dispatch schedule update notifications to assigned teachers.\n\nProceed with operational update?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(academicStateProvider.notifier).approveRecoveryPlan(planId, remarks: 'Approved by Principal');
            },
            child: const Text('Approve & Publish'),
          ),
        ],
      ),
    );
  }
}

class EditRecoverySlotDialog extends ConsumerStatefulWidget {
  final String planId;
  final RecoveryPlanItem item;

  const EditRecoverySlotDialog({super.key, required this.planId, required this.item});

  @override
  ConsumerState<EditRecoverySlotDialog> createState() => _EditRecoverySlotDialogState();
}

class _EditRecoverySlotDialogState extends ConsumerState<EditRecoverySlotDialog> {
  late TextEditingController _dateController;
  late TextEditingController _topicController;
  late int _selectedPeriod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.item.date);
    _topicController = TextEditingController(text: widget.item.topicName);
    _selectedPeriod = widget.item.periodNumber;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updates = {
      'date': _dateController.text.trim(),
      'period_number': _selectedPeriod,
      'topic_name': _topicController.text.trim(),
    };

    final ok = await ref.read(academicStateProvider.notifier).updateRecoveryPlanItem(
      planId: widget.planId,
      itemId: widget.item.id,
      data: updates,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Recovery Slot'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            InkWell(
              onTap: _pickDate,
              child: IgnorePointer(
                child: TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Period Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: _selectedPeriod,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: List.generate(8, (i) => i + 1).map((p) {
                return DropdownMenuItem(value: p, child: Text('Period $p'));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPeriod = val);
              },
            ),
            const SizedBox(height: 12),
            const Text('Topic Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text(
              'Saving will instantly validate this slot against room, teacher clash, and calendar holidays.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save & Validate'),
        ),
      ],
    );
  }
}
