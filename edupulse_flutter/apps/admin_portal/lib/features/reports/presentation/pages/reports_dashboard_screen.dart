import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/reports_provider.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../results/presentation/providers/results_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends ConsumerState<ReportsDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _academicSearchController = TextEditingController();
  String _academicSearchQuery = '';
  int _academicCurrentPage = 1;
  static const int _academicRowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _refreshAll();
  }

  void _handleTabSelection() {
    if (_tabController.index != 1) {
      ref.read(reportsFiltersProvider.notifier).updateGrade(null);
      setState(() {
        _academicSearchQuery = '';
        _academicSearchController.clear();
        _academicCurrentPage = 1;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _academicSearchController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears().then((_) {
          final currentAyId = ref.read(selectedAcademicYearIdProvider);
          if (currentAyId != null && ref.read(reportsFiltersProvider).academicYearId == null) {
            ref.read(reportsFiltersProvider.notifier).updateAcademicYear(currentAyId);
          }
        });
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        // Load default lists
        _invalidateReports();
      }
    });
  }

  void _invalidateReports() {
    ref.invalidate(reportsDashboardProvider);
    ref.invalidate(reportsAcademicProvider);
    ref.invalidate(reportsExaminationsProvider);
    ref.invalidate(reportsAttendanceProvider);
    ref.invalidate(reportsFeesProvider);
    ref.invalidate(reportsAIIntelligenceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final filters = ref.watch(reportsFiltersProvider);
    
    final authState = ref.watch(authStateProvider);
    bool isTenantScopedAdmin = false;
    if (authState is Authenticated) {
      isTenantScopedAdmin = authState.user.isSuperuser || 
          authState.user.roles.any((r) => 
              r.toUpperCase() == 'SUPER_ADMIN' || 
              r.toUpperCase() == 'TENANT_ADMIN' || 
              r.toUpperCase() == 'CHAIRMAN');
    }

    // Listen for school change to reset filters and refresh setup lists
    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      ref.read(reportsFiltersProvider.notifier).reset();
      if (next != null) {
        ref.read(academicYearsProvider(next).notifier).fetchYears().then((_) {
          final currentAyId = ref.read(selectedAcademicYearIdProvider);
          if (currentAyId != null) {
            ref.read(reportsFiltersProvider.notifier).updateAcademicYear(currentAyId);
          }
        });
        ref.read(classesProvider(next).notifier).fetchClasses();
      }
      _invalidateReports();
    });

    if (schoolId == null && !isTenantScopedAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics & Reports')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please select a school context first to view reports.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final ayYears = schoolId != null ? ref.watch(academicYearsProvider(schoolId)).years : const [];
    final classes = schoolId != null ? ref.watch(classesProvider(schoolId)).classes : const [];
    
    // Fetch sections if class is selected
    List<dynamic> sections = [];
    if (schoolId != null && filters.classId != null) {
      final secState = ref.watch(sectionsProvider(schoolId));
      // Auto-trigger sections fetch if list is empty and class changes
      Future.microtask(() {
        if (secState.sections.isEmpty && !secState.isLoading) {
          ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        }
      });
      sections = secState.sections.where((s) => s.classId == filters.classId).toList();
    }

    // Load subjects for academic filtering
    if (schoolId != null) {
      final subjectState = ref.watch(subjectsProvider(schoolId));
      Future.microtask(() {
        if (subjectState.subjects.isEmpty && !subjectState.isLoading) {
          ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
        }
      });
    }
    final subjects = schoolId != null ? ref.watch(subjectsProvider(schoolId)).subjects : const [];

    // Load examinations
    final examsAsync = schoolId != null ? ref.watch(resultsExaminationsProvider) : const AsyncValue<List<dynamic>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _invalidateReports();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report metrics updated.')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Semantics(
              label: 'Reports Overview',
              container: true,
              child: Tooltip(
                message: 'Reports Overview',
                child: Tab(
                  key: const Key('reports_tab_overview'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dashboard),
                      SizedBox(width: 8),
                      Text('Overview'),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Academic Performance',
              container: true,
              child: Tooltip(
                message: 'Academic Performance',
                child: Tab(
                  key: const Key('reports_tab_academic'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school),
                      SizedBox(width: 8),
                      Text('Academic Performance'),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Attendance Records',
              container: true,
              child: Tooltip(
                message: 'Attendance Records',
                child: Tab(
                  key: const Key('reports_tab_attendance'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month),
                      SizedBox(width: 8),
                      Text('Attendance Records'),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Fees and Finance',
              container: true,
              child: Tooltip(
                message: 'Fees and Finance',
                child: Tab(
                  key: const Key('reports_tab_fees'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments),
                      SizedBox(width: 8),
                      Text('Fees & Finance'),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'AI Predictive Insights',
              container: true,
              child: Tooltip(
                message: 'AI Predictive Insights',
                child: Tab(
                  key: const Key('reports_tab_ai'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology),
                      SizedBox(width: 8),
                      Text('AI Predictive Insights'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Panel Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            child: Wrap(
              spacing: spacing.md,
              runSpacing: spacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (schoolId != null) ...[
                  // Academic Year Filter
                  DropdownButton<String>(
                    value: filters.academicYearId,
                    hint: const Text('All Academic Years'),
                    onChanged: (val) {
                      ref.read(reportsFiltersProvider.notifier).updateAcademicYear(val);
                      _invalidateReports();
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Academic Years'),
                      ),
                      ...ayYears.map((ay) => DropdownMenuItem<String>(
                        value: ay.id,
                        child: Text(ay.name),
                      )),
                    ],
                  ),
                  // Class Filter
                  DropdownButton<String>(
                    value: filters.classId,
                    hint: const Text('All Classes'),
                    onChanged: (val) {
                      ref.read(reportsFiltersProvider.notifier).updateClass(val);
                      _invalidateReports();
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Classes'),
                      ),
                      ...classes.map((cls) => DropdownMenuItem<String>(
                        value: cls.id,
                        child: Text(cls.name),
                      )),
                    ],
                  ),
                  // Section Filter
                  if (filters.classId != null)
                    DropdownButton<String>(
                      value: filters.sectionId,
                      hint: const Text('All Sections'),
                      onChanged: (val) {
                        ref.read(reportsFiltersProvider.notifier).updateSection(val);
                        _invalidateReports();
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Sections'),
                        ),
                        ...sections.map((sec) => DropdownMenuItem<String>(
                          value: sec.id,
                          child: Text(sec.name),
                        )),
                      ],
                    ),
                  // Subject Filter (Only shown on Academic Tab)
                  if (_tabController.index == 1)
                    DropdownButton<String>(
                      value: filters.subjectId,
                      hint: const Text('All Subjects'),
                      onChanged: (val) {
                        ref.read(reportsFiltersProvider.notifier).updateSubject(val);
                        _invalidateReports();
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Subjects'),
                        ),
                        ...subjects.map((sub) => DropdownMenuItem<String>(
                          value: sub.id,
                          child: Text(sub.subjectName),
                        )),
                      ],
                    ),
                  // Exam Filter (Only shown on Academic Tab)
                  if (_tabController.index == 1)
                    examsAsync.when(
                      data: (exams) => DropdownButton<String>(
                        value: filters.examinationId,
                        hint: const Text('All Examinations'),
                        onChanged: (val) {
                          ref.read(reportsFiltersProvider.notifier).updateExam(val);
                          _invalidateReports();
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Examinations'),
                          ),
                          ...exams.map((ex) => DropdownMenuItem<String>(
                            value: ex.id,
                            child: Text(ex.examName),
                          )),
                        ],
                      ),
                      loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, __) => const Text('Error loading exams'),
                    ),
                ] else ...[
                  const Text('Filters are school-specific. Select a school context to enable filters.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
                // Clear Filters Button
                TextButton.icon(
                  onPressed: () {
                    ref.read(reportsFiltersProvider.notifier).reset();
                    _invalidateReports();
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(spacing, radius, theme),
                _buildAcademicTab(spacing, radius, theme),
                _buildAttendanceTab(spacing, radius, theme),
                _buildFeesTab(spacing, radius, theme),
                _buildAITab(spacing, radius, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- OVERVIEW TAB ---
  Widget _buildOverviewTab(AppSpacing spacing, AppRadius radius, ThemeData theme) {
    final dashboardAsync = ref.watch(reportsDashboardProvider);
    final filters = ref.watch(reportsFiltersProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final isTenantContext = schoolId == null;

    return dashboardAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(child: Text('No overview metrics available.'));
        }

        final String studentsTitle;
        final String teachersTitle;
        final String classesTitle;
        final String sectionsTitle;
        final String academicTitle;
        final String attendanceTitle;
        final String feeTitle;
        final String riskTitle;

        if (isTenantContext) {
          studentsTitle = 'Total Students (Group)';
          teachersTitle = 'Total Teachers (Group)';
          classesTitle = 'Total Schools';
          sectionsTitle = 'Academic Calendar';
          academicTitle = 'Report Card Progress';
          attendanceTitle = 'Group Attendance Rate';
          feeTitle = 'Group Fee Collection';
          riskTitle = 'Group Risk Alerts';
        } else if (filters.sectionId != null) {
          studentsTitle = 'Students in Section';
          teachersTitle = 'School-wide Active Teachers';
          classesTitle = 'School-wide Classes';
          sectionsTitle = 'Sections in Class';
          academicTitle = 'Academic Avg (Section)';
          attendanceTitle = 'Attendance Rate (Section)';
          feeTitle = 'Fee Collection (Section)';
          riskTitle = 'Risk Alerts (Section)';
        } else if (filters.classId != null) {
          studentsTitle = 'Students in Class';
          teachersTitle = 'School-wide Active Teachers';
          classesTitle = 'School-wide Classes';
          sectionsTitle = 'Sections in Class';
          academicTitle = 'Academic Avg (Class)';
          attendanceTitle = 'Attendance Rate (Class)';
          feeTitle = 'Fee Collection (Class)';
          riskTitle = 'Risk Alerts (Class)';
        } else {
          studentsTitle = 'Total Students (School)';
          teachersTitle = 'Active Teachers (School)';
          classesTitle = 'Total Classes (School)';
          sectionsTitle = 'Total Sections (School)';
          academicTitle = 'Academic Avg (School)';
          attendanceTitle = 'Attendance Rate (School)';
          feeTitle = 'Fee Collection (School)';
          riskTitle = 'Risk Alerts (School)';
        }

        final cards = [
          _OverviewCard(
            title: studentsTitle,
            value: '${data['total_students'] ?? 0}',
            icon: Icons.people,
            color: Colors.blue,
            onTap: isTenantContext ? null : () => _showStudentsDialog(context, filters),
          ),
          _OverviewCard(
            title: teachersTitle,
            value: '${data['active_teachers'] ?? data['total_teachers'] ?? 0}',
            icon: Icons.co_present,
            color: Colors.green,
            onTap: isTenantContext ? null : () => _showTeachersDialog(context, filters),
          ),
          _OverviewCard(
            title: classesTitle,
            value: isTenantContext ? '${data['total_schools'] ?? 0} Schools' : '${data['total_classes'] ?? 0} Classes',
            icon: isTenantContext ? Icons.business : Icons.school,
            color: Colors.teal,
            onTap: isTenantContext ? null : () => _showClassesDialog(context, filters),
          ),
          _OverviewCard(
            title: sectionsTitle,
            value: isTenantContext ? '${data['active_academic_year'] ?? "N/A"}' : '${data['total_sections'] ?? 0}',
            icon: isTenantContext ? Icons.calendar_today : Icons.room_preferences,
            color: Colors.orange,
            onTap: isTenantContext ? null : () => _showClassesDialog(context, filters),
          ),
          _OverviewCard(
            title: academicTitle,
            value: '${data['average_academic_performance'] ?? data['report_card_completion_percentage'] ?? 0.0}%',
            icon: Icons.assessment,
            color: Colors.purple,
            onTap: isTenantContext ? null : () => _showAcademicDialog(context, filters),
          ),
          _OverviewCard(
            title: attendanceTitle,
            value: '${data['average_attendance'] ?? data['overall_attendance'] ?? 100.0}%',
            icon: Icons.calendar_today,
            color: Colors.indigo,
            onTap: isTenantContext ? null : () => _showAttendanceDialog(context, filters),
          ),
          _OverviewCard(
            title: feeTitle,
            value: '${data['fee_collection_percentage'] ?? 100.0}%',
            icon: Icons.payments,
            color: Colors.green,
            onTap: isTenantContext ? null : () => _showFeesDialog(context, filters),
          ),
          _OverviewCard(
            title: riskTitle,
            value: '${data['students_requiring_attention'] ?? 0}',
            icon: Icons.warning,
            color: Colors.red,
            onTap: isTenantContext ? null : () => _showRiskDialog(context, filters),
          ),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Operational Metrics',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1024 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing.md,
                      mainAxisSpacing: spacing.md,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, idx) => cards[idx],
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildCleanErrorState(
        message: 'Unable to load overview metrics right now. Please try again.',
        onRetry: () => ref.invalidate(reportsDashboardProvider),
        theme: theme,
      ),
    );
  }



  Widget _buildAcademicTab(AppSpacing spacing, AppRadius radius, ThemeData theme) {
    final academicAsync = ref.watch(reportsAcademicProvider);
    final filters = ref.watch(reportsFiltersProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    if (schoolId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please select a specific school context to view academic performance analytics.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return academicAsync.when(
      data: (data) {
        final topPerformers = (data['top_performers'] as List<dynamic>?) ?? [];
        final needIntervention = (data['students_needing_intervention'] as List<dynamic>?) ?? [];
        final gradeDistribution = (data['grade_distribution'] as Map<String, dynamic>?) ?? {};

        final totalStudents = gradeDistribution.values.fold<int>(0, (sum, val) => sum + (val as num).toInt());

        const gradeOrder = {
          'A+': 0,
          'A': 1,
          'B': 2,
          'C': 3,
          'D': 4,
          'E': 5,
          'F': 6,
        };

        final sortedEntries = gradeDistribution.entries.toList()
          ..sort((a, b) {
            final orderA = gradeOrder[a.key] ?? 99;
            final orderB = gradeOrder[b.key] ?? 99;
            return orderA.compareTo(orderB);
          });

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final childWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall statistics row
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Class Avg Percentage',
                          value: '${data['average_percentage'] ?? 0.0}%',
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatTile(
                          label: 'Highest Scored',
                          value: '${data['highest_marks'] ?? 0.0}%',
                          icon: Icons.star,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatTile(
                          label: 'Pass Rate',
                          value: '${data['pass_percentage'] ?? 100.0}%',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Grade Distribution Chart Placeholder Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grade Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          if (gradeDistribution.isEmpty)
                            const Text('No marks recorded for current filter combination.')
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: sortedEntries.map((e) {
                                final isSelected = filters.grade == e.key;
                                final count = (e.value as num).toInt();
                                final percentage = totalStudents > 0 ? (count / totalStudents * 100.0) : 0.0;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _academicCurrentPage = 1;
                                    });
                                    if (isSelected) {
                                      ref.read(reportsFiltersProvider.notifier).updateGrade(null);
                                    } else {
                                      ref.read(reportsFiltersProvider.notifier).updateGrade(e.key);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
                                      border: Border.all(
                                        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.key,
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '$count Students',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: isSelected ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${percentage.toStringAsFixed(2)}%',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Top Performers & Intervention Lists
                  constraints.maxWidth > 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPerformersCard('Top Performers 🏆', topPerformers, theme, spacing, radius)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPerformersCard('Intervention Alerts ⚠️', needIntervention, theme, spacing, radius, isWarning: true)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPerformersCard('Top Performers 🏆', topPerformers, theme, spacing, radius),
                            const SizedBox(height: 16),
                            _buildPerformersCard('Intervention Alerts ⚠️', needIntervention, theme, spacing, radius, isWarning: true),
                          ],
                        ),
                  
                  const SizedBox(height: 32),
                  // Student Drill-Down Section
                  _buildAcademicRosterTable(theme, spacing, radius, filters, data),
                ],
              );
              return childWidget;
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildCleanErrorState(
        message: 'Unable to load academic performance data right now. Please try again.',
        onRetry: () => ref.invalidate(reportsAcademicProvider),
        theme: theme,
      ),
    );
  }

  Widget _buildAcademicRosterTable(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    ReportsFilters filters,
    Map<String, dynamic> data,
  ) {
    // 1. Get raw students
    final studentPerformance = (data['student_performance'] as List<dynamic>?) ?? [];

    // 2. Filter by grade (if selected)
    var filteredByGrade = studentPerformance;
    if (filters.grade != null) {
      filteredByGrade = studentPerformance.where((sp) {
        final g = sp['grade']?.toString() ?? '';
        return g.toUpperCase() == filters.grade!.toUpperCase();
      }).toList();
    }

    // 3. Filter by search query (if any)
    var filteredBySearch = filteredByGrade;
    if (_academicSearchQuery.isNotEmpty) {
      final query = _academicSearchQuery.toLowerCase();
      filteredBySearch = filteredByGrade.where((sp) {
        final name = (sp['student_name'] ?? '').toString().toLowerCase();
        final admNo = (sp['admission_number'] ?? '').toString().toLowerCase();
        return name.contains(query) || admNo.contains(query);
      }).toList();
    }

    // 4. Sort: Average percentage DESC, then Student Name ASC
    final sortedStudents = filteredBySearch.toList()
      ..sort((a, b) {
        final pctA = (a['percentage'] as num?)?.toDouble() ?? 0.0;
        final pctB = (b['percentage'] as num?)?.toDouble() ?? 0.0;
        final cmpPct = pctB.compareTo(pctA); // Descending
        if (cmpPct != 0) return cmpPct;

        final nameA = (a['student_name'] ?? '').toString();
        final nameB = (b['student_name'] ?? '').toString();
        return nameA.compareTo(nameB); // Ascending
      });

    final totalFilteredCount = sortedStudents.length;
    final totalPages = (totalFilteredCount / _academicRowsPerPage).ceil();

    if (_academicCurrentPage > totalPages && totalPages > 0) {
      _academicCurrentPage = totalPages;
    } else if (_academicCurrentPage < 1) {
      _academicCurrentPage = 1;
    }

    final startIndex = totalFilteredCount > 0 ? (_academicCurrentPage - 1) * _academicRowsPerPage : 0;
    final endIndex = (startIndex + _academicRowsPerPage) < totalFilteredCount
        ? startIndex + _academicRowsPerPage
        : totalFilteredCount;

    final paginatedStudents = totalFilteredCount > 0
        ? sortedStudents.sublist(startIndex, endIndex)
        : [];

    final titleText = filters.grade != null
        ? 'Students with Grade ${filters.grade} (${filteredByGrade.length})'
        : 'Student Roster (${studentPerformance.length})';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and search bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titleText,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _academicSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or admission number...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _academicSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _academicSearchController.clear();
                                  _academicSearchQuery = '';
                                  _academicCurrentPage = 1;
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _academicSearchQuery = val;
                        _academicCurrentPage = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (totalFilteredCount == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No student records found matching active filter constraints.'),
                ),
              )
            else ...[
              // Scrollable Table
              Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                        children: const [
                          Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Admission No.', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Class - Section', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Average %', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Highest Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      // Data Rows
                      ...paginatedStudents.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final student = entry.value;
                        final rowNum = startIndex + idx + 1;
                        final studentId = student['student_id'];
                        final studentName = student['student_name'] ?? 'Unknown';

                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(10), child: Text('$rowNum')),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: InkWell(
                                onTap: () {
                                  // Navigate to Student details page
                                  ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                                  ref.read(resultsFiltersProvider.notifier).setClass(filters.classId);
                                  ref.read(resultsFiltersProvider.notifier).setSection(filters.sectionId);
                                  context.push('/results/students/$studentId');
                                },
                                child: Text(
                                  studentName,
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Padding(padding: const EdgeInsets.all(10), child: Text(student['admission_number'] ?? 'N/A')),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${student['class_name'] ?? 'N/A'} - ${student['section_name'] ?? 'N/A'}')),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${student['percentage']}%')),
                            Padding(padding: const EdgeInsets.all(10), child: Text(student['grade'] ?? 'F')),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${student['highest_score']}%')),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pagination Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1}-${endIndex} of ${totalFilteredCount} students',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _academicCurrentPage > 1
                            ? () => setState(() => _academicCurrentPage--)
                            : null,
                      ),
                      Text(
                        'Page $_academicCurrentPage of $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _academicCurrentPage < totalPages
                            ? () => setState(() => _academicCurrentPage++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformersCard(String title, List<dynamic> list, ThemeData theme, AppSpacing spacing, AppRadius radius, {bool isWarning = false}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isWarning ? Colors.red : Colors.green)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text('No records matching threshold constraints.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (context, idx) => const Divider(),
                itemBuilder: (context, idx) {
                  final item = list[idx];
                   return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Class: ${item['class_name']} - Section: ${item['section_name']}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isWarning ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item['percentage']}%',
                        style: TextStyle(color: isWarning ? Colors.red.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () {
                      final filters = ref.read(reportsFiltersProvider);
                      ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                      ref.read(resultsFiltersProvider.notifier).setClass(item['class_id']);
                      ref.read(resultsFiltersProvider.notifier).setSection(item['section_id']);
                      context.push('/results/students/${item['student_id']}');
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(AppSpacing spacing, AppRadius radius, ThemeData theme) {
    final attendanceAsync = ref.watch(reportsAttendanceProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final filters = ref.watch(reportsFiltersProvider);

    if (schoolId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please select a specific school context to view attendance records.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return attendanceAsync.when(
      data: (data) {
        final lowAttendance = (data['low_attendance_students'] as List<dynamic>?) ?? [];
        final classAttendance = (data['class_wise_attendance'] as Map<String, dynamic>?) ?? {};
        final monthlyTrend = (data['monthly_attendance_trend'] as Map<String, dynamic>?) ?? {};

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatTile(
                label: 'Overall School Attendance',
                value: '${data['overall_attendance'] ?? 100.0}%',
                icon: Icons.calendar_today,
                color: Colors.blue,
                onTap: () => _showAttendanceDialog(context, filters),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Attendance Trends', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (monthlyTrend.isEmpty)
                        const Text('No monthly attendance trends aggregated.')
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: monthlyTrend.entries.map((e) {
                            return ActionChip(
                              label: Text('${e.key}: ${e.value}%'),
                              onPressed: () => _showAttendanceDialog(context, filters),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class-wise Attendance Averages', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (classAttendance.isEmpty)
                        const Text('No class attendance reports logged.')
                      else
                        Table(
                          border: TableBorder.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Colors.black12),
                              children: [
                                Padding(padding: EdgeInsets.all(8), child: Text('Class Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Average Attendance %', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...classAttendance.entries.map((e) => TableRow(
                              children: [
                                InkWell(
                                  onTap: () => _showAttendanceDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text(e.key, style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue))),
                                ),
                                InkWell(
                                  onTap: () => _showAttendanceDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text('${e.value}%')),
                                ),
                              ],
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Low Attendance Alerts (< 75%)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 12),
                      if (lowAttendance.isEmpty)
                        const Text('No student triggers the low attendance alert warning thresholds.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lowAttendance.length,
                          separatorBuilder: (context, idx) => const Divider(),
                          itemBuilder: (context, idx) {
                            final alert = lowAttendance[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Icon(Icons.priority_high, color: Colors.white),
                              ),
                              title: Text(alert['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${alert['class_name']} - ${alert['section_name']}'),
                              trailing: Text('${alert['attendance_percentage']}%', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildCleanErrorState(
        message: 'Unable to load attendance records right now. Please try again.',
        onRetry: () => ref.invalidate(reportsAttendanceProvider),
        theme: theme,
      ),
    );
  }

  Widget _buildFeesTab(AppSpacing spacing, AppRadius radius, ThemeData theme) {
    final feesAsync = ref.watch(reportsFeesProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final filters = ref.watch(reportsFiltersProvider);

    if (schoolId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please select a specific school context to view fee analytics.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return feesAsync.when(
      data: (data) {
        final classCollection = (data['class_wise_collection'] as Map<String, dynamic>?) ?? {};
        final feeTypeCollection = (data['fee_type_wise_collection'] as Map<String, dynamic>?) ?? {};

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Total Net Dues Assigned',
                      value: '₹${data['total_assigned'] ?? 0.0}',
                      icon: Icons.payments,
                      onTap: () => _showFeesDialog(context, filters),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatTile(
                      label: 'Total Collected',
                      value: '₹${data['total_collected'] ?? 0.0}',
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                      onTap: () => _showFeesDialog(context, filters),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatTile(
                      label: 'Outstanding Balance',
                      value: '₹${data['total_outstanding'] ?? 0.0}',
                      icon: Icons.error_outline,
                      color: Colors.red,
                      onTap: () => _showFeesDialog(context, filters),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collection State Counts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _FeeCountItem(
                            label: 'Fully Paid',
                            count: data['paid_students_count'] ?? 0,
                            color: Colors.green,
                            onTap: () => _showFeesDialog(context, filters),
                          ),
                          _FeeCountItem(
                            label: 'Partially Paid',
                            count: data['partial_payment_students_count'] ?? 0,
                            color: Colors.orange,
                            onTap: () => _showFeesDialog(context, filters),
                          ),
                          _FeeCountItem(
                            label: 'Unpaid',
                            count: data['unpaid_students_count'] ?? 0,
                            color: Colors.red,
                            onTap: () => _showFeesDialog(context, filters),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fee Type-wise Collection Progress', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (feeTypeCollection.isEmpty)
                        const Text('No fee type collection details aggregated.')
                      else
                        Table(
                          border: TableBorder.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Colors.black12),
                              children: [
                                Padding(padding: EdgeInsets.all(8), child: Text('Fee Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Collected Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...feeTypeCollection.entries.map((e) => TableRow(
                              children: [
                                InkWell(
                                  onTap: () => _showFeesDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text(e.key, style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue))),
                                ),
                                InkWell(
                                  onTap: () => _showFeesDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text('₹${e.value}')),
                                ),
                              ],
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class-wise Collection Progress', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (classCollection.isEmpty)
                        const Text('No active assignments found.')
                      else
                        Table(
                          border: TableBorder.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Colors.black12),
                              children: [
                                Padding(padding: EdgeInsets.all(8), child: Text('Class Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Collection Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...classCollection.entries.map((e) => TableRow(
                              children: [
                                InkWell(
                                  onTap: () => _showFeesDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text(e.key, style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue))),
                                ),
                                InkWell(
                                  onTap: () => _showFeesDialog(context, filters),
                                  child: Padding(padding: const EdgeInsets.all(8), child: Text('${e.value}%')),
                                ),
                              ],
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildCleanErrorState(
        message: 'Unable to load fee analytics right now. Please try again.',
        onRetry: () => ref.invalidate(reportsFeesProvider),
        theme: theme,
      ),
    );
  }

  // --- AI PREDICTIVE INSIGHTS TAB ---
  Widget _buildAITab(AppSpacing spacing, AppRadius radius, ThemeData theme) {
    final aiAsync = ref.watch(reportsAIIntelligenceProvider);
    final filters = ref.watch(reportsFiltersProvider);

    return aiAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'AI Predictive Insights are only available within a selected school context.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        final highRisk = (data['high_risk_students'] as List<dynamic>?) ?? [];
        final mediumRisk = (data['medium_risk_students'] as List<dynamic>?) ?? [];
        final lowRisk = (data['low_risk_students'] as List<dynamic>?) ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'High Risk Students',
                      value: '${data['attendance_academic_risk_count'] ?? 0}',
                      icon: Icons.dangerous,
                      color: Colors.red,
                      onTap: () => _showRiskDialog(context, filters),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatTile(
                      label: 'On-Track (Improving)',
                      value: '${data['high_performers_count'] ?? 0}',
                      icon: Icons.trending_up,
                      color: Colors.green,
                      onTap: () => _showRiskDialog(context, filters),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flagged Students Requiring Immediate Attention', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 12),
                      if (highRisk.isEmpty)
                        const Text('No student is flagged as HIGH RISK currently.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: highRisk.length,
                          separatorBuilder: (context, idx) => const Divider(),
                          itemBuilder: (context, idx) {
                            final stud = highRisk[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Icon(Icons.crisis_alert, color: Colors.white),
                              ),
                              title: Text(stud['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${stud['class_name']} - ${stud['section_name']} | Academic Avg: ${stud['current_percentage']}%'),
                                  const SizedBox(height: 4),
                                  Text('AI Insight: ${stud['ai_narrative']}', style: TextStyle(color: Colors.red.shade800, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text('Action: ${stud['recommendation']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () {
                                ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                                ref.read(resultsFiltersProvider.notifier).setClass(stud['class_id']);
                                ref.read(resultsFiltersProvider.notifier).setSection(stud['section_id']);
                                context.push('/results/students/${stud['student_id']}');
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flagged Students for Monitoring (Medium Risk)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 12),
                      if (mediumRisk.isEmpty)
                        const Text('No student is flagged as MEDIUM RISK currently.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: mediumRisk.length,
                          separatorBuilder: (context, idx) => const Divider(),
                          itemBuilder: (context, idx) {
                            final stud = mediumRisk[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.orange,
                                child: Icon(Icons.warning_amber, color: Colors.white),
                              ),
                              title: Text(stud['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${stud['class_name']} - ${stud['section_name']} | Academic Avg: ${stud['current_percentage']}%'),
                              onTap: () {
                                ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                                ref.read(resultsFiltersProvider.notifier).setClass(stud['class_id']);
                                ref.read(resultsFiltersProvider.notifier).setSection(stud['section_id']);
                                context.push('/results/students/${stud['student_id']}');
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Students in Good Standing (Low Risk)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 12),
                      if (lowRisk.isEmpty)
                        const Text('No student is classified as LOW RISK currently.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lowRisk.length,
                          separatorBuilder: (context, idx) => const Divider(),
                          itemBuilder: (context, idx) {
                            final stud = lowRisk[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.check, color: Colors.white),
                              ),
                              title: Text(stud['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${stud['class_name']} - ${stud['section_name']} | Academic Avg: ${stud['current_percentage']}%'),
                              onTap: () {
                                ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                                ref.read(resultsFiltersProvider.notifier).setClass(stud['class_id']);
                                ref.read(resultsFiltersProvider.notifier).setSection(stud['section_id']);
                                context.push('/results/students/${stud['student_id']}');
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildCleanErrorState(
        message: 'Unable to load AI insights right now. Please try again.',
        onRetry: () => ref.invalidate(reportsAIIntelligenceProvider),
        theme: theme,
      ),
    );
  }

  void _showScrollableDialog({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext context, WidgetRef ref) bodyBuilder,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final width = MediaQuery.of(context).size.width;
        final dialogWidth = width > 800 ? 750.0 : width * 0.9;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      return bodyBuilder(context, ref);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStudentsDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Detailed Student Roster',
      bodyBuilder: (context, ref) => _StudentsRosterDialogBody(filters: filters),
    );
  }

  void _showTeachersDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Detailed Teacher Assignments',
      bodyBuilder: (context, ref) => _TeachersRosterDialogBody(filters: filters),
    );
  }

  void _showClassesDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Class & Section Breakdowns',
      bodyBuilder: (context, ref) => _ClassesRosterDialogBody(filters: filters),
    );
  }

  void _showAcademicDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Academic Performance Analytics',
      bodyBuilder: (context, ref) => _AcademicDetailDialogBody(filters: filters),
    );
  }

  void _showAttendanceDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Attendance Analytics & Warnings',
      bodyBuilder: (context, ref) => _AttendanceDetailDialogBody(filters: filters),
    );
  }

  void _showFeesDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'Fee Collection Ledgers',
      bodyBuilder: (context, ref) => _FeesDetailDialogBody(filters: filters),
    );
  }

  void _showRiskDialog(BuildContext context, ReportsFilters filters) {
    _showScrollableDialog(
      context: context,
      title: 'AI Predictive Risk Insights',
      bodyBuilder: (context, ref) => _RiskDetailDialogBody(filters: filters),
    );
  }

  Widget _buildCleanErrorState({
    required String message,
    required VoidCallback onRetry,
    required ThemeData theme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: onTap != null ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                radius: 24,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.blue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidget = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: cardWidget,
      );
    }
    return cardWidget;
  }
}

class _FeeCountItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _FeeCountItem({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final columnWidget = Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: columnWidget,
        ),
      );
    }
    return columnWidget;
  }
}

class _StudentsRosterDialogBody extends StatefulWidget {
  final ReportsFilters filters;
  const _StudentsRosterDialogBody({required this.filters});

  @override
  State<_StudentsRosterDialogBody> createState() => _StudentsRosterDialogBodyState();
}

class _StudentsRosterDialogBodyState extends State<_StudentsRosterDialogBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final studentsAsync = ref.watch(reportsDetailedStudentsProvider);
        return studentsAsync.when(
          data: (students) {
            final filtered = students.where((s) {
              final name = (s['student_name'] ?? '').toString().toLowerCase();
              final code = (s['admission_number'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();

            return Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or admission code...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No students match search.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = filtered[index];
                            final attendance = s['attendance_percentage'] ?? 100.0;
                            final academic = s['academic_percentage'] ?? 0.0;
                            final grade = s['grade'] ?? 'N/A';
                            final risk = s['risk_level'] ?? 'LOW';
                            
                            Color riskColor = Colors.green;
                            if (risk == 'HIGH') {
                              riskColor = Colors.red;
                            } else if (risk == 'MEDIUM') {
                              riskColor = Colors.orange;
                            }

                            final theme = Theme.of(context);
                            return InkWell(
                              onTap: () {
                                ref.read(resultsFiltersProvider.notifier).setAcademicYear(widget.filters.academicYearId);
                                ref.read(resultsFiltersProvider.notifier).setClass(s['class_id']);
                                ref.read(resultsFiltersProvider.notifier).setSection(s['section_id']);
                                Navigator.of(context).pop();
                                context.push('/results/students/${s['student_id']}');
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            s['student_name'] ?? 'Unknown Student',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code: ${s['admission_number']} | Roll: ${s['roll_number']}\n${s['class_name']} - ${s['section_name']} | Status: ${s['promotion_status']}',
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Acad: $academic% ($grade)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text('Att: $attendance%', style: TextStyle(color: attendance < 75 ? Colors.red : Colors.green, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: riskColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            risk,
                                            style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
          error: (err, _) => const Center(
            child: Text(
              'Unable to load student roster right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _TeachersRosterDialogBody extends StatefulWidget {
  final ReportsFilters filters;
  const _TeachersRosterDialogBody({required this.filters});

  @override
  State<_TeachersRosterDialogBody> createState() => _TeachersRosterDialogBodyState();
}

class _TeachersRosterDialogBodyState extends State<_TeachersRosterDialogBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final teachersAsync = ref.watch(reportsDetailedTeachersProvider);
        return teachersAsync.when(
          data: (teachers) {
            final filtered = teachers.where((t) {
              final name = (t['teacher_name'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery.toLowerCase());
            }).toList();

            return Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search teachers by name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No teachers match search.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final t = filtered[index];
                            final subjects = (t['subjects'] as List<dynamic>?)?.join(', ') ?? 'None';
                            final classes = (t['classes'] as List<dynamic>?)?.join(', ') ?? 'None';
                            final sections = (t['sections'] as List<dynamic>?)?.join(', ') ?? 'None';
                            final status = t['status'] ?? 'ACTIVE';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              title: Text(t['teacher_name'] ?? 'Unknown Teacher', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Subjects: $subjects\nClasses: $classes\nSections: $sections'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'ACTIVE' ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'ACTIVE' ? Colors.green : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
          error: (err, _) => const Center(
            child: Text(
              'Unable to load teacher roster right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _ClassesRosterDialogBody extends StatelessWidget {
  final ReportsFilters filters;
  const _ClassesRosterDialogBody({required this.filters});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final classesAsync = ref.watch(reportsDetailedClassesProvider);
        return classesAsync.when(
          data: (classes) {
            if (classes.isEmpty) {
              return const Center(child: Text('No classes found.'));
            }
            return ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final c = classes[index];
                final sections = (c['sections'] as List<dynamic>?) ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: InkWell(
                      onTap: () {
                        ref.read(reportsFiltersProvider.notifier).updateClass(c['class_id']?.toString());
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        c['class_name'] ?? 'Unknown Class',
                        style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: Colors.blue),
                      ),
                    ),
                    subtitle: Text('${c['student_count']} Students | ${c['section_count']} Sections | Academic Avg: ${c['academic_percentage']}% | Attendance: ${c['attendance_percentage']}%'),
                    childrenPadding: const EdgeInsets.all(12),
                    children: [
                      if (sections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No sections available for this class.'),
                        )
                      else
                        Table(
                          border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade100)),
                          children: [
                            const TableRow(
                              children: [
                                Padding(padding: EdgeInsets.all(6), child: Text('Section', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Students', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Academic Avg', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Risk Count', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...sections.map((s) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: InkWell(
                                      onTap: () {
                                        ref.read(reportsFiltersProvider.notifier).updateClass(c['class_id']?.toString());
                                        ref.read(reportsFiltersProvider.notifier).updateSection(s['section_id']?.toString());
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        s['section_name'] ?? 'N/A',
                                        style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                      ),
                                    ),
                                  ),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${s['student_count']}')),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${s['academic_percentage']}%')),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${s['attendance_percentage']}%')),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      '${s['risk_count']}',
                                      style: TextStyle(
                                        color: s['risk_count'] > 0 ? Colors.red : Colors.green,
                                        fontWeight: s['risk_count'] > 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const Center(
            child: Text(
              'Unable to load class details right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _AcademicDetailDialogBody extends StatelessWidget {
  final ReportsFilters filters;
  const _AcademicDetailDialogBody({required this.filters});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final academicAsync = ref.watch(reportsAcademicProvider);
        return academicAsync.when(
          data: (data) {
            final subjectPerformance = (data['subject_performance'] as List<dynamic>?) ?? [];
            final studentPerformance = (data['student_performance'] as List<dynamic>?) ?? [];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniMetricCard('Average Marks', '${data['average_marks'] ?? 0.0}', Colors.blue, context),
                      _buildMiniMetricCard('Average Pct', '${data['average_percentage'] ?? 0.0}%', Colors.purple, context),
                      _buildMiniMetricCard('Pass Rate', '${data['pass_percentage'] ?? 0.0}%', Colors.green, context),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (subjectPerformance.isNotEmpty) ...[
                    const Text('Subject-wise Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, width: 1, borderRadius: BorderRadius.circular(8)),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Colors.black12),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Avg %', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Highest %', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Lowest %', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ...subjectPerformance.map((s) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(s['subject_name'] ?? 'N/A')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${s['average_percentage']}%')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${s['highest_percentage']}%')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${s['lowest_percentage']}%')),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (studentPerformance.isNotEmpty) ...[
                    const Text('Student Academic List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: studentPerformance.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sp = studentPerformance[index];
                        final trend = sp['trend'] ?? 'STABLE';
                        
                        IconData trendIcon = Icons.trending_flat;
                        Color trendColor = Colors.grey;
                        if (trend == 'IMPROVING') {
                          trendIcon = Icons.trending_up;
                          trendColor = Colors.green;
                        } else if (trend == 'DECLINING') {
                          trendIcon = Icons.trending_down;
                          trendColor = Colors.red;
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(sp['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Percentage: ${sp['percentage']}% | Grade: ${sp['grade']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(trendIcon, color: trendColor),
                              const SizedBox(width: 4),
                              Text(trend, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          onTap: () {
                            ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                            ref.read(resultsFiltersProvider.notifier).setClass(filters.classId);
                            ref.read(resultsFiltersProvider.notifier).setSection(filters.sectionId);
                            Navigator.of(context).pop();
                            context.push('/results/students/${sp['student_id']}');
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const Center(
            child: Text(
              'Unable to load academic details right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMetricCard(String label, String value, Color color, BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceDetailDialogBody extends StatelessWidget {
  final ReportsFilters filters;
  const _AttendanceDetailDialogBody({required this.filters});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final attendanceAsync = ref.watch(reportsAttendanceProvider);
        return attendanceAsync.when(
          data: (data) {
            final lowAttendance = (data['low_attendance_students'] as List<dynamic>?) ?? [];
            final monthlyTrends = (data['monthly_attendance_trends'] as Map<String, dynamic>?) ?? {};

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: Colors.blue.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Text('${data['overall_attendance'] ?? 100.0}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 4),
                                const Text('Overall Attendance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (lowAttendance.isNotEmpty) ...[
                    const Text('Low Attendance Warnings (<75%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lowAttendance.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = lowAttendance[index];
                        final pct = s['attendance_percentage'] ?? 0.0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.warning, color: Colors.white),
                          ),
                          title: Text(s['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s['class_name']} - ${s['section_name']} | Present Days: ${s['present_days']}/${s['total_days']}'),
                          trailing: Text('$pct%', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          onTap: () {
                            ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                            ref.read(resultsFiltersProvider.notifier).setClass(s['class_id']);
                            ref.read(resultsFiltersProvider.notifier).setSection(s['section_id']);
                            Navigator.of(context).pop();
                            context.push('/results/students/${s['student_id']}');
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (monthlyTrends.isNotEmpty) ...[
                    const Text('Monthly Attendance Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, width: 1, borderRadius: BorderRadius.circular(8)),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Colors.black12),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Attendance %', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ...monthlyTrends.entries.map((e) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(e.key)),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${e.value}%')),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const Center(
            child: Text(
              'Unable to load attendance details right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _FeesDetailDialogBody extends StatelessWidget {
  final ReportsFilters filters;
  const _FeesDetailDialogBody({required this.filters});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final feesAsync = ref.watch(reportsFeesProvider);
        return feesAsync.when(
          data: (data) {
            final studentFees = (data['student_fees'] as List<dynamic>?) ?? [];
            final classCollection = (data['class_wise_collection'] as Map<String, dynamic>?) ?? {};

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: Colors.green.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.green.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Text('${data['collection_percentage'] ?? 0.0}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                const SizedBox(height: 4),
                                const Text('Collection Rate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: Colors.amber.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.amber.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Text('₹${data['total_outstanding'] ?? 0.0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                                const SizedBox(height: 4),
                                const Text('Outstanding Balance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (classCollection.isNotEmpty) ...[
                    const Text('Class-wise Collection Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, width: 1, borderRadius: BorderRadius.circular(8)),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Colors.black12),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Collection %', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ...classCollection.entries.map((e) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(e.key)),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${e.value}%')),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (studentFees.isNotEmpty) ...[
                    const Text('Student Payment Ledgers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: studentFees.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sf = studentFees[index];
                        final status = sf['status'] ?? 'UNPAID';
                        
                        Color statusColor = Colors.red;
                        if (status == 'PAID') {
                          statusColor = Colors.green;
                        } else if (status == 'PARTIAL') {
                          statusColor = Colors.orange;
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(sf['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Assigned: ₹${sf['assigned']} | Paid: ₹${sf['paid']} | Outstanding: ₹${sf['outstanding']}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () {
                            ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                            ref.read(resultsFiltersProvider.notifier).setClass(sf['class_id']);
                            ref.read(resultsFiltersProvider.notifier).setSection(sf['section_id']);
                            Navigator.of(context).pop();
                            context.push('/results/students/${sf['student_id']}');
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const Center(
            child: Text(
              'Unable to load fee details right now.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _RiskDetailDialogBody extends StatelessWidget {
  final ReportsFilters filters;
  const _RiskDetailDialogBody({required this.filters});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final aiAsync = ref.watch(reportsAIIntelligenceProvider);
        return aiAsync.when(
          data: (data) {
            final highRisk = (data['high_risk_students'] as List<dynamic>?) ?? [];
            final mediumRisk = (data['medium_risk_students'] as List<dynamic>?) ?? [];
            final totalRisk = highRisk.length + mediumRisk.length;

            if (totalRisk == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No Risk Alerts Flagged',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All students are performing within standard metrics and show stable attendance levels.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allRisk = [...highRisk, ...mediumRisk];

            return ListView.separated(
              itemCount: allRisk.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final r = allRisk[index];
                final risk = r['risk_level'] ?? 'LOW';
                final weakSubs = (r['weak_subjects'] as List<dynamic>?)?.join(', ') ?? 'None';
                final attTrend = r['attendance_trend'] ?? 'STABLE';
                final narrative = r['ai_narrative'] ?? 'N/A';
                final recommendation = r['recommendation'] ?? 'N/A';

                Color riskColor = Colors.orange;
                if (risk == 'HIGH') {
                  riskColor = Colors.red;
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: riskColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r['student_name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: riskColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$risk RISK',
                                style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${r['class_name']} - ${r['section_name']} | Academic Avg: ${r['current_percentage']}% | Attendance: ${r['attendance_percentage']}%'),
                        const SizedBox(height: 8),
                        Text('Attendance Trend: $attTrend', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Weak Subjects: $weakSubs', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        const Text('AI Narrative:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(narrative, style: const TextStyle(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 6),
                        const Text('Recommendation:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(recommendation),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View Result Details'),
                            onPressed: () {
                              ref.read(resultsFiltersProvider.notifier).setAcademicYear(filters.academicYearId);
                              ref.read(resultsFiltersProvider.notifier).setClass(filters.classId);
                              ref.read(resultsFiltersProvider.notifier).setSection(filters.sectionId);
                              Navigator.of(context).pop();
                              context.push('/results/students/${r['student_id']}');
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load AI insights right now. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(reportsAIIntelligenceProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
