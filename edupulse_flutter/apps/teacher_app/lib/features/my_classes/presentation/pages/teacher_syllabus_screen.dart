import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../data/models/teacher_syllabus_models.dart';
import '../providers/teacher_syllabus_provider.dart';

class TeacherSyllabusScreen extends ConsumerStatefulWidget {
  final String classId;
  final String sectionId;
  final String subjectId;
  final String className;
  final String sectionName;
  final String subjectName;

  const TeacherSyllabusScreen({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.className,
    required this.sectionName,
    required this.subjectName,
  });

  @override
  ConsumerState<TeacherSyllabusScreen> createState() => _TeacherSyllabusScreenState();
}

class _TeacherSyllabusScreenState extends ConsumerState<TeacherSyllabusScreen> {
  late TeacherSyllabusQuery _query;

  @override
  void initState() {
    super.initState();
    _query = TeacherSyllabusQuery(
      classId: widget.classId,
      sectionId: widget.sectionId,
      subjectId: widget.subjectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final state = ref.watch(teacherSyllabusProvider(_query));
    final notifier = ref.read(teacherSyllabusProvider(_query).notifier);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subjectName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.className} - ${widget.sectionName} • Syllabus Progress',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh syllabus data',
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null && state.items.isEmpty
              ? _buildErrorView(state.errorMessage!, notifier, theme, spacing, radius)
              : RefreshIndicator(
                  onRefresh: () => notifier.load(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.prediction != null) ...[
                          _buildPacingAndRiskHero(state.prediction!, theme, spacing, radius),
                          SizedBox(height: spacing.md),
                        ],
                        _buildFilterRow(state, notifier, theme, spacing),
                        SizedBox(height: spacing.md),
                        if (state.items.isEmpty)
                          _buildEmptyView(theme, spacing, radius)
                        else
                          _buildSyllabusGroupedList(state, notifier, theme, spacing, radius),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPacingAndRiskHero(
    TeacherSyllabusPrediction pred,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacing & Completion Intelligence',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: spacing.xs / 2),
                      Text(
                        pred.message.isNotEmpty
                            ? pred.message
                            : 'AI syllabus monitoring compares completed chapters against academic calendar.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2),
                  decoration: BoxDecoration(
                    color: pred.riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(radius.sm),
                    border: Border.all(color: pred.riskColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    pred.riskLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pred.riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Syllabus Coverage: ${pred.completionPercentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pred.completedChapters}/${pred.totalChapters} Chapters',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(radius.xs),
                  child: LinearProgressIndicator(
                    value: (pred.completionPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pred.completionPercentage >= 95 ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            // Metric Pills
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.xs,
              children: [
                _buildMetricPill(
                  icon: Icons.speed_rounded,
                  label: 'Planned Pace',
                  value: '${pred.plannedPace.toStringAsFixed(1)} ch/wk',
                  theme: theme,
                  radius: radius,
                ),
                _buildMetricPill(
                  icon: Icons.directions_run_rounded,
                  label: 'Actual Pace',
                  value: '${pred.actualPace.toStringAsFixed(1)} ch/wk',
                  theme: theme,
                  radius: radius,
                ),
                if (pred.projectedCompletionDate != null)
                  _buildMetricPill(
                    icon: Icons.event_available_rounded,
                    label: 'Projected Completion',
                    value: '${pred.projectedCompletionDate} (Est.)',
                    theme: theme,
                    radius: radius,
                  ),
              ],
            ),
            if (pred.targetExamName != null) ...[
              SizedBox(height: spacing.sm),
              Container(
                padding: EdgeInsets.all(spacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm_on_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: spacing.xs),
                    Expanded(
                      child: Text(
                        'Target Exam: ${pred.targetExamName} (${pred.targetExamDate ?? 'TBD'}) - ${pred.daysGapToExam ?? 0} days remaining',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (pred.recommendedAction != null && pred.recommendedAction!.isNotEmpty) ...[
              SizedBox(height: spacing.xs),
              Container(
                padding: EdgeInsets.all(spacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(radius.sm),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: spacing.xs),
                    Expanded(
                      child: Text(
                        'Adaptive Advice: ${pred.recommendedAction}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required AppRadius radius,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
    TeacherSyllabusState state,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
    AppSpacing spacing,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', 'All (${state.items.length})', state.filter, notifier, theme),
          SizedBox(width: spacing.xs),
          _buildFilterChip('IN_PROGRESS', 'In Progress (${state.inProgressCount})', state.filter, notifier, theme),
          SizedBox(width: spacing.xs),
          _buildFilterChip('COMPLETED', 'Completed (${state.completedCount})', state.filter, notifier, theme),
          SizedBox(width: spacing.xs),
          _buildFilterChip('PENDING', 'Pending (${state.pendingCount})', state.filter, notifier, theme),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String filterValue,
    String label,
    String activeFilter,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
  ) {
    final isSelected = activeFilter == filterValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => notifier.setFilter(filterValue),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSyllabusGroupedList(
    TeacherSyllabusState state,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final items = state.filteredItems;

    // Group items by Unit -> Chapter
    final grouped = <String, Map<String, List<TeacherSyllabusItem>>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.unitName, () => {});
      grouped[item.unitName]!.putIfAbsent(item.chapterName, () => []);
      grouped[item.unitName]![item.chapterName]!.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((unitEntry) {
        final unitName = unitEntry.key;
        final chapters = unitEntry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.xs),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, size: 18, color: theme.colorScheme.primary),
                  SizedBox(width: spacing.xs),
                  Text(
                    unitName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            ...chapters.entries.map((chapterEntry) {
              final chapterName = chapterEntry.key;
              final topics = chapterEntry.value;

              return Card(
                elevation: 0,
                margin: EdgeInsets.only(bottom: spacing.sm),
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius.md),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 16, color: theme.colorScheme.secondary),
                          SizedBox(width: spacing.xs),
                          Expanded(
                            child: Text(
                              chapterName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${topics.length} topics',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      ...topics.map((topic) {
                        final progress = state.progressMap[topic.id];
                        return _buildTopicRow(topic, progress, notifier, theme, spacing, radius);
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTopicRow(
    TeacherSyllabusItem topic,
    TeacherCoverageProgressItem? progress,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final status = (progress?.status ?? topic.coverageStatus).toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS' || status == 'ONGOING';
    final percentage = progress?.completionPercentage ?? (isCompleted ? 100.0 : 0.0);

    Color statusColor = const Color(0xFF94A3B8);
    if (isCompleted) statusColor = const Color(0xFF10B981);
    if (isInProgress) statusColor = const Color(0xFF0F766E);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Container(
        padding: EdgeInsets.all(spacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(radius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkmark button for rapid one-tap completion
            InkWell(
              onTap: () {
                final newStatus = isCompleted ? 'NOT_STARTED' : 'COMPLETED';
                final newPct = isCompleted ? 0.0 : 100.0;
                notifier.recordProgress(
                  syllabusId: topic.id,
                  status: newStatus,
                  completionPercentage: newPct,
                  remarks: progress?.remarks,
                );
              },
              borderRadius: BorderRadius.circular(radius.sm),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted ? const Color(0xFF10B981) : theme.colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : isInProgress
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F766E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(radius.xs),
                        ),
                        child: Text(
                          '#${topic.sequenceOrder}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      Expanded(
                        child: Text(
                          topic.topicName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Row(
                    children: [
                      Text(
                        '⏱️ ${topic.estimatedPeriods} periods',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(radius.xs),
                        ),
                        child: Text(
                          isInProgress
                              ? '${percentage.toStringAsFixed(0)}% In Progress'
                              : isCompleted
                                  ? 'Done'
                                  : 'Pending',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (progress?.remarks != null && progress!.remarks!.isNotEmpty) ...[
                    SizedBox(height: spacing.xs / 2),
                    Text(
                      'Note: "${progress.remarks}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18),
              tooltip: 'Update progress details',
              onPressed: () => _showProgressBottomSheet(topic, progress, notifier, theme, spacing, radius),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgressBottomSheet(
    TeacherSyllabusItem topic,
    TeacherCoverageProgressItem? progress,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    String currentStatus = (progress?.status ?? topic.coverageStatus).toUpperCase();
    if (currentStatus == 'PENDING') currentStatus = 'NOT_STARTED';
    double currentPct = progress?.completionPercentage ?? (currentStatus == 'COMPLETED' ? 100.0 : 0.0);
    final remarksController = TextEditingController(text: progress?.remarks ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: spacing.lg,
                right: spacing.lg,
                top: spacing.lg,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + spacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Update Topic Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    Text(
                      '${topic.chapterName} • ${topic.topicName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Teaching Status',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.xs),
                    Wrap(
                      spacing: spacing.sm,
                      children: [
                        _buildStatusChoiceChip('NOT_STARTED', 'Not Started', currentStatus, (val) {
                          setModalState(() {
                            currentStatus = val;
                            currentPct = 0.0;
                          });
                        }, theme),
                        _buildStatusChoiceChip('IN_PROGRESS', 'In Progress', currentStatus, (val) {
                          setModalState(() {
                            currentStatus = val;
                            if (currentPct <= 0.0 || currentPct >= 100.0) currentPct = 50.0;
                          });
                        }, theme),
                        _buildStatusChoiceChip('COMPLETED', 'Completed', currentStatus, (val) {
                          setModalState(() {
                            currentStatus = val;
                            currentPct = 100.0;
                          });
                        }, theme),
                        _buildStatusChoiceChip('SKIPPED', 'Skipped', currentStatus, (val) {
                          setModalState(() {
                            currentStatus = val;
                          });
                        }, theme),
                      ],
                    ),
                    SizedBox(height: spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completion Percentage',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${currentPct.toStringAsFixed(0)}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: currentPct,
                      min: 0.0,
                      max: 100.0,
                      divisions: 20,
                      label: '${currentPct.toStringAsFixed(0)}%',
                      onChanged: (val) {
                        setModalState(() {
                          currentPct = val;
                          if (currentPct == 100.0) {
                            currentStatus = 'COMPLETED';
                          } else if (currentPct > 0.0) {
                            currentStatus = 'IN_PROGRESS';
                          } else {
                            currentStatus = 'NOT_STARTED';
                          }
                        });
                      },
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Teacher Remarks / Homework Notes',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.xs),
                    TextField(
                      controller: remarksController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Completed theory, class exercises 1-5 solved.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius.sm),
                        ),
                        contentPadding: EdgeInsets.all(spacing.sm),
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: spacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius.sm),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Save Teaching Progress'),
                        onPressed: () async {
                          Navigator.pop(modalCtx);
                          final ok = await notifier.recordProgress(
                            syllabusId: topic.id,
                            status: currentStatus,
                            completionPercentage: currentPct,
                            remarks: remarksController.text.trim(),
                          );
                          if (mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Updated progress for "${topic.topicName}".'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChoiceChip(
    String value,
    String label,
    String current,
    ValueChanged<String> onSelected,
    ThemeData theme,
  ) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme, AppSpacing spacing, AppRadius radius) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_rounded, size: 64, color: theme.colorScheme.outlineVariant),
            SizedBox(height: spacing.md),
            Text(
              'No Syllabus Items Found',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'No syllabus items have been created for this class & subject yet, or none match the active filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(
    String error,
    TeacherSyllabusNotifier notifier,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            SizedBox(height: spacing.md),
            Text(
              'Unable to Load Syllabus',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.lg),
            ElevatedButton(
              onPressed: () => notifier.load(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
