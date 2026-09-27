import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../data/models/academic_predictive_models.dart';
import '../providers/academic_predictive_providers.dart';

class PredictiveAnalyticsView extends ConsumerStatefulWidget {
  final String? initialClassId;
  final String? initialAcademicYearId;
  final GlobalKey? chapterSectionKey;
  final GlobalKey? syllabusSectionKey;

  const PredictiveAnalyticsView({
    super.key,
    this.initialClassId,
    this.initialAcademicYearId,
    this.chapterSectionKey,
    this.syllabusSectionKey,
  });

  @override
  ConsumerState<PredictiveAnalyticsView> createState() => _PredictiveAnalyticsViewState();
}

class _PredictiveAnalyticsViewState extends ConsumerState<PredictiveAnalyticsView> {
  String? _selectedClassId;
  String? _selectedAyId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    _selectedAyId = widget.initialAcademicYearId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndFetch();
    });
  }

  @override
  void didUpdateWidget(covariant PredictiveAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldFetch = false;
    if (widget.initialAcademicYearId != oldWidget.initialAcademicYearId &&
        widget.initialAcademicYearId != null &&
        widget.initialAcademicYearId != _selectedAyId) {
      _selectedAyId = widget.initialAcademicYearId;
      shouldFetch = true;
    }
    if (widget.initialClassId != oldWidget.initialClassId &&
        widget.initialClassId != null &&
        widget.initialClassId != _selectedClassId) {
      _selectedClassId = widget.initialClassId;
      shouldFetch = true;
    }
    if (shouldFetch) {
      _onFilterChanged();
    }
  }

  void _initAndFetch() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId != null) {
      final years = ref.read(academicYearsProvider(schoolId)).years;
      final classes = ref.read(classesProvider(schoolId)).classes;

      if (_selectedAyId == null && years.isNotEmpty) {
        _selectedAyId = years.first.id;
      }
      if (_selectedClassId == null && classes.isNotEmpty) {
        _selectedClassId = classes.first.id;
      }

      if (_selectedClassId != null && _selectedAyId != null) {
        ref.read(academicPredictiveProvider.notifier).fetchPredictiveIntelligence(
          classId: _selectedClassId,
          academicYearId: _selectedAyId,
          subjectId: _selectedSubjectId,
        );
      }
    }
  }

  void _onFilterChanged() {
    if (_selectedClassId != null && _selectedAyId != null) {
      ref.read(academicPredictiveProvider.notifier).fetchPredictiveIntelligence(
        classId: _selectedClassId,
        academicYearId: _selectedAyId,
        subjectId: _selectedSubjectId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final predictiveState = ref.watch(academicPredictiveProvider);

    final years = schoolId != null ? (ref.watch(academicYearsProvider(schoolId)).years.whereType<AcademicYearDto>().toList()) : <AcademicYearDto>[];
    final classes = schoolId != null ? (ref.watch(classesProvider(schoolId)).classes.whereType<ClassDto>().toList()) : <ClassDto>[];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF0D9488), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Predictive Intelligence',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Grounded trajectory forecasting, syllabus alignment, & subject risk models',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Predictive Data',
                onPressed: _onFilterChanged,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Bar
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Academic Year
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _selectedAyId,
                  decoration: const InputDecoration(
                    labelText: 'Analytics Academic Year',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.name))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedAyId = val);
                    _onFilterChanged();
                  },
                ),
              ),
              // Class
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Analytics Class',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedClassId = val);
                    _onFilterChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content body
          if (predictiveState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Evaluating academic cycles & predictive metrics...'),
                  ],
                ),
              ),
            )
          else if (predictiveState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.error),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      predictiveState.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            )
          else if (predictiveState.analytics != null)
            _buildPredictiveDashboard(context, predictiveState.analytics!)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Please select an Academic Year and Class to view predictive analytics.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPredictiveDashboard(BuildContext context, AcademicPredictiveAnalyticsModel analytics) {
    final sufficiency = analytics.dataSufficiency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Data Sufficiency Banner
        _buildSufficiencyBanner(context, sufficiency),
        const SizedBox(height: 24),

        // 2. State-specific content
        if (sufficiency.isInsufficient)
          _buildInsufficientDataState(context, sufficiency)
        else if (sufficiency.isDescriptiveOnly)
          _buildDescriptiveOnlyState(context, analytics)
        else
          _buildActivePredictiveState(context, analytics),
      ],
    );
  }

  Widget _buildSufficiencyBanner(BuildContext context, DataSufficiencyModel sufficiency) {
    Color bannerBg;
    Color bannerBorder;
    Color iconColor;
    IconData icon;
    String title;

    if (sufficiency.isInsufficient) {
      bannerBg = const Color(0xFFFEF3C7);
      bannerBorder = const Color(0xFFF59E0B);
      iconColor = const Color(0xFFB45309);
      icon = Icons.info_outline;
      title = 'Data Sufficiency Tier: Insufficient Assessment Data (0 Exams Recorded)';
    } else if (sufficiency.isDescriptiveOnly) {
      bannerBg = const Color(0xFFEFF6FF);
      bannerBorder = const Color(0xFF3B82F6);
      iconColor = const Color(0xFF1D4ED8);
      icon = Icons.insights_rounded;
      title = 'Data Sufficiency Tier: Descriptive Baseline Only (1 Exam Cycle)';
    } else {
      bannerBg = const Color(0xFFF0FDF4);
      bannerBorder = const Color(0xFF10B981);
      iconColor = const Color(0xFF047857);
      icon = Icons.verified_rounded;
      title = 'Data Sufficiency Tier: Predictive Engine Active (${sufficiency.examCount} Exam Cycles Recorded)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: iconColor, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  sufficiency.statusMessage,
                  style: TextStyle(color: iconColor.withValues(alpha: 0.9), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataState(BuildContext context, DataSufficiencyModel sufficiency) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.query_stats_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No Predictive Models Rendered',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'To uphold zero-hallucination compliance, EduPulse does not project scores or predict academic trajectories without verified examination data. Import examination marks to activate performance insights.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptiveOnlyState(BuildContext context, AcademicPredictiveAnalyticsModel analytics) {
    final theme = Theme.of(context);
    final subjects = analytics.subjectPerformance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Single Examination Cycle Performance Summary',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth >= 650 ? 2 : 1);
            final cardWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: subjects.map((sub) {
                return SizedBox(
                  width: cardWidth,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sub.subjectName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildDifficultyChip(sub.difficultyRating),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildMetricColumn('Class Avg', '${sub.averagePercentage.toStringAsFixed(1)}%')),
                              Expanded(child: _buildMetricColumn('Min', '${sub.minPercentage.toStringAsFixed(1)}%')),
                              Expanded(child: _buildMetricColumn('Max', '${sub.maxPercentage.toStringAsFixed(1)}%')),
                              Expanded(child: _buildMetricColumn('Pass Rate', '${sub.passRatePercentage.toStringAsFixed(1)}%')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        _buildChapterPerformanceSection(context, analytics.chapterPerformance),
      ],
    );
  }

  Widget _buildActivePredictiveState(BuildContext context, AcademicPredictiveAnalyticsModel analytics) {
    final theme = Theme.of(context);
    final subjects = analytics.subjectPerformance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject-Level Projections & Risk Trajectories',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        // Subject Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth >= 650 ? 2 : 1);
            final cardWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: subjects.map((sub) {
                return SizedBox(
                  width: cardWidth,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sub.subjectName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildRiskBadge(sub.riskLevel),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${sub.subjectCode} | Difficulty: ${sub.difficultyRating}',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildMetricColumn('Historical Avg', '${sub.averagePercentage.toStringAsFixed(1)}%')),
                              Expanded(child: _buildMetricColumn('Pass Rate', '${sub.passRatePercentage.toStringAsFixed(1)}%')),
                              Expanded(child: _buildMetricColumn('Syllabus Cov.', '${sub.syllabusCoveragePct.toStringAsFixed(0)}%')),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (sub.predictedScoreBand != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.trending_up, color: Color(0xFF0D9488), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Predicted Score Band: ${sub.predictedScoreBand!.minPercentage.toStringAsFixed(1)}% – ${sub.predictedScoreBand!.maxPercentage.toStringAsFixed(1)}% (${sub.predictedScoreBand!.confidenceInterval} CI)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        // Chapter Performance Block
        _buildChapterPerformanceSection(context, analytics.chapterPerformance),
        const SizedBox(height: 24),
        // Syllabus Correlation Block
        _buildSyllabusCorrelationSection(context, analytics.syllabusCorrelation),
      ],
    );
  }

  Widget _buildChapterPerformanceSection(BuildContext context, ChapterPerformanceBlock block) {
    final theme = Theme.of(context);

    if (!block.isAvailable) {
      return Container(
        key: widget.chapterSectionKey ?? const Key('section_chapter_question_mapping'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.link_off_rounded, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.message.isNotEmpty
                        ? block.message
                        : 'Chapter-level analysis unavailable because examination questions are not mapped.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tip: Open an examination in the Examinations Hub, navigate to Papers, and configure Question Mapping to link questions to syllabus chapters.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: widget.chapterSectionKey ?? const Key('section_chapter_question_mapping'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mapped Syllabus Chapter Accuracy & Focus Areas',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1150 ? 3 : (constraints.maxWidth >= 650 ? 2 : 1);
              final cardWidth = (constraints.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: block.chapters.map((ch) {
                  return SizedBox(
                    width: cardWidth,
                    child: Card(
                      elevation: 0,
                      color: ch.weakAreaAlert ? const Color(0xFFFEF2F2) : theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: ch.weakAreaAlert ? const Color(0xFFF87171) : theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ch.chapterName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (ch.weakAreaAlert)
                                  const Chip(
                                    label: Text('Weak Area', style: TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: Color(0xFFDC2626),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${ch.subjectName} • ${ch.totalQuestions} Questions (${ch.totalMarksAllocated.toInt()} Marks)',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Accuracy: ${ch.averageAccuracyPct.toStringAsFixed(1)}% | Difficulty: ${ch.difficulty}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ch.weakAreaAlert ? const Color(0xFFB91C1C) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusCorrelationSection(BuildContext context, SyllabusCorrelationBlock correlation) {
    final theme = Theme.of(context);
    if (!correlation.isAvailable) return const SizedBox.shrink();

    return Container(
      key: widget.syllabusSectionKey ?? const Key('section_syllabus_coverage'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: Color(0xFF0D9488), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Curriculum Pacing & Exam Score Correlation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  correlation.coverageVsScoreSummary ?? correlation.message,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          if (correlation.correlationIndex != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'r = ${correlation.correlationIndex!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color bg;
    Color text;
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case 'HARD':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      default:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(difficulty, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color bg;
    Color text;
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      case 'MODERATE':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      default:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text('$riskLevel RISK', style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
