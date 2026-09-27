import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_form_dialog.dart';

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  final _searchController = TextEditingController();
  final _hScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _hScrollController.dispose();
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
        ref.read(guardianListProvider.notifier).fetchGuardians();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian deactivated successfully.')),
        );
      }
    }
  }

  Future<void> _resetGuardianPassword(GuardianDto guardian, String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Are you sure you want to reset credentials for ${guardian.fullName} (${guardian.mobile})? A temporary password will be generated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      String? tempPassword;

      if (guardian.userId != null) {
        final res = await apiClient.post(
          '/identity/users/${guardian.userId}/reset-password',
          mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
        );
        res.when(
          onSuccess: (data) => tempPassword = data?['temporary_password'] as String?,
          onFailure: (err) => throw Exception(err.message),
        );
      } else {
        final provRes = await apiClient.post(
          '/identity/provision/guardian/${guardian.id}?school_id=$schoolId',
          mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
        );
        String? newUserId;
        provRes.when(
          onSuccess: (data) => newUserId = data?['id'] as String?,
          onFailure: (err) => throw Exception(err.message),
        );

        if (newUserId != null) {
          final res = await apiClient.post(
            '/identity/users/$newUserId/reset-password',
            mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
          );
          res.when(
            onSuccess: (data) => tempPassword = data?['temporary_password'] as String?,
            onFailure: (err) => throw Exception(err.message),
          );
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Password Reset Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guardian: ${guardian.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Mobile / Login ID: ${guardian.loginId ?? guardian.mobile}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        tempPassword ?? 'EduPulse@123',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tempPassword ?? 'EduPulse@123'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Temporary password copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share this temporary password with the parent/guardian. They must update it on first sign-in.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final listState = ref.watch(guardianListProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

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
              ).then((updated) {
                if (updated == true) {
                  ref.read(guardianListProvider.notifier).fetchGuardians();
                }
              }),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: listState.guardians.length,
                              itemBuilder: (context, idx) {
                                final g = listState.guardians[idx];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    child: Text(
                                                      g.firstName.isNotEmpty ? g.firstName[0].toUpperCase() : 'G',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '${g.firstName} ${g.lastName}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          'Type: ${g.guardianType}${g.loginId != null ? " • Login ID: ${g.loginId}" : ""}',
                                                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: g.status == 'ACTIVE' ? Colors.green.shade50 : Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: g.status == 'ACTIVE' ? Colors.green.shade200 : Colors.red.shade200,
                                                ),
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
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text('📞 ${g.mobile}  •  ✉️ ${g.email ?? "N/A"}${g.occupation != null ? "  •  💼 ${g.occupation}" : ""}',
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        const Divider(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              key: Key('view_guardian_${g.id}'),
                                              icon: const Icon(Icons.visibility_outlined, size: 16),
                                              label: const Text('View'),
                                              onPressed: () => context.go('${AppRoutes.guardians}/${g.id}'),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              key: Key('edit_guardian_${g.id}'),
                                              icon: const Icon(Icons.edit_outlined, size: 16),
                                              label: const Text('Edit'),
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (context) => GuardianFormDialog(guardian: g),
                                              ).then((updated) {
                                                if (updated == true) {
                                                  ref.read(guardianListProvider.notifier).fetchGuardians();
                                                }
                                              }),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              key: Key('reset_pwd_${g.id}'),
                                              icon: const Icon(Icons.lock_reset, size: 20),
                                              tooltip: 'Reset Password',
                                              onPressed: () => _resetGuardianPassword(g, schoolId),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              key: Key('delete_guardian_${g.id}'),
                                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                              tooltip: 'Deactivate',
                                              onPressed: () => _deleteGuardian(g.id, schoolId),
                                            ),
                                          ],
                                        ),
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
                                    child: Scrollbar(
                                      controller: _hScrollController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _hScrollController,
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
                                                DataCell(
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 160),
                                                    child: Text(
                                                      '${g.firstName} ${g.lastName}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(Text(g.loginId ?? 'N/A')),
                                                DataCell(Text(g.guardianType)),
                                                DataCell(Text(g.mobile)),
                                                DataCell(
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 180),
                                                    child: Text(g.email ?? 'N/A', overflow: TextOverflow.ellipsis),
                                                  ),
                                                ),
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
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        key: Key('view_guardian_${g.id}'),
                                                        icon: const Icon(Icons.visibility_outlined, size: 20),
                                                        tooltip: 'View Profile',
                                                        onPressed: () => context.go('${AppRoutes.guardians}/${g.id}'),
                                                      ),
                                                      IconButton(
                                                        key: Key('edit_guardian_${g.id}'),
                                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                                        tooltip: 'Edit Profile',
                                                        onPressed: () => showDialog(
                                                          context: context,
                                                          builder: (context) => GuardianFormDialog(guardian: g),
                                                        ).then((updated) {
                                                          if (updated == true) {
                                                            ref.read(guardianListProvider.notifier).fetchGuardians();
                                                          }
                                                        }),
                                                      ),
                                                      IconButton(
                                                        key: Key('reset_pwd_${g.id}'),
                                                        icon: const Icon(Icons.lock_reset, size: 20),
                                                        tooltip: 'Reset Password',
                                                        onPressed: () => _resetGuardianPassword(g, schoolId),
                                                      ),
                                                      IconButton(
                                                        key: Key('delete_guardian_${g.id}'),
                                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                                        tooltip: 'Deactivate',
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
