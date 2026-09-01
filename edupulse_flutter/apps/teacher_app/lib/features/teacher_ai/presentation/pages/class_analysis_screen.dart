import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';
import '../providers/teacher_ai_provider.dart';
import '../../data/models/teacher_ai_dtos.dart';

class ClassAnalysisScreen extends ConsumerStatefulWidget {
  const ClassAnalysisScreen({super.key});

  @override
  ConsumerState<ClassAnalysisScreen> createState() => _ClassAnalysisScreenState();
}

class _ClassAnalysisScreenState extends ConsumerState<ClassAnalysisScreen> {
  TeacherClassGroupEntity? _selectedClassGroup;
  TeacherSubjectAssignmentEntity? _selectedSubject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
      ref.read(classAnalysisNotifierProvider.notifier).clearAnalysis();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final classesState = ref.watch(myClassesStateProvider);
    final analysisState = ref.watch(classAnalysisNotifierProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Class Performance Analysis'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dropdowns Selector Header
            _buildSelectorHeader(classesState, theme, spacing, radius),
            
            // Content View
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.md),
                child: switch (analysisState) {
                  ClassAnalysisInitial() => _buildInitialState(theme, spacing),
                  ClassAnalysisLoading() => _buildLoadingState(theme, spacing),
                  ClassAnalysisSuccess(:final analysis) => _buildAnalysisContent(analysis, theme, spacing, radius),
                  ClassAnalysisError(:final message) => _buildErrorState(message, theme, spacing),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorHeader(
    MyClassesState classesState,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    if (classesState is! MyClassesSuccess && classesState is! MyClassesRefreshing) {
      return const SizedBox.shrink();
    }

    final groups = classesState is MyClassesSuccess 
        ? classesState.classes 
        : (classesState as MyClassesRefreshing).classes;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class & Section Dropdown
          DropdownButtonFormField<TeacherClassGroupEntity>(
            value: _selectedClassGroup,
            decoration: const InputDecoration(
              labelText: 'Select Class & Section',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: groups.map((g) {
              return DropdownMenuItem(
                value: g,
                child: Text('${g.className} - ${g.sectionName}'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedClassGroup = val;
                _selectedSubject = null; // reset subject
              });
            },
          ),
          SizedBox(height: spacing.sm),

          // Subject Dropdown (depends on selected Class Group)
          DropdownButtonFormField<TeacherSubjectAssignmentEntity>(
            value: _selectedSubject,
            decoration: const InputDecoration(
              labelText: 'Select Subject',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _selectedClassGroup?.assignments.map((a) {
              return DropdownMenuItem(
                value: a,
                child: Text(a.subjectName),
              );
            }).toList() ?? [],
            onChanged: _selectedClassGroup == null ? null : (val) {
              setState(() {
                _selectedSubject = val;
              });
            },
          ),
          SizedBox(height: spacing.md),

          // Generate Button
          ElevatedButton.icon(
            onPressed: (_selectedClassGroup == null || _selectedSubject == null)
                ? null
                : () {
                    ref.read(classAnalysisNotifierProvider.notifier).fetchClassAnalysis(
                          classId: _selectedClassGroup!.classId,
                          sectionId: _selectedClassGroup!.sectionId,
                          subjectId: _selectedSubject!.subjectId,
                        );
                  },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate Class Performance Analysis'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            SizedBox(height: spacing.md),
            Text(
              'No Class Analysis Loaded',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Text(
                'Select a class/section and subject above to generate an AI-powered performance report, grade breakdown, and recommendations.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: spacing.md),
            Text(
              'Retrieving grade distribution and calculating class metrics...',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
            SizedBox(height: spacing.md),
            Text(
              'Failed to Generate Report',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent(
    ClassAnalysisDto analysis,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Header
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Text(
                'Analysis for ${_selectedClassGroup?.className} - ${_selectedClassGroup?.sectionName} (${_selectedSubject?.subjectName})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.md),

        // Key Metrics Cards Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Class Average',
                value: '${analysis.classAverage.toStringAsFixed(1)}%',
                icon: Icons.functions_rounded,
                color: theme.colorScheme.primary,
                theme: theme,
                spacing: spacing,
                radius: radius,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _buildMetricCard(
                label: 'Pass Percentage',
                value: '${analysis.passPercentage.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green,
                theme: theme,
                spacing: spacing,
                radius: radius,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),

        // Trend Card
        Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: theme.colorScheme.secondaryContainer, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.trending_up_rounded, color: theme.colorScheme.secondary, size: 24),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Trend',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.xs / 2),
                    Text(
                      analysis.improvementTrend,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.md),

        // Grade Distribution Chart Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grade Distribution',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.md),
                ...analysis.gradeDistribution.entries.map((entry) => Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(radius.xs),
                              child: LinearProgressIndicator(
                                value: entry.value / 40.0, // Assuming max students 40
                                backgroundColor: theme.colorScheme.outlineVariant,
                                color: theme.colorScheme.primary,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          SizedBox(width: spacing.sm),
                          Text(
                            '${entry.value} students',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // Improving / Declining Students Cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildStudentListCard(
                title: 'Improving Progress',
                students: analysis.studentsImproving,
                icon: Icons.thumb_up_alt_outlined,
                color: Colors.green,
                theme: theme,
                spacing: spacing,
                radius: radius,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _buildStudentListCard(
                title: 'Needs Attention',
                students: analysis.studentsDeclining,
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
                theme: theme,
                spacing: spacing,
                radius: radius,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.md),

        // Strong vs reinforcement areas
        _buildAreasCard(
          title: 'Strong Areas (Concept Mastery)',
          areas: analysis.strongAreas,
          icon: Icons.star_border_rounded,
          color: Colors.orange,
          theme: theme,
          spacing: spacing,
          radius: radius,
        ),
        SizedBox(height: spacing.sm),
        _buildAreasCard(
          title: 'Needs Reinforcement / Revision',
          areas: analysis.needsReinforcementAreas,
          icon: Icons.refresh_rounded,
          color: Colors.indigo,
          theme: theme,
          spacing: spacing,
          radius: radius,
        ),
        SizedBox(height: spacing.md),

        // Action plan recommendations
        Card(
          elevation: 0,
          color: Colors.teal[50]?.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(color: Colors.teal.withOpacity(0.3), width: 1.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Suggested Pedagogical Interventions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                SizedBox(height: spacing.md),
                ...analysis.suggestedActions.asMap().entries.map((entry) => Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.key + 1}. ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.teal[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required AppSpacing spacing,
    required AppRadius radius,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: spacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListCard({
    required String title,
    required List<String> students,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required AppSpacing spacing,
    required AppRadius radius,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            if (students.isEmpty)
              Text(
                'None identified.',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              )
            else
              ...students.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '• $s',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildAreasCard({
    required String title,
    required List<String> areas,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required AppSpacing spacing,
    required AppRadius radius,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                SizedBox(width: spacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            if (areas.isEmpty)
              Text(
                'No specific topics reported.',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              )
            else
              ...areas.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '• $a',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
