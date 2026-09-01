import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

class ReportCardManagementScreen extends ConsumerStatefulWidget {
  const ReportCardManagementScreen({super.key});

  @override
  ConsumerState<ReportCardManagementScreen> createState() => _ReportCardManagementScreenState();
}

class _ReportCardManagementScreenState extends ConsumerState<ReportCardManagementScreen> {
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
      case 'LOCKED':
        color = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        break;
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

  void _showActionFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleBulkGenerate(String classId, String sectionId, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Generate Report Cards'),
        content: const Text(
          'Are you sure you want to bulk generate report cards for the selected class and section? '
          'This will compile student grades and attendance details.',
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
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(reportCardOperationsProvider.notifier);
    final success = await notifier.bulkGenerate(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
    );

    if (success) {
      final state = ref.read(reportCardOperationsProvider);
      final result = state.bulkGenerateResult;
      if (result != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Generation Result'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Students Checked: ${result.totalStudents}'),
                  Text('Successfully Generated: ${result.generatedCount}'),
                  Text('Failed: ${result.failedCount}'),
                  if (result.failures.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Failure Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    ...result.failures.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '• ${f.studentName}: ${f.reasons.join(", ")}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        )),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk generation failed', isError: true);
    }
  }

  Future<void> _handleBulkPublish(String classId, String sectionId, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Publish Report Cards'),
        content: const Text(
          'Are you sure you want to publish all APPROVED report cards for this class and section? '
          'Once published, they will become visible to parents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(reportCardOperationsProvider.notifier).publish(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
    );

    if (success) {
      _showActionFeedback('Approved report cards published successfully.');
    } else {
      final state = ref.read(reportCardOperationsProvider);
      _showActionFeedback(state.error ?? 'Bulk publication failed', isError: true);
    }
  }

  Future<void> _showVerificationDialog(String uuid) async {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final verifyAsync = ref.watch(reportCardVerificationProvider(uuid));
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text('Signature Verification'),
              ],
            ),
            content: verifyAsync.when(
              data: (data) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✓ Digitally Signed & Authenticated',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text('Student: ${data.studentName} (Roll: ${data.rollNumber})'),
                  Text('Class & Section: ${data.className} - ${data.sectionName}'),
                  Text('Academic Year: ${data.academicYear}'),
                  Text('Status: ${data.status.toUpperCase()}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Verification UUID:\n$uuid',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  if (data.generatedAt != null)
                    Text('Signed Date: ${data.generatedAt}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text(
                'Failed to verify signature authenticity: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Card Management')),
        body: const Center(child: Text('Please select a school to proceed.')),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));
    final filters = ref.watch(resultsFiltersProvider);
    final filtersNotifier = ref.read(resultsFiltersProvider.notifier);

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

    // Schedule asynchronous reset of invalid filter states after UI frame
    if ((filters.academicYearId != null && validAyId == null) ||
        (filters.classId != null && validClassId == null) ||
        (filters.sectionId != null && validSectionId == null)) {
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
      });
    }

    final studentsAsync = ref.watch(resultsStudentsProvider);
    final cardsAsync = ref.watch(resultsReportCardsProvider);
    final opsState = ref.watch(reportCardOperationsProvider);

    // Filter defaults fallback if empty or invalid
    if (uniqueYears.isNotEmpty && validAyId == null) {
      final current = uniqueYears.firstWhere((y) => y.isCurrent, orElse: () => uniqueYears.first);
      Future.microtask(() => filtersNotifier.setAcademicYear(current.id));
    }
    if (uniqueClasses.isNotEmpty && validClassId == null) {
      Future.microtask(() => filtersNotifier.setClass(uniqueClasses.first.id));
    }
    if (uniqueSections.isNotEmpty && validClassId != null && validSectionId == null) {
      Future.microtask(() => filtersNotifier.setSection(uniqueSections.first.id));
    }

    // Derive summary metrics from rosters list
    int totalCount = 0;
    int notGeneratedCount = 0;
    int draftCount = 0;
    int underReviewCount = 0;
    int approvedCount = 0;
    int publishedCount = 0;
    int lockedCount = 0;

    if (studentsAsync.hasValue && cardsAsync.hasValue) {
      final students = studentsAsync.value ?? const [];
      final cards = cardsAsync.value ?? const [];
      totalCount = students.length;

      for (final s in students) {
        final card = cards.firstWhere((c) => c.studentId == s.id, orElse: () => const ReportCardDto(
          id: '',
          verificationUuid: '',
          status: 'NOT GENERATED',
          pdfHistory: [],
          tenantId: '',
          schoolId: '',
          academicYearId: '',
          studentId: '',
          aiMetrics: {},
        ));

        if (card.id.isEmpty) {
          notGeneratedCount++;
        } else {
          switch (card.status.toUpperCase()) {
            case 'DRAFT':
              draftCount++;
              break;
            case 'UNDER_REVIEW':
              underReviewCount++;
              break;
            case 'APPROVED':
              approvedCount++;
              break;
            case 'PUBLISHED':
              publishedCount++;
              break;
            case 'LOCKED':
              lockedCount++;
              break;
          }
        }
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Card Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(resultsStudentsProvider);
              ref.invalidate(resultsReportCardsProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top filter card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.filter_list, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select Class & Roster View',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final colCount = width > 900 ? 3 : (width > 600 ? 2 : 1);
                            final itemWidth = width / colCount - 16;

                            final dropdowns = [
                              DropdownButtonFormField<String>(
                                key: const Key('filter_academic_year'),
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
                              DropdownButtonFormField<String>(
                                key: const Key('filter_class'),
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
                              DropdownButtonFormField<String>(
                                key: const Key('filter_section'),
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
                                children: dropdowns
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
                                children: dropdowns
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

                // Operational summaries section
                if (studentsAsync.hasValue && cardsAsync.hasValue) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final double childWidth = width > 1200
                          ? (width - 64) / 5
                          : (width > 800 ? (width - 32) / 3 : (width > 600 ? (width - 16) / 2 : width));

                      final statsCards = [
                        _buildStatCard(
                          context,
                          title: 'Total Students',
                          value: totalCount.toString(),
                          icon: Icons.people_outline,
                          color: theme.colorScheme.primary,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Not Generated (Derived)',
                          value: notGeneratedCount.toString(),
                          icon: Icons.assignment_late_outlined,
                          color: Colors.red,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Draft (Derived)',
                          value: draftCount.toString(),
                          icon: Icons.edit_note,
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Under Review (Derived)',
                          value: underReviewCount.toString(),
                          icon: Icons.rate_review_outlined,
                          color: Colors.amber,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Approved (Derived)',
                          value: approvedCount.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Published (Derived)',
                          value: publishedCount.toString(),
                          icon: Icons.publish_outlined,
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Locked (Derived)',
                          value: lockedCount.toString(),
                          icon: Icons.lock_outline,
                          color: Colors.purple,
                        ),
                      ];

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: statsCards
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

                // Action panel & DataTable
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bulk operation actions buttons row
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Text(
                              'Bulk Operations',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (filters.classId != null && filters.sectionId != null)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  ElevatedButton.icon(
                                    key: const Key('btn_bulk_generate'),
                                    onPressed: () => _handleBulkGenerate(
                                      filters.classId!,
                                      filters.sectionId!,
                                      schoolId,
                                    ),
                                    icon: const Icon(Icons.flash_on),
                                    label: const Text('Generate Class Cards'),
                                  ),
                                  ElevatedButton.icon(
                                    key: const Key('btn_bulk_publish'),
                                    onPressed: approvedCount > 0
                                        ? () => _handleBulkPublish(
                                              filters.classId!,
                                              filters.sectionId!,
                                              schoolId,
                                            )
                                        : null,
                                    icon: const Icon(Icons.publish),
                                    label: const Text('Publish Approved'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Search Bar
                        TextField(
                          key: const Key('search_bar_input'),
                          decoration: const InputDecoration(
                            hintText: 'Search student roll, name or admission number...',
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 16),

                        // Students Roster table listing
                        studentsAsync.when(
                          data: (List<StudentDto> students) {
                            if (students.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text('No students found for this class and section selection.'),
                                ),
                              );
                            }

                            return cardsAsync.when(
                              data: (List<ReportCardDto> cards) {
                                final filtered = students.where((st) {
                                  final name = '${st.firstName} ${st.lastName}'.toLowerCase();
                                  final roll = st.rollNumber.toLowerCase();
                                  final adm = st.admissionNumber.toLowerCase();
                                  final query = _searchQuery.toLowerCase();
                                  return name.contains(query) || roll.contains(query) || adm.contains(query);
                                }).toList();

                                if (filtered.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text('No students matches the query.'),
                                    ),
                                  );
                                }

                                if (isMobile) {
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const Divider(),
                                    itemBuilder: (context, idx) {
                                      final s = filtered[idx];
                                      final card = cards.firstWhere(
                                        (c) => c.studentId == s.id,
                                        orElse: () => ReportCardDto(
                                          id: '',
                                          verificationUuid: '',
                                          status: 'NOT GENERATED',
                                          pdfHistory: const [],
                                          tenantId: '',
                                          schoolId: '',
                                          academicYearId: '',
                                          studentId: s.id,
                                          aiMetrics: const {},
                                        ),
                                      );

                                      return ListTile(
                                        title: Text('${s.rollNumber}. ${s.firstName} ${s.lastName}'),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Adm No: ${s.admissionNumber}'),
                                            const SizedBox(height: 4),
                                            _buildStatusBadge(card.status),
                                          ],
                                        ),
                                        trailing: _buildPopupMenuButton(card, s, schoolId),
                                      );
                                    },
                                  );
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Roll No')),
                                      DataColumn(label: Text('Admission No')),
                                      DataColumn(label: Text('Student Name')),
                                      DataColumn(label: Text('Class & Section')),
                                      DataColumn(label: Text('Report Card Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: filtered.map((s) {
                                      final card = cards.firstWhere(
                                        (c) => c.studentId == s.id,
                                        orElse: () => ReportCardDto(
                                          id: '',
                                          verificationUuid: '',
                                          status: 'NOT GENERATED',
                                          pdfHistory: const [],
                                          tenantId: '',
                                          schoolId: '',
                                          academicYearId: '',
                                          studentId: s.id,
                                          aiMetrics: const {},
                                        ),
                                      );

                                      final className = classState.classes
                                          .firstWhere((c) => c.id == s.classId,
                                              orElse: () => classState.classes.first)
                                          .name;
                                      final secName = sectionState.sections
                                          .firstWhere((sec) => sec.id == s.sectionId,
                                              orElse: () => sectionState.sections.first)
                                          .name;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(s.rollNumber)),
                                          DataCell(Text(s.admissionNumber)),
                                          DataCell(Text('${s.firstName} ${s.lastName}')),
                                          DataCell(Text('$className - $secName')),
                                          DataCell(_buildStatusBadge(card.status)),
                                          DataCell(_buildPopupMenuButton(card, s, schoolId)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Text('Error loading cards: $err'),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Column(
                            children: [
                              Text('Error: $err'),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (opsState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopupMenuButton(ReportCardDto card, StudentDto s, String schoolId) {
    final status = card.status.toUpperCase();
    final hasCard = card.id.isNotEmpty;

    return PopupMenuButton<String>(
      key: Key('actions_menu_${s.id}'),
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        final ops = ref.read(reportCardOperationsProvider.notifier);
        bool res = false;
        String successText = '';

        if (value == 'view') {
          context.push('/results/report-cards/${s.id}');
          return;
        }

        switch (value) {
          case 'generate':
            res = await ops.generateSingle(studentId: s.id, schoolId: schoolId);
            successText = 'Report card generated successfully.';
            break;
          case 'submit_review':
            res = await ops.submitForReview(id: card.id, schoolId: schoolId);
            successText = 'Report card submitted for review.';
            break;
          case 'approve':
            res = await ops.approve(id: card.id, schoolId: schoolId);
            successText = 'Report card approved successfully.';
            break;
          case 'publish':
            final filters = ref.read(resultsFiltersProvider);
            if (filters.classId != null && filters.sectionId != null) {
              res = await ops.publish(
                classId: filters.classId!,
                sectionId: filters.sectionId!,
                schoolId: schoolId,
              );
              successText = 'Approved report cards published.';
            }
            break;
          case 'lock':
            res = await ops.lock(id: card.id, schoolId: schoolId);
            successText = 'Report card frozen successfully.';
            break;
          case 'unlock':
            res = await ops.unlock(id: card.id, schoolId: schoolId);
            successText = 'Report card unlocked.';
            break;
          case 'download_pdf':
            res = await ops.downloadPdf(
              studentId: s.id,
              schoolId: schoolId,
              studentName: '${s.firstName} ${s.lastName}',
            );
            successText = 'PDF downloaded.';
            break;
          case 'view_pdf':
            res = await ops.viewPdf(studentId: s.id, schoolId: schoolId);
            successText = 'PDF loaded in viewer.';
            break;
          case 'verify':
            if (card.verificationUuid.isNotEmpty) {
              await _showVerificationDialog(card.verificationUuid);
            }
            return;
        }

        if (res) {
          _showActionFeedback(successText);
        } else {
          final state = ref.read(reportCardOperationsProvider);
          _showActionFeedback(state.error ?? 'Action execution failed', isError: true);
        }
      },
      itemBuilder: (context) {
        return [
          // View details is always available if card is generated
          if (hasCard)
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View Details'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!hasCard)
            const PopupMenuItem(
              value: 'generate',
              child: ListTile(
                leading: Icon(Icons.flash_on),
                title: Text('Generate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'DRAFT') ...[
            const PopupMenuItem(
              value: 'submit_review',
              child: ListTile(
                leading: Icon(Icons.rate_review),
                title: Text('Submit Review'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'generate',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Regenerate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (status == 'UNDER_REVIEW')
            const PopupMenuItem(
              value: 'approve',
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Approve'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'APPROVED')
            const PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: Icon(Icons.publish),
                title: Text('Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (status == 'PUBLISHED') ...[
            const PopupMenuItem(
              value: 'lock',
              child: ListTile(
                leading: Icon(Icons.lock),
                title: Text('Lock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'download_pdf',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('View PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'verify',
              child: ListTile(
                leading: Icon(Icons.verified),
                title: Text('Verify Signature'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (status == 'LOCKED') ...[
            const PopupMenuItem(
              value: 'unlock',
              child: ListTile(
                leading: Icon(Icons.lock_open),
                title: Text('Unlock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'download_pdf',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('View PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'verify',
              child: ListTile(
                leading: Icon(Icons.verified),
                title: Text('Verify Signature'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ];
      },
    );
  }
}
