import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import '../providers/guardian_providers.dart';

class GuardianDetailsScreen extends ConsumerStatefulWidget {
  final String guardianId;

  const GuardianDetailsScreen({super.key, required this.guardianId});

  @override
  ConsumerState<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends ConsumerState<GuardianDetailsScreen> {
  Future<void> _unlinkStudent(String mappingId, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Student'),
        content: const Text('Are you sure you want to remove this student mapping?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_unlink_student_btn'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(guardianActionsProvider.notifier).execute(
            method: 'DELETE',
            path: '/student-guardians/$mappingId?school_id=$schoolId',
            successMsg: 'Student mapping removed successfully.',
            invalidationId: widget.guardianId,
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student mapping removed successfully.')),
        );
      }
    }
  }

  Future<void> _showAddMappingDialog(String schoolId) async {
    final studentIdController = TextEditingController();
    String relationship = 'FATHER';
    bool isPrimary = false;
    bool canPickup = true;
    bool receivesNotif = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Link Student Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: studentIdController,
                key: const Key('mapping_student_id_input'),
                decoration: const InputDecoration(labelText: 'Student UUID *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relationship,
                decoration: const InputDecoration(labelText: 'Relationship *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                  DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                  DropdownMenuItem(value: 'GUARDIAN', child: Text('Guardian')),
                  DropdownMenuItem(value: 'GRANDPARENT', child: Text('Grandparent')),
                  DropdownMenuItem(value: 'RELATIVE', child: Text('Relative')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setDialogState(() => relationship = v ?? 'GUARDIAN'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('mapping_primary_checkbox'),
                title: const Text('Primary Guardian'),
                value: isPrimary,
                onChanged: (v) => setDialogState(() => isPrimary = v ?? false),
              ),
              CheckboxListTile(
                key: const Key('mapping_pickup_checkbox'),
                title: const Text('Authorized for Pickup'),
                value: canPickup,
                onChanged: (v) => setDialogState(() => canPickup = v ?? true),
              ),
              CheckboxListTile(
                key: const Key('mapping_notif_checkbox'),
                title: const Text('Receives Notifications'),
                value: receivesNotif,
                onChanged: (v) => setDialogState(() => receivesNotif = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('mapping_save_btn'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && studentIdController.text.isNotEmpty && mounted) {
      final success = await ref.read(guardianActionsProvider.notifier).execute(
            method: 'POST',
            path: '/student-guardians',
            data: {
              'school_id': schoolId,
              'student_id': studentIdController.text.trim(),
              'guardian_id': widget.guardianId,
              'relationship': relationship,
              'is_primary': isPrimary,
              'can_pickup_student': canPickup,
              'receives_notifications': receivesNotif,
            },
            successMsg: 'Student mapped successfully.',
            invalidationId: widget.guardianId,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student mapped successfully.')),
        );
      }

      if (!success && mounted) {
        final errorMsg = ref.read(guardianActionsProvider).errorMessage ?? 'Conflict or limit error';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mapping Conflict'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                key: const Key('mapping_error_ok_btn'),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showEditMappingDialog(StudentGuardianDto mapping, String schoolId) async {
    String relationship = mapping.relationship;
    bool isPrimary = mapping.isPrimary;
    bool canPickup = mapping.canPickupStudent;
    bool receivesNotif = mapping.receivesNotifications;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Mapping Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: relationship,
                decoration: const InputDecoration(labelText: 'Relationship *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                  DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                  DropdownMenuItem(value: 'GUARDIAN', child: Text('Guardian')),
                  DropdownMenuItem(value: 'GRANDPARENT', child: Text('Grandparent')),
                  DropdownMenuItem(value: 'RELATIVE', child: Text('Relative')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setDialogState(() => relationship = v ?? 'GUARDIAN'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Primary Guardian'),
                value: isPrimary,
                onChanged: (v) => setDialogState(() => isPrimary = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Authorized for Pickup'),
                value: canPickup,
                onChanged: (v) => setDialogState(() => canPickup = v ?? true),
              ),
              CheckboxListTile(
                title: const Text('Receives Notifications'),
                value: receivesNotif,
                onChanged: (v) => setDialogState(() => receivesNotif = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('mapping_save_btn'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(guardianActionsProvider.notifier).execute(
            method: 'PUT',
            path: '/student-guardians/${mapping.id}?school_id=$schoolId',
            data: {
              'relationship': relationship,
              'is_primary': isPrimary,
              'can_pickup_student': canPickup,
              'receives_notifications': receivesNotif,
            },
            successMsg: 'Mapping details updated.',
            invalidationId: widget.guardianId,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapping details updated.')),
        );
      }

      if (!success && mounted) {
        final errorMsg = ref.read(guardianActionsProvider).errorMessage ?? 'Conflict or limit error';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mapping Conflict'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                key: const Key('mapping_error_ok_btn'),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final detailAsync = ref.watch(guardianDetailProvider(widget.guardianId));
    final mappingsAsync = ref.watch(guardianMappingsProvider(widget.guardianId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Profile Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.guardians),
        ),
      ),
      body: schoolId == null
          ? const Center(child: Text('Please select a school campus first.'))
          : detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(key: Key('guardian_details_loading'))),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              data: (guardian) => SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Profile Panel
                    Card(
                      child: ListTile(
                        title: Text('${guardian.firstName} ${guardian.lastName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        subtitle: Text('Parent Login ID: ${guardian.loginId ?? "N/A"} | Type: ${guardian.guardianType} | Gender: ${guardian.gender} | DOB: ${guardian.dateOfBirth} | Status: ${guardian.status}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: guardian.status == 'ACTIVE' ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            guardian.status,
                            style: TextStyle(color: guardian.status == 'ACTIVE' ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // B. Contact & Identity Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const Divider(),
                                  Text('Mobile: ${guardian.mobile}'),
                                  Text('Mobile Verified: ${guardian.isMobileVerified ? "Yes" : "No"}'),
                                  Text('Alternate Mobile: ${guardian.alternateMobile ?? "N/A"}'),
                                  Text('Email: ${guardian.email ?? "N/A"}'),
                                  Text('Email Verified: ${guardian.isEmailVerified ? "Yes" : "No"}'),
                                  const SizedBox(height: 12),
                                  Text('Emergency Contact: ${guardian.emergencyContactName ?? "N/A"}'),
                                  Text('Emergency Mobile: ${guardian.emergencyContactMobile ?? "N/A"}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Credentials & Professional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const Divider(),
                                  Text('Aadhaar Number: ${guardian.aadhaarNumber ?? "N/A"}'),
                                  Text('PAN Number: ${guardian.panNumber ?? "N/A"}'),
                                  const SizedBox(height: 12),
                                  Text('Occupation: ${guardian.occupation ?? "N/A"}'),
                                  Text('Qualification: ${guardian.qualification ?? "N/A"}'),
                                  Text('Organization: ${guardian.organization ?? "N/A"}'),
                                  Text('Annual Income: \$${guardian.annualIncome?.toStringAsFixed(2) ?? "0.00"}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // E. Address Parser
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Address Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(),
                              Text('Street: ${guardian.address['street'] ?? "N/A"}'),
                              Text('City/Town: ${guardian.address['city'] ?? "N/A"}'),
                              Text('State/Province: ${guardian.address['state'] ?? "N/A"}'),
                              Text('Postal Code: ${guardian.address['postal_code'] ?? "N/A"}'),
                              Text('Country: ${guardian.address['country'] ?? "N/A"}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // F. Linked Students mappings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Linked Students & Mappings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          key: const Key('add_mapping_btn'),
                          icon: const Icon(Icons.link),
                          label: const Text('Link Student'),
                          onPressed: () => _showAddMappingDialog(schoolId),
                        ),
                      ],
                    ),
                    const Divider(),

                    mappingsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(key: Key('mappings_loading'))),
                      error: (err, stack) => Text('Error loading mappings: $err', style: const TextStyle(color: Colors.red)),
                      data: (mappings) {
                        if (mappings.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              key: Key('mappings_empty_state'),
                              child: Text('No student records mapped to this guardian profile.'),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            key: const Key('mappings_data_table'),
                            columns: const [
                              DataColumn(label: Text('Student ID')),
                              DataColumn(label: Text('Relationship')),
                              DataColumn(label: Text('Primary')),
                              DataColumn(label: Text('Can Pickup')),
                              DataColumn(label: Text('Receives Notifications')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: mappings.map((m) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(m.studentId)),
                                  DataCell(Text(m.relationship)),
                                  DataCell(Icon(m.isPrimary ? Icons.check_circle : Icons.cancel, color: m.isPrimary ? Colors.green : Colors.grey)),
                                  DataCell(Icon(m.canPickupStudent ? Icons.check_circle : Icons.cancel, color: m.canPickupStudent ? Colors.green : Colors.grey)),
                                  DataCell(Icon(m.receivesNotifications ? Icons.check_circle : Icons.cancel, color: m.receivesNotifications ? Colors.green : Colors.grey)),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          key: Key('edit_mapping_${m.id}'),
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showEditMappingDialog(m, schoolId),
                                        ),
                                        IconButton(
                                          key: Key('unlink_student_${m.id}'),
                                          icon: const Icon(Icons.link_off),
                                          onPressed: () => _unlinkStudent(m.id, schoolId),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
