import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class SchoolsScreen extends ConsumerStatefulWidget {
  const SchoolsScreen({super.key});

  @override
  ConsumerState<SchoolsScreen> createState() => _SchoolsScreenState();
}

class _SchoolsScreenState extends ConsumerState<SchoolsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(schoolsListProvider.notifier).fetchSchools();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(schoolsListProvider.notifier).fetchSchools(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.schools}/new');
          ref.read(schoolsListProvider.notifier).fetchSchools();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Campus'),
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
                        onPressed: () => ref.read(schoolsListProvider.notifier).fetchSchools(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : state.schools.isEmpty
                  ? const Center(child: Text('No school campuses registered yet.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Schools (${state.schools.length})',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: isMobile
                                ? _buildMobileList(state.schools, selectedSchoolId, theme)
                                : _buildDesktopTable(state.schools, selectedSchoolId, theme),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMobileList(List<dynamic> schools, String? selectedSchoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: schools.length,
      itemBuilder: (context, index) {
        final school = schools[index];
        final isSelected = school.id == selectedSchoolId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.push('${AppRoutes.schools}/${school.id}');
              ref.read(schoolsListProvider.notifier).fetchSchools();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          school.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildStatusChip(school.status, theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${school.code} • Board: ${school.board}', style: theme.textTheme.bodyMedium),
                  Text('Type: ${school.schoolType}', style: theme.textTheme.bodyMedium),
                  if (school.email.isNotEmpty) Text('Email: ${school.email}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(selectedSchoolIdProvider.notifier).state = school.id;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Active school changed to ${school.name}')),
                          );
                        },
                        icon: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                        label: Text(isSelected ? 'Selected' : 'Select Campus'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: () async {
                          await context.push('${AppRoutes.schools}/${school.id}');
                          ref.read(schoolsListProvider.notifier).fetchSchools();
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<dynamic> schools, String? selectedSchoolId, ThemeData theme) {
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
            DataColumn(label: Text('Campus Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Board')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('UDISE')),
            DataColumn(label: Text('Action')),
          ],
          rows: schools.map((school) {
            final isSelected = school.id == selectedSchoolId;
            return DataRow(
              selected: isSelected,
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.schools}/${school.id}');
                      ref.read(schoolsListProvider.notifier).fetchSchools();
                    },
                    child: Text(
                      school.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(school.code)),
                DataCell(Text(school.board)),
                DataCell(Text(school.schoolType)),
                DataCell(_buildStatusChip(school.status, theme)),
                DataCell(Text(school.udiseCode ?? '-')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Select Campus',
                        icon: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? theme.colorScheme.primary : null),
                        onPressed: () {
                          ref.read(selectedSchoolIdProvider.notifier).state = school.id;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Active school changed to ${school.name}')),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit details',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await context.push('${AppRoutes.schools}/${school.id}');
                          ref.read(schoolsListProvider.notifier).fetchSchools();
                        },
                      ),
                    ],
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
      case 'SUSPENDED':
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
