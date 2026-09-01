import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  String? _selectedAyId;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: _selectedAyId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() => _selectedAyId = null);
        ref.read(academicYearsProvider(next).notifier).fetchYears();
        ref.read(subjectsProvider(next).notifier).fetchSubjects(academicYearId: null);
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subject Catalog')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its subjects.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final subjectState = ref.watch(subjectsProvider(schoolId));

    // Handle initializing selected academic year context filter
    if (ayState.years.isNotEmpty && _selectedAyId == null) {
      final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      _selectedAyId = current.id;
      Future.microtask(() {
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: _selectedAyId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.subjects}/new?school_id=$schoolId');
          _refreshData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Register Subject'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined),
                    const SizedBox(width: 12),
                    const Text('Academic Year:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ayState.isLoading
                          ? const LinearProgressIndicator()
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAyId,
                                items: ayState.years.map((y) {
                                  return DropdownMenuItem(
                                    value: y.id,
                                    child: Text(y.name),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() => _selectedAyId = v);
                                  ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: v);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: subjectState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : subjectState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${subjectState.error}', style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : subjectState.subjects.isEmpty
                        ? const Center(child: Text('No subjects registered for this year yet.'))
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: isMobile
                                ? _buildMobileList(subjectState.subjects, schoolId, theme)
                                : _buildDesktopTable(subjectState.subjects, schoolId, theme),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> subjects, String schoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final sub = subjects[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
              _refreshData();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sub.subjectName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildStatusChip(sub.status, theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${sub.subjectCode} • Short Name: ${sub.shortName ?? "-"}', style: theme.textTheme.bodyMedium),
                  Text('Type: ${sub.subjectType} • Category: ${sub.category}', style: theme.textTheme.bodyMedium),
                  Text('Theory Marks: ${sub.theoryMarks} • Practical Marks: ${sub.practicalMarks} • Pass: ${sub.passMarks}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> subjects, String schoolId, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Subject Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Short Name')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Theory')),
            DataColumn(label: Text('Practical')),
            DataColumn(label: Text('Pass Marks')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: subjects.map((sub) {
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
                      _refreshData();
                    },
                    child: Text(
                      sub.subjectName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(sub.subjectCode)),
                DataCell(Text(sub.shortName ?? '-')),
                DataCell(Text(sub.category)),
                DataCell(Text(sub.subjectType)),
                DataCell(Text(sub.theoryMarks.toString())),
                DataCell(Text(sub.practicalMarks.toString())),
                DataCell(Text(sub.passMarks.toString())),
                DataCell(_buildStatusChip(sub.status, theme)),
                DataCell(
                  IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
                      _refreshData();
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.orange;
        break;
      case 'ARCHIVED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
