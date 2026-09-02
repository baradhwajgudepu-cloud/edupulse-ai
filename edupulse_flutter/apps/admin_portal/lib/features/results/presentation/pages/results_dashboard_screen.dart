import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';
import '../../../../core/routing/routes.dart';

class ResultsDashboardScreen extends ConsumerStatefulWidget {
  const ResultsDashboardScreen({super.key});

  @override
  ConsumerState<ResultsDashboardScreen> createState() => _ResultsDashboardScreenState();
}

class _ResultsDashboardScreenState extends ConsumerState<ResultsDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      Future.microtask(() => filtersNotifier.setExamination(uniqueExams.first.id));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results & Report Cards'),
        actions: [
          ElevatedButton.icon(
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(resultsExaminationsProvider);
              ref.invalidate(resultsStudentsProvider);
              ref.invalidate(resultsReportCardsProvider);
              _refreshData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            items: uniqueYears.map((y) {
                              return DropdownMenuItem(
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
                            items: uniqueExams.map((e) {
                              return DropdownMenuItem(
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
                            items: uniqueClasses.map((c) {
                              return DropdownMenuItem(
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
                            items: uniqueSections.map((s) {
                              return DropdownMenuItem(
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

            // Student results roster
            Text(
              'Student Roster Results',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
                                  orElse: () => ReportCardDto(
                                    id: '',
                                    verificationUuid: '',
                                    status: 'NOT GENERATED',
                                    pdfHistory: const [],
                                    tenantId: '',
                                    schoolId: '',
                                    academicYearId: '',
                                    studentId: '',
                                    aiMetrics: const {},
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
                                    orElse: () => ReportCardDto(
                                      id: '',
                                      verificationUuid: '',
                                      status: 'NOT GENERATED',
                                      pdfHistory: const [],
                                      tenantId: '',
                                      schoolId: '',
                                      academicYearId: '',
                                      studentId: '',
                                      aiMetrics: const {},
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
}
