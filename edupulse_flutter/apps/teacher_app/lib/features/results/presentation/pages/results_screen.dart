import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

import '../../domain/entities/result_summary_entity.dart';
import '../../domain/entities/report_card_entity.dart';
import '../../domain/entities/bulk_class_generate_entity.dart';
import '../providers/results_providers.dart';
import '../../../marks/domain/entities/examination_entity.dart';
import '../../../marks/domain/entities/exam_schedule_entity.dart';
import '../../../marks/presentation/providers/marks_providers.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';
import '../../../my_classes/domain/entities/student.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/result_summary_card.dart';
import '../widgets/result_status_badge.dart';
import '../../../../core/router/routes.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tab 1 state
  ExaminationEntity? _selectedExamTab1;
  ExamScheduleEntity? _selectedScheduleTab1;

  // Tab 2 state
  TeacherClassGroupEntity? _selectedClassGroup;
  TeacherSubjectAssignmentEntity? _selectedAssignment;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text('Results & Report Cards'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Exam Statistics', icon: Icon(Icons.analytics_rounded)),
            Tab(text: 'Report Cards', icon: Icon(Icons.assignment_turned_in_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExamStatisticsTab(examsAsync, theme, spacing, radius),
          _buildReportCardsTab(myClassesState, schoolId, theme, spacing, radius),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1 — EXAM STATISTICS TAB
  // ==========================================
  Widget _buildExamStatisticsTab(
    AsyncValue<List<ExaminationEntity>> examsAsync,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return examsAsync.when(
      data: (exams) {
        if (exams.isEmpty) {
          return Center(
            child: Text(
              'No examinations scheduled.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(spacing.md),
          children: [
            DropdownButtonFormField<ExaminationEntity>(
              value: _selectedExamTab1,
              decoration: const InputDecoration(
                labelText: 'Select Examination',
                prefixIcon: Icon(Icons.assignment_rounded),
              ),
              items: exams.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e.examName),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedExamTab1 = val;
                  _selectedScheduleTab1 = null;
                });
              },
            ),
            SizedBox(height: spacing.md),
            if (_selectedExamTab1 != null) ...[
              DropdownButtonFormField<ExamScheduleEntity>(
                value: _selectedScheduleTab1,
                decoration: const InputDecoration(
                  labelText: 'Select Paper / Subject Slot',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
                items: _selectedExamTab1!.schedules.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text('${s.subjectId} - Grade ${s.classId}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedScheduleTab1 = val;
                  });
                },
              ),
              SizedBox(height: spacing.lg),
            ],
            if (_selectedScheduleTab1 != null)
              Consumer(
                builder: (context, ref, child) {
                  final summaryAsync = ref.watch(resultsSummaryProvider(_selectedScheduleTab1!.id));
                  return summaryAsync.when(
                    data: (summary) => ResultSummaryCard(summary: summary),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error loading stats: $err', style: TextStyle(color: theme.colorScheme.error)),
                  );
                },
              )
            else if (_selectedExamTab1 != null)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(spacing.xl),
                  child: Text(
                    'Please select a subject slot to view statistics.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: EdgeInsets.all(spacing.xl),
                  child: Text(
                    'Select an examination to begin.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
    );
  }

  // ==========================================
  // TAB 2 — REPORT CARDS LIFECYCLE TAB
  // ==========================================
  Widget _buildReportCardsTab(
    MyClassesState myClassesState,
    String? schoolId,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    if (myClassesState is MyClassesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myClassesState is MyClassesError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load classes: ${myClassesState.message}', style: TextStyle(color: theme.colorScheme.error)),
            SizedBox(height: spacing.md),
            ElevatedButton(
              onPressed: () => ref.read(myClassesStateProvider.notifier).fetchClasses(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final groups = <TeacherClassGroupEntity>[];
    if (myClassesState is MyClassesSuccess) {
      groups.addAll(myClassesState.classes);
    } else if (myClassesState is MyClassesRefreshing) {
      groups.addAll(myClassesState.classes);
    }

    if (groups.isEmpty) {
      return Center(
        child: Text('No assigned class groups found.', style: theme.textTheme.bodyMedium),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<TeacherClassGroupEntity>(
                value: _selectedClassGroup,
                decoration: const InputDecoration(
                  labelText: 'Select Class',
                  prefixIcon: Icon(Icons.school_rounded),
                ),
                items: groups.map((g) {
                  return DropdownMenuItem(
                    value: g,
                    child: Text('${g.className} - Section ${g.sectionName}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedClassGroup = val;
                    _selectedAssignment = null;
                  });
                  if (val != null) {
                    ref.read(studentRosterStateProvider("${val.classId}:${val.sectionId}").notifier).fetchStudents();
                  }
                },
              ),
              SizedBox(height: spacing.sm),
              if (_selectedClassGroup != null) ...[
                DropdownButtonFormField<TeacherSubjectAssignmentEntity>(
                  value: _selectedAssignment,
                  decoration: const InputDecoration(
                    labelText: 'Select Subject Assignment',
                    prefixIcon: Icon(Icons.subject_rounded),
                  ),
                  items: _selectedClassGroup!.assignments.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a.subjectName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAssignment = val;
                    });
                  },
                ),
                SizedBox(height: spacing.sm),
              ],
            ],
          ),
        ),
        if (_selectedAssignment != null)
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final classId = _selectedClassGroup!.classId;
                final sectionId = _selectedClassGroup!.sectionId;
                
                final cardsAsync = ref.watch(reportCardsProvider((classId: classId, sectionId: sectionId)));
                final rosterState = ref.watch(studentRosterStateProvider("$classId:$sectionId"));

                if (rosterState is StudentRosterLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (rosterState is StudentRosterError) {
                  return Center(
                    child: Text('Error loading students: ${rosterState.message}', style: TextStyle(color: theme.colorScheme.error)),
                  );
                }

                final studentsList = <StudentEntity>[];
                if (rosterState is StudentRosterSuccess) {
                  studentsList.addAll(rosterState.allStudents);
                } else if (rosterState is StudentRosterRefreshing) {
                  studentsList.addAll(rosterState.allStudents);
                }

                if (studentsList.isEmpty) {
                  return const Center(child: Text('No students found in this roster.'));
                }

                return cardsAsync.when(
                  data: (cards) {
                    final filteredStudents = studentsList.where((st) {
                      final fullName = st.fullName.toLowerCase();
                      final roll = st.rollNumber.toLowerCase();
                      final admission = st.admissionNumber.toLowerCase();
                      return fullName.contains(_searchQuery.toLowerCase()) ||
                          roll.contains(_searchQuery.toLowerCase()) ||
                          admission.contains(_searchQuery.toLowerCase());
                    }).toList();

                    return Column(
                      children: [
                        // Roster actions & search bar
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search roster...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              ElevatedButton.icon(
                                onPressed: () => _handleBulkGenerate(classId, sectionId, schoolId ?? ''),
                                icon: const Icon(Icons.flash_on_rounded),
                                label: const Text('Bulk Generate'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing.md),
                        Expanded(
                          child: filteredStudents.isEmpty
                              ? const Center(child: Text('No matching students.'))
                              : ListView.separated(
                                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                                  itemCount: filteredStudents.length,
                                  separatorBuilder: (context, index) => SizedBox(height: spacing.xs),
                                  itemBuilder: (context, index) {
                                    final st = filteredStudents[index];
                                    
                                    // Match with report card record if exists
                                    final match = cards.firstWhere(
                                      (c) => c.studentId == st.id,
                                      orElse: () => ReportCardEntity(
                                        id: '',
                                        verificationUuid: '',
                                        status: ReportCardStatus.DRAFT,
                                        pdfHistory: const [],
                                        settings: const {},
                                        aiMetrics: const {},
                                        isActive: false,
                                        version: 0,
                                        tenantId: '',
                                        schoolId: '',
                                        academicYearId: '',
                                        studentId: '',
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      ),
                                    );

                                    final hasReportCard = match.id.isNotEmpty;

                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(radius.sm),
                                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                                      ),
                                      child: ListTile(
                                        onTap: () {
                                          context.push(
                                            '${AppRoutes.studentResult}?studentId=${st.id}&classId=$classId&sectionId=$sectionId',
                                          );
                                        },
                                        leading: CircleAvatar(
                                          child: Text(st.rollNumber),
                                        ),
                                        title: Text(st.fullName),
                                        subtitle: Text('Adm No: ${st.admissionNumber}'),
                                        trailing: hasReportCard
                                            ? ResultStatusBadge(status: match.status.name)
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'NOT GENERATED',
                                                  style: theme.textTheme.labelMedium?.copyWith(
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error loading report cards: $err', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                );
              },
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Please select class and subject assignment.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleBulkGenerate(String classId, String sectionId, String schoolId) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Generate Report Cards?'),
          content: const Text(
            'This will compile live grade results and generate PDF draft report cards for all active students in this class.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ref.read(bulkClassGenerateProvider.notifier).runBulkGenerate(
            classId: classId,
            sectionId: sectionId,
            schoolId: schoolId,
          );

      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        
        final state = ref.read(bulkClassGenerateProvider);
        state.when(
          data: (data) {
            if (data == null) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Bulk Generation Complete'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Roster Students: ${data.totalStudents}'),
                    Text('Successfully Generated: ${data.generatedCount}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('Failed / Incomplete: ${data.failedCount}', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                    if (data.failures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Failed Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 120,
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: data.failures.length,
                          itemBuilder: (context, index) {
                            final fail = data.failures[index];
                            return Text('• ${fail.studentName}: ${fail.reasons.join(", ")}', style: const TextStyle(fontSize: 12));
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.invalidate(reportCardsProvider((classId: classId, sectionId: sectionId)));
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          error: (err, stack) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $err'), backgroundColor: theme.colorScheme.error),
            );
          },
          loading: () {},
        );
      }
    }
  }
}
