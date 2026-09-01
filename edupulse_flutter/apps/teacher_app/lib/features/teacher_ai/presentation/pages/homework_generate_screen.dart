import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';
import '../providers/teacher_ai_provider.dart';
import '../../../../core/router/routes.dart';

class HomeworkGenerateScreen extends ConsumerStatefulWidget {
  const HomeworkGenerateScreen({super.key});

  @override
  ConsumerState<HomeworkGenerateScreen> createState() => _HomeworkGenerateScreenState();
}

class _HomeworkGenerateScreenState extends ConsumerState<HomeworkGenerateScreen> {
  TeacherClassGroupEntity? _selectedClassGroup;
  TeacherSubjectAssignmentEntity? _selectedSubject;
  
  final _topicController = TextEditingController();
  final _marksController = TextEditingController(text: '20');
  
  String _selectedDifficulty = 'MEDIUM';
  int _numberOfQuestions = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
      ref.read(homeworkGenerationNotifierProvider.notifier).clearHomework();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final classesState = ref.watch(myClassesStateProvider);
    final genState = ref.watch(homeworkGenerationNotifierProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('AI Homework Generator'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Configurations Form
            _buildConfigForm(classesState, theme, spacing, radius),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.md),
                child: switch (genState) {
                  HomeworkGenerationInitial() => _buildInitialState(theme, spacing),
                  HomeworkGenerationLoading() => _buildLoadingState(theme, spacing),
                  HomeworkGenerationSuccess(:final homework) => _buildHomeworkContent(homework, theme, spacing, radius),
                  HomeworkGenerationError(:final message) => _buildErrorState(message, theme, spacing),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm(
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
          // Row 1: Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TeacherClassGroupEntity>(
                  value: _selectedClassGroup,
                  decoration: const InputDecoration(
                    labelText: 'Class & Section',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      _selectedSubject = null;
                    });
                  },
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: DropdownButtonFormField<TeacherSubjectAssignmentEntity>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              ),
            ],
          ),
          SizedBox(height: spacing.sm),

          // Row 2: Topic & Marks
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _topicController,
                  onChanged: (val) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Topic / Syllabus Area',
                    hintText: 'e.g. Gravity and Motion',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _marksController,
                  onChanged: (val) => setState(() {}),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Marks',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),

          // Row 3: Difficulty & Questions count
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: ['EASY', 'MEDIUM', 'HARD', 'MIXED'].map((diff) {
                    return DropdownMenuItem(
                      value: diff,
                      child: Text(diff),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDifficulty = val ?? 'MEDIUM';
                    });
                  },
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _numberOfQuestions,
                  decoration: const InputDecoration(
                    labelText: 'Questions Count',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [3, 5, 10, 15].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count Questions'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _numberOfQuestions = val ?? 5;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),

          // Generate Button
          ElevatedButton.icon(
            onPressed: (_selectedClassGroup == null || 
                        _selectedSubject == null || 
                        _topicController.text.trim().isEmpty ||
                        _marksController.text.trim().isEmpty)
                ? null
                : () {
                    final marks = int.tryParse(_marksController.text.trim()) ?? 20;
                    ref.read(homeworkGenerationNotifierProvider.notifier).generateHomework(
                          classId: _selectedClassGroup!.classId,
                          sectionId: _selectedClassGroup!.sectionId,
                          subjectId: _selectedSubject!.subjectId,
                          topic: _topicController.text.trim(),
                          difficulty: _selectedDifficulty,
                          numberOfQuestions: _numberOfQuestions,
                          marks: marks,
                        );
                  },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate Homework Template Draft'),
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
              Icons.menu_book_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            SizedBox(height: spacing.md),
            Text(
              'No Homework Draft Generated',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Text(
                'Configure the parameters above to request a custom curriculum-aligned homework assignment outline with suggested questions and difficulty mappings.',
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
              'Generating questions, answers and instructions...',
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
              'Failed to Generate Homework',
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

  Widget _buildHomeworkContent(
    dynamic homework,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI Success Banner
        Container(
          padding: EdgeInsets.all(spacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(radius.sm),
            border: Border.all(color: theme.colorScheme.primaryContainer),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Homework Draft generated successfully!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.md),

        // Homework Card Details
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
                  homework.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                _buildMetadataRow('Learning Objective', homework.learningObjective, theme, spacing),
                _buildMetadataRow('Estimated Duration', '${homework.estimatedMinutes} minutes', theme, spacing),
                _buildMetadataRow('Difficulty Level', homework.difficulty, theme, spacing),
                SizedBox(height: spacing.sm),
                const Divider(),
                SizedBox(height: spacing.sm),
                Text(
                  'Instructions / Description:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  homework.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // Questions Title
        Text(
          'Generated Questions (${homework.questions.length})',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: spacing.sm),

        // List of questions
        ...homework.questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return Card(
            elevation: 0,
            margin: EdgeInsets.only(bottom: spacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.sm),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${idx + 1}. ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          q.text,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(radius.xs),
                        ),
                        child: Text(
                          '${q.marks}M',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (q.choices != null && q.choices!.isNotEmpty) ...[
                    SizedBox(height: spacing.sm),
                    ...q.choices!.asMap().entries.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                          child: Text('${String.fromCharCode(97 + (c.key as int))}) ${c.value}'),
                        )),
                  ],
                  if (q.answerKey != null && q.answerKey!.isNotEmpty) ...[
                    SizedBox(height: spacing.sm),
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: Text(
                            'Answer Key: ${q.answerKey}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        SizedBox(height: spacing.lg),

        // Action Load Button
        ElevatedButton.icon(
          onPressed: () {
            // Build full formatted description with questions to pass to create screen
            final qStrings = homework.questions.asMap().entries.map((qEntry) {
              final idx = qEntry.key + 1;
              final question = qEntry.value;
              String str = '$idx. ${question.text} (${question.marks} Marks)';
              if (question.choices != null && question.choices!.isNotEmpty) {
                str += '\n' + question.choices!.asMap().entries.map((cEntry) => '    ${String.fromCharCode(97 + (cEntry.key as int))}) ${cEntry.value}').join('\n');
              }
              if (question.answerKey != null && question.answerKey!.isNotEmpty) {
                str += '\n    (Answer Key: ${question.answerKey})';
              }
              return str;
            }).join('\n\n');

            final formattedDescription = '${homework.description}\n\n'
                'Learning Objective: ${homework.learningObjective}\n\n'
                'Questions:\n$qStrings';

            // Find tsaId matching selected subject & class group
            final matchingAssignment = _selectedClassGroup?.assignments.firstWhere(
              (a) => a.subjectId == _selectedSubject!.subjectId,
            );
            
            // Navigate to homework creation form prefilled with AI draft details
            context.push(
              '${AppRoutes.homeworkCreate}?'
              'classId=${_selectedClassGroup!.classId}&'
              'sectionId=${_selectedClassGroup!.sectionId}&'
              'subjectId=${_selectedSubject!.subjectId}&'
              'tsaId=${matchingAssignment?.id ?? ""}&'
              'initialTitle=${Uri.encodeComponent(homework.title)}&'
              'initialDescription=${Uri.encodeComponent(formattedDescription)}&'
              'initialEstimatedMinutes=${homework.estimatedMinutes}',
            );
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review and Publish Homework'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value, ThemeData theme, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
