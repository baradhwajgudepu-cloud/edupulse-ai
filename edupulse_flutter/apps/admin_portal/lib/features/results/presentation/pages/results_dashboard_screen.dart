import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';
import '../widgets/predictive_analytics_view.dart';
import '../../../../core/routing/routes.dart';

class ResultsDashboardScreen extends ConsumerStatefulWidget {
  final String? initialSection;
  const ResultsDashboardScreen({super.key, this.initialSection});

  @override
  ConsumerState<ResultsDashboardScreen> createState() => _ResultsDashboardScreenState();
}

class _ResultsDashboardScreenState extends ConsumerState<ResultsDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _readinessKey = GlobalKey();
  final GlobalKey _analyticsKey = GlobalKey();
  final GlobalKey _chapterMappingKey = GlobalKey();
  final GlobalKey _syllabusCoverageKey = GlobalKey();
  final GlobalKey _rosterKey = GlobalKey();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(widget.initialSection!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String section) {
    GlobalKey? targetKey;
    if (section == 'publishing' || section == 'readiness') {
      targetKey = _readinessKey;
    } else if (section == 'analytics') {
      targetKey = _analyticsKey;
    } else if (section == 'chapter') {
      targetKey = _chapterMappingKey;
    } else if (section == 'syllabus') {
      targetKey = _syllabusCoverageKey;
    } else if (section == 'roster') {
      targetKey = _rosterKey;
    }

    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          (section == 'publishing' || section == 'readiness')
              ? 220.0
              : (section == 'analytics' ? 400.0 : (section == 'chapter' ? 650.0 : (section == 'roster' ? 950.0 : 850.0))),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      }
    });
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        color = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'APPROVED':
        color = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'UNDER_REVIEW':
        color = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        break;
      case 'DRAFT':
        color = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'NOT GENERATED':
      default:
        color = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final filters = ref.watch(resultsFiltersProvider);
    final studentsAsync = ref.watch(resultsStudentsProvider);
    final cardsAsync = ref.watch(resultsReportCardsProvider);
    final stats = ref.watch(resultsDashboardStatsProvider);
    
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results & Report Cards')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its results.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Load setup dependencies
    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));

    final filtersNotifier = ref.read(resultsFiltersProvider.notifier);

    // Results states
    final examsAsync = ref.watch(resultsExaminationsProvider);

    // Deduplicate Academic Years
    final uniqueYearsMap = <String, AcademicYearDto>{};
    for (final y in ayState.years) {
      if (y.id.isNotEmpty) {
        if (uniqueYearsMap.containsKey(y.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Academic Year ID duplicate detected: ${y.id}');
        } else {
          uniqueYearsMap[y.id] = y;
        }
      }
    }
    final uniqueYears = uniqueYearsMap.values.toList();
    final validAyId = uniqueYears.any((y) => y.id == filters.academicYearId)
        ? filters.academicYearId
        : null;

    // Deduplicate Classes
    final uniqueClassesMap = <String, ClassDto>{};
    for (final c in classState.classes) {
      if (c.id.isNotEmpty) {
        if (uniqueClassesMap.containsKey(c.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Class ID duplicate detected: ${c.id}');
        } else {
          uniqueClassesMap[c.id] = c;
        }
      }
    }
    final uniqueClasses = uniqueClassesMap.values.toList();
    final validClassId = uniqueClasses.any((c) => c.id == filters.classId)
        ? filters.classId
        : null;

    // Deduplicate Sections
    final filteredSections = sectionState.sections
        .where((s) => s.classId == validClassId)
        .toList();
    final uniqueSectionsMap = <String, SectionDto>{};
    for (final s in filteredSections) {
      if (s.id.isNotEmpty) {
        if (uniqueSectionsMap.containsKey(s.id)) {
          // ignore: avoid_print
          print('[DROPDOWN][DUPLICATE] Section ID duplicate detected: ${s.id}');
        } else {
          uniqueSectionsMap[s.id] = s;
        }
      }
    }
    final uniqueSections = uniqueSectionsMap.values.toList();
    final validSectionId = uniqueSections.any((s) => s.id == filters.sectionId)
        ? filters.sectionId
        : null;

    // Deduplicate Examinations
    final uniqueExamsMap = <String, ExaminationDto>{};
    if (examsAsync.hasValue) {
      for (final e in examsAsync.value ?? const <ExaminationDto>[]) {
        if (e.id.isNotEmpty) {
          if (uniqueExamsMap.containsKey(e.id)) {
            // ignore: avoid_print
            print('[DROPDOWN][DUPLICATE] Examination ID duplicate detected: ${e.id}');
          } else {
            uniqueExamsMap[e.id] = e;
          }
        }
      }
    }
    final uniqueExams = uniqueExamsMap.values.toList();
    final validExamId = uniqueExams.any((e) => e.id == filters.examinationId)
        ? filters.examinationId
        : null;

    // Schedule asynchronous reset of invalid filter states after UI frame
    if ((filters.academicYearId != null && validAyId == null) ||
        (filters.classId != null && validClassId == null) ||
        (filters.sectionId != null && validSectionId == null) ||
        (filters.examinationId != null && validExamId == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (filters.academicYearId != null && validAyId == null) {
          filtersNotifier.setAcademicYear(null);
        }
        if (filters.classId != null && validClassId == null) {
          filtersNotifier.setClass(null);
        }
        if (filters.sectionId != null && validSectionId == null) {
          filtersNotifier.setSection(null);
        }
        if (filters.examinationId != null && validExamId == null) {
          filtersNotifier.setExamination(null);
        }
      });
    }

    // Dynamic initial state selection mapping (defaults fallback if empty or invalid)
    if (uniqueYears.isNotEmpty && validAyId == null) {
      final current = uniqueYears.firstWhere((y) => y.isCurrent, orElse: () => uniqueYears.first);
      Future.microtask(() => filtersNotifier.setAcademicYear(current.id));
    }
    if (uniqueClasses.isNotEmpty && validClassId == null) {
      Future.microtask(() => filtersNotifier.setClass(uniqueClasses.first.id));
    }
    if (uniqueSections.isNotEmpty && validClassId != null && validSectionId == null) {
      final section = uniqueSections.firstWhere(
        (s) => s.classId == validClassId,
        orElse: () => uniqueSections.first,
      );
      Future.microtask(() => filtersNotifier.setSection(section.id));
    }
    if (uniqueExams.isNotEmpty && validExamId == null) {
      final now = DateTime.now();
      bool isNotFuture(ExaminationDto e) {
        try {
          final sDate = DateTime.parse(e.startDate);
          return sDate.isBefore(now) || sDate.isAtSameMomentAs(now);
        } catch (_) {
          return true;
        }
      }

      final preferredExam = uniqueExams.where((e) => e.status == 'PUBLISHED' && isNotFuture(e)).firstOrNull ??
          uniqueExams.where((e) => (e.status == 'COMPLETED' || e.status == 'APPROVED') && isNotFuture(e)).firstOrNull ??
          uniqueExams.where((e) => e.status != 'DRAFT' && e.status != 'ARCHIVED' && isNotFuture(e)).firstOrNull ??
          uniqueExams.where((e) => e.status != 'DRAFT').firstOrNull ??
          uniqueExams.first;
      Future.microtask(() => filtersNotifier.setExamination(preferredExam.id));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Exams & Assessments Dashboard'),
            Text(
              'Results & Report Cards',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (isMobile) ...[
            IconButton(
              key: const Key('header_create_exam_btn'),
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0F766E)),
              tooltip: 'Create Examination',
              onPressed: () => context.push(AppRoutes.examinations),
            ),
            IconButton(
              key: const Key('header_import_marks_btn'),
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Import Marks',
              onPressed: () {
                final queryParams = <String, String>{};
                if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
                if (filters.classId != null) queryParams['class_id'] = filters.classId!;
                if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
                if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
                final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
                context.push(uri.toString());
              },
            ),
            IconButton(
              key: const Key('header_manage_marks_btn'),
              icon: const Icon(Icons.edit_calendar),
              tooltip: 'Manage Marks',
              onPressed: () {
                final queryParams = <String, String>{};
                if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
                if (filters.classId != null) queryParams['class_id'] = filters.classId!;
                if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
                if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
                final uri = Uri(path: AppRoutes.marksManagement, queryParameters: queryParams);
                context.push(uri.toString());
              },
            ),
          ] else ...[
            FilledButton.icon(
              key: const Key('header_create_exam_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Examination'),
              onPressed: () => context.push(AppRoutes.examinations),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('header_import_marks_btn'),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Import Marks'),
              onPressed: () {
                final queryParams = <String, String>{};
                if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
                if (filters.classId != null) queryParams['class_id'] = filters.classId!;
                if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
                if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
                final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
                context.push(uri.toString());
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              key: const Key('header_manage_marks_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Manage Marks'),
              onPressed: () {
                final queryParams = <String, String>{};
                if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
                if (filters.classId != null) queryParams['class_id'] = filters.classId!;
                if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
                if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
                final uri = Uri(path: AppRoutes.marksManagement, queryParameters: queryParams);
                context.push(uri.toString());
              },
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: () {
              ref.invalidate(resultsExaminationsProvider);
              ref.invalidate(resultsStudentsProvider);
              ref.invalidate(resultsReportCardsProvider);
              ref.invalidate(resultsReadinessProvider);
              _refreshData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exams & Assessments Operations Hub
            _buildExamsOperationsHub(context, filters),
            // Filter card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_alt_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Filter Roster Results',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final colCount = width > 1024 ? 4 : (width > 600 ? 2 : 1);
                        final itemWidth = width / colCount - 16;

                        final items = [
                          // Academic Year
                          DropdownButtonFormField<String>(
                            value: validAyId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: uniqueYears.map<DropdownMenuItem<String>>((y) {
                              return DropdownMenuItem<String>(
                                value: y.id,
                                child: Text('${y.name} ${y.isCurrent ? "(Current)" : ""}'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              filtersNotifier.setAcademicYear(v);
                              ref.invalidate(resultsExaminationsProvider);
                            },
                          ),
                          // Examination
                          DropdownButtonFormField<String>(
                            value: validExamId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Examination',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: uniqueExams.map<DropdownMenuItem<String>>((e) {
                              return DropdownMenuItem<String>(
                                value: e.id,
                                child: Text(e.examName),
                              );
                            }).toList(),
                            onChanged: (v) => filtersNotifier.setExamination(v),
                          ),
                          // Class
                          DropdownButtonFormField<String>(
                            value: validClassId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Class',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: uniqueClasses.map<DropdownMenuItem<String>>((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: (v) {
                              filtersNotifier.setClass(v);
                              ref.invalidate(resultsStudentsProvider);
                              ref.invalidate(resultsReportCardsProvider);
                            },
                          ),
                          // Section
                          DropdownButtonFormField<String>(
                            value: validSectionId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: uniqueSections.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(s.name),
                              );
                            }).toList(),
                            onChanged: (v) {
                              filtersNotifier.setSection(v);
                              ref.invalidate(resultsStudentsProvider);
                              ref.invalidate(resultsReportCardsProvider);
                            },
                          ),
                        ];

                        if (colCount == 1) {
                          return Column(
                            children: items
                                .map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: e,
                                    ))
                                .toList(),
                          );
                        } else {
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: items
                                .map((e) => SizedBox(
                                      width: itemWidth,
                                      child: e,
                                    ))
                                .toList(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Results Readiness & Publication Control Section
            KeyedSubtree(
              key: _readinessKey,
              child: _buildResultReadinessCard(context, filters, schoolId),
            ),
            const SizedBox(height: 24),

            // Statistics widgets
            if (stats != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final double childWidth = width > 900 ? (width - 32) / 3 : (width > 600 ? (width - 16) / 2 : width);

                  final cards = [
                    _buildStatCard(
                      context,
                      title: 'Total Students',
                      value: stats.totalStudents.toString(),
                      icon: Icons.people_outline,
                      color: theme.colorScheme.primary,
                    ),
                    _buildStatCard(
                      context,
                      title: 'Complete Results',
                      value: stats.completeResults.toString(),
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      title: 'Incomplete Results',
                      value: stats.incompleteResults.toString(),
                      icon: Icons.pending_actions_outlined,
                      color: Colors.orange,
                    ),
                  ];

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards
                        .map((e) => SizedBox(
                              width: childWidth,
                              child: e,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Predictive Analytics Intelligence
            Container(
              key: _analyticsKey,
              child: PredictiveAnalyticsView(
                initialClassId: filters.classId,
                initialAcademicYearId: filters.academicYearId,
                chapterSectionKey: _chapterMappingKey,
                syllabusSectionKey: _syllabusCoverageKey,
              ),
            ),
            const SizedBox(height: 28),

            // Student results roster
            Container(
              key: _rosterKey,
              child: Text(
                'Student Roster Results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar & datatable
            studentsAsync.when(
              data: (List<StudentDto> students) {
                if (students.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No students mapped to the selected class and section.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }

                return cardsAsync.when(
                  data: (List<ReportCardDto> cards) {
                    final filtered = students.where((st) {
                      final nameMatch = '${st.firstName} ${st.lastName}'.toLowerCase().contains(_searchQuery.toLowerCase());
                      final rollMatch = st.rollNumber.toLowerCase().contains(_searchQuery.toLowerCase());
                      final admMatch = st.admissionNumber.toLowerCase().contains(_searchQuery.toLowerCase());
                      return nameMatch || rollMatch || admMatch;
                    }).toList();

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search by roll number, name or admission code...',
                                prefixIcon: Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(child: Text('No students found matching your search query.')),
                            )
                          else if (isMobile)
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final st = filtered[idx];
                                final card = cards.firstWhere(
                                  (c) => c.studentId == st.id,
                                  orElse: () => const ReportCardDto(
                                    id: '',
                                    verificationUuid: '',
                                    status: 'NOT GENERATED',
                                    pdfHistory: [],
                                    tenantId: '',
                                    schoolId: '',
                                    academicYearId: '',
                                    studentId: '',
                                    aiMetrics: {},
                                  ),
                                );
                                final hasCard = card.id.isNotEmpty;

                                return ListTile(
                                  title: Text('${st.rollNumber}. ${st.firstName} ${st.lastName}'),
                                  subtitle: Text('Adm No: ${st.admissionNumber}'),
                                  trailing: _buildStatusBadge(hasCard ? card.status : 'NOT GENERATED'),
                                  onTap: () => context.push('/results/students/${st.id}'),
                                );
                              },
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Roll No')),
                                  DataColumn(label: Text('Admission No')),
                                  DataColumn(label: Text('Student Name')),
                                  DataColumn(label: Text('Class & Section')),
                                  DataColumn(label: Text('Result Status')),
                                ],
                                rows: filtered.map((st) {
                                  final card = cards.firstWhere(
                                    (c) => c.studentId == st.id,
                                    orElse: () => const ReportCardDto(
                                      id: '',
                                      verificationUuid: '',
                                      status: 'NOT GENERATED',
                                      pdfHistory: [],
                                      tenantId: '',
                                      schoolId: '',
                                      academicYearId: '',
                                      studentId: '',
                                      aiMetrics: {},
                                    ),
                                  );
                                  final hasCard = card.id.isNotEmpty;
                                  final className = classState.classes.firstWhere((c) => c.id == st.classId, orElse: () => classState.classes.first).name;
                                  final secName = sectionState.sections.firstWhere((s) => s.id == st.sectionId, orElse: () => sectionState.sections.first).name;

                                  return DataRow(
                                    onSelectChanged: (_) => context.push('/results/students/${st.id}'),
                                    cells: [
                                      DataCell(Text(st.rollNumber)),
                                      DataCell(Text(st.admissionNumber)),
                                      DataCell(Text('${st.firstName} ${st.lastName}')),
                                      DataCell(Text('$className - $secName')),
                                      DataCell(_buildStatusBadge(hasCard ? card.status : 'NOT GENERATED')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading report cards list: $err', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading student roster list: $err', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(resultsStudentsProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsOperationsHub(BuildContext context, ResultsFiltersState filters) {
    final theme = Theme.of(context);

    final actions = [
      _ExamHubActionItem(
        key: const Key('hub_create_examination_action'),
        title: '+ Create Examination',
        subtitle: 'New Exam Wizard',
        icon: Icons.add_task_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => context.push(AppRoutes.examinations),
      ),
      _ExamHubActionItem(
        key: const Key('hub_import_marks_action'),
        title: 'Import Marks',
        subtitle: '9-Step Ingestion Wizard',
        icon: Icons.cloud_upload_outlined,
        color: const Color(0xFF2563EB),
        onTap: () {
          final queryParams = <String, String>{};
          if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
          if (filters.classId != null) queryParams['class_id'] = filters.classId!;
          if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
          if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
          final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
          context.push(uri.toString());
        },
      ),
      _ExamHubActionItem(
        key: const Key('hub_manage_marks_action'),
        title: 'Manage Marks',
        subtitle: 'Scores, Entry & Overrides',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF4F46E5),
        onTap: () {
          final queryParams = <String, String>{};
          if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
          if (filters.classId != null) queryParams['class_id'] = filters.classId!;
          if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
          if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
          final uri = Uri(path: AppRoutes.marksManagement, queryParameters: queryParams);
          context.push(uri.toString());
        },
      ),
      _ExamHubActionItem(
        key: const Key('hub_results_publishing_action'),
        title: 'Results Publishing',
        subtitle: 'Readiness & Parent Release',
        icon: Icons.publish_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => _scrollToSection('publishing'),
      ),
      _ExamHubActionItem(
        key: const Key('hub_report_cards_action'),
        title: 'Report Cards',
        subtitle: 'Bulk PDF & Generation',
        icon: Icons.badge_outlined,
        color: const Color(0xFF0284C7),
        onTap: () => context.push(AppRoutes.reportCards),
      ),
      _ExamHubActionItem(
        key: const Key('hub_syllabus_action'),
        title: 'Syllabus & Coverage',
        subtitle: 'Curriculum Pacing & Progress',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFD97706),
        onTap: () => _scrollToSection('syllabus'),
      ),
      _ExamHubActionItem(
        key: const Key('hub_question_mapping_action'),
        title: 'Question / Chapter Mapping',
        subtitle: 'Question & Chapter Accuracy',
        icon: Icons.account_tree_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => _scrollToSection('chapter'),
      ),
      _ExamHubActionItem(
        key: const Key('hub_academic_analytics_action'),
        title: 'Academic Analytics',
        subtitle: 'Forecasts & Risk Trajectories',
        icon: Icons.auto_graph_rounded,
        color: const Color(0xFF0D9488),
        onTap: () => _scrollToSection('analytics'),
      ),
    ];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.assessment_outlined, size: 18, color: Color(0xFF0F766E)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Exams & Assessments Hub',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'Comprehensive Academic Operations',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final colCount = width >= 1100 ? 4 : (width >= 600 ? 2 : 1);
                final itemWidth = (width - ((colCount - 1) * 12)) / colCount;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: actions.map((item) {
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        key: item.key,
                        onTap: item.onTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: item.color.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(item.icon, size: 20, color: item.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }

  Widget _buildResultReadinessCard(
    BuildContext context,
    ResultsFiltersState filters,
    String schoolId,
  ) {
    final theme = Theme.of(context);
    final readinessAsync = ref.watch(resultsReadinessProvider);
    final operationsState = ref.watch(reportCardOperationsProvider);

    if (filters.examinationId == null || filters.examinationId!.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select an Examination Cycle in the filters above to evaluate result readiness and publish results.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return readinessAsync.when(
      loading: () => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Evaluating examination results readiness & completion...'),
              ],
            ),
          ),
        ),
      ),
      error: (err, _) => Card(
        color: theme.colorScheme.errorContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unable to load result readiness: $err',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(resultsReadinessProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (readiness) {
        if (readiness == null) return const SizedBox.shrink();

        final isPublished = readiness.isFullyPublished || readiness.publicationStatus == 'PUBLISHED';
        final isReady = readiness.isReadyToPublish;
        final hasIncomplete = readiness.studentsWithIncompleteResults > 0;

        Color badgeColor;
        Color badgeTextColor;
        String badgeText;
        IconData badgeIcon;

        if (isPublished) {
          badgeColor = const Color(0xFFDCFCE7);
          badgeTextColor = const Color(0xFF15803D);
          badgeText = 'PUBLISHED';
          badgeIcon = Icons.check_circle;
        } else if (isReady) {
          badgeColor = const Color(0xFFCCFBF1);
          badgeTextColor = const Color(0xFF0F766E);
          badgeText = 'READY TO PUBLISH';
          badgeIcon = Icons.send;
        } else {
          badgeColor = const Color(0xFFFEF3C7);
          badgeTextColor = const Color(0xFFB45309);
          badgeText = 'INCOMPLETE DATA';
          badgeIcon = Icons.warning_amber_rounded;
        }

        final pubDateDisplay = readiness.lastPublishedDate != null
            ? (readiness.lastPublishedDate!.contains('T')
                ? readiness.lastPublishedDate!.split('T').first
                : readiness.lastPublishedDate)
            : null;

        return Card(
          key: const Key('result_readiness_status_card'),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isPublished
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : (isReady ? const Color(0xFF0F766E).withValues(alpha: 0.4) : theme.colorScheme.outlineVariant),
              width: (isPublished || isReady) ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(badgeIcon, color: badgeTextColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Results Readiness & Publication Status',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: badgeTextColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(badgeIcon, size: 14, color: badgeTextColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeText,
                                      style: TextStyle(
                                        color: badgeTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cycle: ${readiness.examinationName}'
                            '${readiness.className != null ? ' • Class: ${readiness.className}' : ''}'
                            '${readiness.sectionName != null ? ' (${readiness.sectionName})' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (pubDateDisplay != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Last Published: $pubDateDisplay by ${readiness.publishedByName ?? 'Administrator'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final colCount = width > 900 ? 6 : (width > 600 ? 3 : 2);
                    final metricWidth = (width - ((colCount - 1) * 12)) / colCount;

                    final metricItems = [
                      _buildReadinessMetric('Total Students', '${readiness.totalStudents}', Icons.people_outline, theme.colorScheme.primary),
                      _buildReadinessMetric('Complete Results', '${readiness.studentsWithCompleteResults}', Icons.check_circle_outline, Colors.green),
                      _buildReadinessMetric('Incomplete Results', '${readiness.studentsWithIncompleteResults}', Icons.pending_actions_outlined, hasIncomplete ? Colors.amber.shade900 : Colors.grey),
                      _buildReadinessMetric('Draft Results', '${readiness.draftResultsCount}', Icons.edit_note, Colors.orange),
                      _buildReadinessMetric('Ready to Publish', '${readiness.readyToPublishCount}', Icons.schedule_send, const Color(0xFF0F766E)),
                      _buildReadinessMetric('Published', '${readiness.publishedCount}', Icons.verified, const Color(0xFF15803D)),
                    ];

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: metricItems.map((m) => SizedBox(width: metricWidth, child: m)).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Advisory Message Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? const Color(0xFFF0FDF4)
                        : (isReady ? const Color(0xFFF0FDFA) : const Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPublished
                          ? const Color(0xFF86EFAC)
                          : (isReady ? const Color(0xFF99F6E4) : const Color(0xFFFDE68A)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPublished ? Icons.info_outline : (isReady ? Icons.check_circle_outline : Icons.warning_amber_rounded),
                        color: isPublished ? const Color(0xFF15803D) : (isReady ? const Color(0xFF0F766E) : const Color(0xFFB45309)),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          readiness.statusMessage.isNotEmpty
                              ? readiness.statusMessage
                              : (isPublished
                                  ? 'Examination marks are published and currently visible to students and parents.'
                                  : (isReady
                                      ? 'All student marks have been entered and approved. Ready to publish.'
                                      : '${readiness.studentsWithIncompleteResults} students remain incomplete. Complete all required marks before publishing.')),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isPublished ? const Color(0xFF15803D) : (isReady ? const Color(0xFF0F766E) : const Color(0xFF92400E)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Bar
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('readiness_review_results_btn'),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text(isPublished ? 'View Published Results' : 'Review Results'),
                      onPressed: () => _scrollToSection('roster'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('readiness_manage_marks_btn'),
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: const Text('Manage Marks'),
                      onPressed: () {
                        final qParams = <String, String>{
                          'exam_id': readiness.examinationId,
                          if (readiness.classId != null) 'class_id': readiness.classId!,
                          if (readiness.sectionId != null) 'section_id': readiness.sectionId!,
                          if (readiness.academicYearId != null) 'ay_id': readiness.academicYearId!,
                        };
                        context.push(Uri(path: AppRoutes.marksManagement, queryParameters: qParams).toString());
                      },
                    ),
                    if (hasIncomplete) ...[
                      OutlinedButton.icon(
                        key: const Key('readiness_resolve_missing_btn'),
                        icon: const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFB45309)),
                        label: const Text('Resolve Missing Data', style: TextStyle(color: Color(0xFFB45309))),
                        onPressed: () {
                          final qParams = <String, String>{
                            'exam_id': readiness.examinationId,
                            if (readiness.classId != null) 'class_id': readiness.classId!,
                            if (readiness.sectionId != null) 'section_id': readiness.sectionId!,
                            if (readiness.academicYearId != null) 'ay_id': readiness.academicYearId!,
                          };
                          context.push(Uri(path: AppRoutes.marksImport, queryParameters: qParams).toString());
                        },
                      ),
                    ],
                    if (!isPublished) ...[
                      Tooltip(
                        message: isReady
                            ? 'Publish all marks for this examination cycle'
                            : '${readiness.studentsWithIncompleteResults} students remain incomplete. Complete all required marks before publishing.',
                        child: FilledButton.icon(
                          key: const Key('readiness_publish_results_btn'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                          ),
                          icon: operationsState.isLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.publish, size: 16),
                          label: const Text('Publish Results'),
                          onPressed: (isReady && !operationsState.isLoading)
                              ? () => _showPublishConfirmationDialog(context, readiness, schoolId)
                              : null,
                        ),
                      ),
                    ] else ...[
                      if (readiness.canUnpublish) ...[
                        OutlinedButton.icon(
                          key: const Key('readiness_unpublish_results_btn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          icon: operationsState.isLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                              : const Icon(Icons.undo, size: 16),
                          label: const Text('Unpublish / Reopen'),
                          onPressed: operationsState.isLoading
                              ? null
                              : () => _showUnpublishConfirmationDialog(context, readiness, schoolId),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadinessMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishConfirmationDialog(
    BuildContext context,
    ExaminationResultReadinessDto readiness,
    String schoolId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.publish, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Publish Examination Results'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to publish examination results for:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Examination: ${readiness.examinationName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (readiness.className != null)
                    Text('• Class: ${readiness.className} ${readiness.sectionName ?? ""}'),
                  Text('• Verified Students: ${readiness.studentsWithCompleteResults}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Publishing will immediately make these marks, grades, and report cards visible to parents and students in their respective applications.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_publish_dialog_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              final success = await ref
                  .read(reportCardOperationsProvider.notifier)
                  .publishExaminationResults(
                    examId: readiness.examinationId,
                    schoolId: schoolId,
                    classId: readiness.classId,
                    sectionId: readiness.sectionId,
                  );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Results published successfully! Parents and students can now view results.'
                        : 'Failed to publish results.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Publish Results Now'),
          ),
        ],
      ),
    );
  }

  void _showUnpublishConfirmationDialog(
    BuildContext context,
    ExaminationResultReadinessDto readiness,
    String schoolId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
            const SizedBox(width: 8),
            const Text('Unpublish Examination Results?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to unpublish results for ${readiness.examinationName}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_reset, size: 20, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unpublishing will revoke result visibility from Parent and Student portals. Marks will be reopened for staff to update or edit.',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_unpublish_dialog_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              final success = await ref
                  .read(reportCardOperationsProvider.notifier)
                  .unpublishExaminationResults(
                    examId: readiness.examinationId,
                    schoolId: schoolId,
                    classId: readiness.classId,
                    sectionId: readiness.sectionId,
                  );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Results unpublished and reopened for editing.'
                        : 'Failed to unpublish results.'),
                    backgroundColor: success ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Unpublish & Reopen'),
          ),
        ],
      ),
    );
  }
}

class _ExamHubActionItem {
  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExamHubActionItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
