import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_form_dialog.dart';

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(guardianListProvider.notifier).updateFilters(search: val.trim());
  }

  void _onStatusChanged(String? val) {
    ref.read(guardianListProvider.notifier).updateFilters(status: val == 'ALL' ? null : val);
  }

  Future<void> _deleteGuardian(String id, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Guardian'),
        content: const Text('Are you sure you want to deactivate/soft-delete this guardian profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_guardian_btn'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(guardianActionsProvider.notifier).execute(
            method: 'DELETE',
            path: '/guardians/$id?school_id=$schoolId',
            successMsg: 'Guardian deactivated successfully.',
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian deactivated successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final listState = ref.watch(guardianListProvider);
    final actionState = ref.watch(guardianActionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Registry'),
        actions: [
          if (schoolId != null)
            ElevatedButton.icon(
              key: const Key('add_guardian_btn'),
              icon: const Icon(Icons.add),
              label: const Text('Add Guardian'),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const GuardianFormDialog(),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: schoolId == null
          ? const Center(child: Text('Please select a school campus first.'))
          : Column(
              children: [
                // Filter Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 250,
                            child: TextField(
                              controller: _searchController,
                              key: const Key('guardian_search_field'),
                              decoration: const InputDecoration(
                                labelText: 'Search Guardians',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              key: const Key('guardian_status_filter'),
                              value: listState.status ?? 'ALL',
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All')),
                                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                              ],
                              onChanged: _onStatusChanged,
                            ),
                          ),
                          IconButton(
                            key: const Key('guardian_refresh_btn'),
                            icon: const Icon(Icons.refresh),
                            onPressed: () => ref.read(guardianListProvider.notifier).fetchGuardians(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Table or List Views
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (listState.isLoading && listState.guardians.isEmpty) {
                        return const Center(child: CircularProgressIndicator(key: Key('guardian_loading_indicator')));
                      }

                      if (listState.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(listState.error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                key: const Key('guardian_retry_btn'),
                                onPressed: () => ref.read(guardianListProvider.notifier).fetchGuardians(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (listState.guardians.isEmpty) {
                        return const Center(
                          key: Key('guardian_empty_state'),
                          child: Text('No guardian records found.'),
                        );
                      }

                      return isMobile
                          ? ListView.builder(
                              itemCount: listState.guardians.length,
                              itemBuilder: (context, idx) {
                                final g = listState.guardians[idx];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text('${g.firstName} ${g.lastName}'),
                                    subtitle: Text('Type: ${g.guardianType}\nMobile: ${g.mobile}\nLogin ID: ${g.loginId ?? "N/A"}'),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'view') {
                                          context.go('${AppRoutes.guardians}/${g.id}');
                                        } else if (action == 'edit') {
                                          showDialog(
                                            context: context,
                                            builder: (context) => GuardianFormDialog(guardian: g),
                                          );
                                        } else if (action == 'delete') {
                                          _deleteGuardian(g.id, schoolId);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'view', child: Text('View Details')),
                                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                        const PopupMenuItem(value: 'delete', child: Text('Deactivate')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        key: const Key('guardian_data_table'),
                                        columns: const [
                                          DataColumn(label: Text('Name')),
                                          DataColumn(label: Text('Parent Login ID')),
                                          DataColumn(label: Text('Guardian Type')),
                                          DataColumn(label: Text('Mobile')),
                                          DataColumn(label: Text('Email')),
                                          DataColumn(label: Text('Occupation')),
                                          DataColumn(label: Text('Status')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: listState.guardians.map((g) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text('${g.firstName} ${g.lastName}')),
                                              DataCell(Text(g.loginId ?? 'N/A')),
                                              DataCell(Text(g.guardianType)),
                                              DataCell(Text(g.mobile)),
                                              DataCell(Text(g.email ?? 'N/A')),
                                              DataCell(Text(g.occupation ?? 'N/A')),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: g.status == 'ACTIVE' ? Colors.green.shade50 : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    g.status,
                                                    style: TextStyle(
                                                      color: g.status == 'ACTIVE' ? Colors.green.shade800 : Colors.red.shade800,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      key: Key('view_guardian_${g.id}'),
                                                      icon: const Icon(Icons.visibility),
                                                      onPressed: () => context.go('${AppRoutes.guardians}/${g.id}'),
                                                    ),
                                                    IconButton(
                                                      key: Key('edit_guardian_${g.id}'),
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () => showDialog(
                                                        context: context,
                                                        builder: (context) => GuardianFormDialog(guardian: g),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      key: Key('delete_guardian_${g.id}'),
                                                      icon: const Icon(Icons.delete),
                                                      onPressed: () => _deleteGuardian(g.id, schoolId),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  // Pagination footer
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('Page ${listState.skip ~/ listState.limit + 1}'),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: listState.skip == 0 ? null : () => ref.read(guardianListProvider.notifier).prevPage(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: !listState.hasMore ? null : () => ref.read(guardianListProvider.notifier).nextPage(),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
