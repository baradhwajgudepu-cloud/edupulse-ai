import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/examination_entity.dart';
import '../../domain/entities/exam_schedule_entity.dart';
import '../providers/marks_providers.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/router/routes.dart';

class MarksSelectScreen extends ConsumerStatefulWidget {
  const MarksSelectScreen({super.key});

  @override
  ConsumerState<MarksSelectScreen> createState() => _MarksSelectScreenState();
}

class _MarksSelectScreenState extends ConsumerState<MarksSelectScreen> {
  TeacherClassGroupEntity? _selectedClassGroup;
  TeacherSubjectAssignmentEntity? _selectedAssignment;
  ExaminationEntity? _selectedExam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final myClassesState = ref.watch(myClassesStateProvider);
    final dashboardState = ref.watch(dashboardStateProvider);
    final authState = ref.watch(authStateProvider);

    String? academicYearId;
    final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull : null;
    if (dashboardState is DashboardSuccess) {
      academicYearId = dashboardState.data.academicYear.id;
    } else if (dashboardState is DashboardRefreshing) {
      academicYearId = dashboardState.data.academicYear.id;
    }

    final examsAsync = ref.watch(marksExaminationsProvider(academicYearId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Class & Assessment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing.md),

              // Class Dropdown
              _buildClassDropdown(myClassesState, theme, spacing, radius),
              SizedBox(height: spacing.md),

              // Subject Dropdown
              if (_selectedClassGroup != null) ...[
                _buildSubjectDropdown(theme, spacing, radius),
                SizedBox(height: spacing.md),
              ],

              // Examination Dropdown
              _buildExaminationDropdown(examsAsync, theme, spacing, radius),
              SizedBox(height: spacing.lg),

              // Schedules List
              if (_selectedClassGroup != null && _selectedExam != null && _selectedAssignment != null) ...[
                Text(
                  'Available Exam Schedules',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: spacing.sm),
                _buildSchedulesList(_selectedExam!, _selectedClassGroup!, _selectedAssignment!, theme, spacing, radius),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassDropdown(
    MyClassesState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    List<TeacherClassGroupEntity> classes = [];
    if (state is MyClassesSuccess) {
      classes = state.classes;
    } else if (state is MyClassesRefreshing) {
      classes = state.classes;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class & Section', style: theme.textTheme.labelMedium),
        SizedBox(height: spacing.xs),
        DropdownButtonFormField<TeacherClassGroupEntity>(
          value: _selectedClassGroup,
          hint: const Text('Choose class & section'),
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.sm),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: spacing.md),
          ),
          items: classes.map((c) {
            return DropdownMenuItem<TeacherClassGroupEntity>(
              value: c,
              child: Text('${c.className} - ${c.sectionName}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedClassGroup = value;
              _selectedAssignment = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final assignments = _selectedClassGroup!.assignments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject', style: theme.textTheme.labelMedium),
        SizedBox(height: spacing.xs),
        DropdownButtonFormField<TeacherSubjectAssignmentEntity>(
          value: _selectedAssignment,
          hint: const Text('Choose subject'),
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.sm),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: spacing.md),
          ),
          items: assignments.map((a) {
            return DropdownMenuItem<TeacherSubjectAssignmentEntity>(
              value: a,
              child: Text(a.subjectName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedAssignment = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildExaminationDropdown(
    AsyncValue<List<ExaminationEntity>> examsAsync,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return examsAsync.when(
      data: (exams) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Examination', style: theme.textTheme.labelMedium),
            SizedBox(height: spacing.xs),
            DropdownButtonFormField<ExaminationEntity>(
              value: _selectedExam,
              hint: const Text('Choose examination'),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: spacing.md),
              ),
              items: exams.map((e) {
                return DropdownMenuItem<ExaminationEntity>(
                  value: e,
                  child: Text(e.examName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedExam = value;
                });
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading exams: $err', style: TextStyle(color: theme.colorScheme.error)),
    );
  }

  Widget _buildSchedulesList(
    ExaminationEntity exam,
    TeacherClassGroupEntity group,
    TeacherSubjectAssignmentEntity assignment,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final authState = ref.watch(authStateProvider);
    final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull : '';

    return FutureBuilder<ApiResult<ExaminationEntity>>(
      future: ref.read(marksRepositoryProvider).getExaminationById(id: exam.id, schoolId: schoolId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text('Error fetching exam schedules.', style: TextStyle(color: theme.colorScheme.error));
        }

        final result = snapshot.data!;
        return result.when(
          onSuccess: (detailedExam) {
            return _buildFilteredSchedulesView(detailedExam, group, assignment, theme, spacing, radius);
          },
          onFailure: (failure) {
            return Text('Failed to load schedules: ${failure.message}', style: TextStyle(color: theme.colorScheme.error));
          },
        );
      },
    );
  }

  Widget _buildFilteredSchedulesView(
    ExaminationEntity detailedExam,
    TeacherClassGroupEntity group,
    TeacherSubjectAssignmentEntity assignment,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final filtered = detailedExam.schedules.where((s) {
      return s.classId == group.classId &&
          s.sectionId == group.sectionId &&
          s.subjectId == assignment.subjectId;
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.lg),
        child: const Center(
          child: Text('No exam schedules configured for this class and subject.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final schedule = filtered[index];

        // Security check: teacher must not enter for mismatching TSA
        final isAuthorized = schedule.teacherSubjectAssignmentId == assignment.id;

        return Card(
          margin: EdgeInsets.only(bottom: spacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.sm),
            side: BorderSide(
              color: isAuthorized ? theme.colorScheme.outlineVariant : theme.colorScheme.error.withOpacity(0.5),
            ),
          ),
          child: ListTile(
            title: Text(
              '${group.className} - ${assignment.subjectName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Date: ${schedule.examDate.toLocal().toString().split(' ')[0]}'),
                Text('Time: ${schedule.startTime} - ${schedule.endTime}'),
                Text('Max Marks: ${schedule.maxMarks}  |  Pass Marks: ${schedule.passMarks}'),
                if (schedule.roomNumber != null) Text('Room: ${schedule.roomNumber}'),
                if (!isAuthorized) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
                      const SizedBox(width: 4),
                      Text(
                        'Assignment mismatch: Unauthorized schedule.',
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: isAuthorized ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
            onTap: isAuthorized
                ? () {
                    context.push(
                      '${AppRoutes.marksEntry}?examScheduleId=${schedule.id}&examName=${Uri.encodeComponent(detailedExam.examName)}&subjectName=${Uri.encodeComponent(assignment.subjectName)}&className=${Uri.encodeComponent('${group.className} - ${group.sectionName}')}&maxMarks=${schedule.maxMarks}&passMarks=${schedule.passMarks}&teacherSubjectAssignmentId=${schedule.teacherSubjectAssignmentId}',
                    );
                  }
                : null,
          ),
        );
      },
    );
  }
}
