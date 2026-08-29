import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class AcademicYearsScreen extends ConsumerStatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  ConsumerState<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends ConsumerState<AcademicYearsScreen> {
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
        ref.read(academicYearsProvider(next).notifier).fetchYears();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Academic Calendar')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its academic years.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(academicYearsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.schools}/$schoolId/academic-years/new');
          _refreshData();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Academic Year'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.error}', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : state.years.isEmpty
                  ? const Center(child: Text('No academic years registered for this campus yet.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Years Calendar',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: isMobile
                                ? _buildMobileList(state.years, schoolId, theme)
                                : _buildDesktopTable(state.years, schoolId, theme),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMobileList(List<dynamic> years, String schoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: years.length,
      itemBuilder: (context, index) {
        final ay = years[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: ay.isCurrent ? 2 : 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: ay.isCurrent ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: ay.isCurrent ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.schools}/$schoolId/academic-years/${ay.id}');
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
                        ay.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (ay.isCurrent) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _buildStatusChip(ay.status, theme),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${ay.code}', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Duration: ${ay.startDate} to ${ay.endDate}', style: theme.textTheme.bodySmall),
                  if (ay.description != null && ay.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(ay.description!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> years, String schoolId, ThemeData theme) {
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
            DataColumn(label: Text('Calendar Year')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Start Date')),
            DataColumn(label: Text('End Date')),
            DataColumn(label: Text('Current')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: years.map((ay) {
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.schools}/$schoolId/academic-years/${ay.id}');
                      _refreshData();
                    },
                    child: Text(
                      ay.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(ay.code)),
                DataCell(Text(ay.startDate)),
                DataCell(Text(ay.endDate)),
                DataCell(
                  Icon(
                    ay.isCurrent ? Icons.check_circle : Icons.circle_outlined,
                    color: ay.isCurrent ? theme.colorScheme.primary : null,
                  ),
                ),
                DataCell(_buildStatusChip(ay.status, theme)),
                DataCell(
                  IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await context.push('${AppRoutes.schools}/$schoolId/academic-years/${ay.id}');
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
      case 'UPCOMING':
        color = Colors.blue;
        break;
      case 'COMPLETED':
        color = Colors.grey;
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
