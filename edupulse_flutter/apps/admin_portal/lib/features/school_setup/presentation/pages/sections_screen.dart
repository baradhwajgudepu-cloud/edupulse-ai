import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class SectionsScreen extends ConsumerStatefulWidget {
  const SectionsScreen({super.key});

  @override
  ConsumerState<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends ConsumerState<SectionsScreen> {
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: _selectedClassId);
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
        setState(() => _selectedClassId = null);
        ref.read(classesProvider(next).notifier).fetchClasses();
        ref.read(sectionsProvider(next).notifier).fetchSections(classId: null);
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sections & Classrooms')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its sections.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));

    // Handle initializing selected class context filter
    if (classState.classes.isNotEmpty && _selectedClassId == null) {
      _selectedClassId = classState.classes.first.id;
      Future.microtask(() {
        ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: _selectedClassId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sections & Classrooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.sections}/new?school_id=$schoolId');
          _refreshData();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Section'),
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
                    const Icon(Icons.class_outlined),
                    const SizedBox(width: 12),
                    const Text('Class Scope:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: classState.isLoading
                          ? const LinearProgressIndicator()
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClassId,
                                items: classState.classes.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() => _selectedClassId = v);
                                  ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: v);
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
            child: sectionState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sectionState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${sectionState.error}', style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : sectionState.sections.isEmpty
                        ? const Center(child: Text('No sections registered for this class context yet.'))
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: isMobile
                                ? _buildMobileList(sectionState.sections, schoolId, theme)
                                : _buildDesktopTable(sectionState.sections, schoolId, theme),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> sections, String schoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final sec = sections[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.sections}/${sec.id}?school_id=$schoolId');
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
                        sec.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildStatusChip(sec.status, theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${sec.code}', style: theme.textTheme.bodyMedium),
                  Text('Room Number: ${sec.roomNumber ?? "-"} • Capacity: ${sec.capacity}', style: theme.textTheme.bodyMedium),
                  if (sec.description != null) Text('Description: ${sec.description}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> sections, String schoolId, ThemeData theme) {
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
            DataColumn(label: Text('Section Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Room Number')),
            DataColumn(label: Text('Capacity')),
            DataColumn(label: Text('Sort Order')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: sections.map((sec) {
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.sections}/${sec.id}?school_id=$schoolId');
                      _refreshData();
                    },
                    child: Text(
                      sec.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(sec.code)),
                DataCell(Text(sec.roomNumber ?? '-')),
                DataCell(Text(sec.capacity.toString())),
                DataCell(Text(sec.sortOrder.toString())),
                DataCell(_buildStatusChip(sec.status, theme)),
                DataCell(
                  IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await context.push('${AppRoutes.sections}/${sec.id}?school_id=$schoolId');
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
