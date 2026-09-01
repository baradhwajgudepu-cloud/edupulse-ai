import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
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
        ref.read(classesProvider(schoolId).notifier).fetchClasses(academicYearId: _selectedAyId);
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
        ref.read(classesProvider(next).notifier).fetchClasses(academicYearId: null);
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Classes & Grade Levels')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its classes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));

    // Handle initializing selected academic year
    if (ayState.years.isNotEmpty && _selectedAyId == null) {
      final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      _selectedAyId = current.id;
      // Fetch classes for this year
      Future.microtask(() {
        ref.read(classesProvider(schoolId).notifier).fetchClasses(academicYearId: _selectedAyId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes & Grade Levels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.classes}/new?school_id=$schoolId');
          _refreshData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Class'),
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
                    const Icon(Icons.filter_list),
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
                                    child: Text('${y.name} ${y.isCurrent ? "(Current)" : ""}'),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() => _selectedAyId = v);
                                  ref.read(classesProvider(schoolId).notifier).fetchClasses(academicYearId: v);
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
            child: classState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : classState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${classState.error}', style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : classState.classes.isEmpty
                        ? const Center(child: Text('No classes registered for this academic year yet.'))
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: isMobile
                                ? _buildMobileList(classState.classes, schoolId, theme)
                                : _buildDesktopTable(classState.classes, schoolId, theme),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> classes, String schoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final c = classes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.classes}/${c.id}?school_id=$schoolId');
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
                        c.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      _buildStatusChip(c.status, theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${c.code} • Category: ${c.category}', style: theme.textTheme.bodyMedium),
                  Text('Level: ${c.level} • Max Capacity: ${c.capacity}', style: theme.textTheme.bodyMedium),
                  if (c.stream != null) Text('Stream: ${c.stream}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> classes, String schoolId, ThemeData theme) {
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
            DataColumn(label: Text('Class Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Level')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Stream')),
            DataColumn(label: Text('Capacity')),
            DataColumn(label: Text('Promotion Order')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: classes.map((c) {
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.classes}/${c.id}?school_id=$schoolId');
                      _refreshData();
                    },
                    child: Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(c.code)),
                DataCell(Text(c.level.toString())),
                DataCell(Text(c.category)),
                DataCell(Text(c.stream ?? '-')),
                DataCell(Text(c.capacity.toString())),
                DataCell(Text(c.promotionOrder?.toString() ?? '-')),
                DataCell(_buildStatusChip(c.status, theme)),
                DataCell(
                  IconButton(
                    tooltip: 'Edit class details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await context.push('${AppRoutes.classes}/${c.id}?school_id=$schoolId');
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
