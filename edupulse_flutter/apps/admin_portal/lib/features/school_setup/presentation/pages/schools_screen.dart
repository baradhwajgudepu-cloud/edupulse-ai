import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/school_setup_providers.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/routing/routes.dart';
import '../widgets/quick_school_onboarding_dialog.dart';

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
          await QuickSchoolOnboardingDialog.show(context);
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.school_outlined, size: 48, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No School Campuses Registered Yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Onboard your school in seconds with minimal setup and configure ERP modules progressively.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await QuickSchoolOnboardingDialog.show(context);
                              ref.read(schoolsListProvider.notifier).fetchSchools();
                            },
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Create School'),
                          ),
                        ],
                      ),
                    )
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
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(selectedSchoolIdProvider.notifier).state = school.id;
                          ref.read(selectedTenantIdProvider.notifier).state = school.tenantId;
                          context.go(AppRoutes.dashboard);
                        },
                        icon: const Icon(Icons.launch_rounded, size: 14),
                        label: const Text('Open School'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          elevation: 0,
                        ),
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
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(selectedSchoolIdProvider.notifier).state = school.id;
                          ref.read(selectedTenantIdProvider.notifier).state = school.tenantId;
                          context.go(AppRoutes.dashboard);
                        },
                        icon: const Icon(Icons.launch_rounded, size: 14),
                        label: const Text('Open School'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
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
