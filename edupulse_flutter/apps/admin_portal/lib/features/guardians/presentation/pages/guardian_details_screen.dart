import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_avatar.dart';
import '../widgets/guardian_form_dialog.dart';
import '../widgets/linked_student_card.dart';

class GuardianDetailsScreen extends ConsumerStatefulWidget {
  final String guardianId;

  const GuardianDetailsScreen({super.key, required this.guardianId});

  @override
  ConsumerState<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends ConsumerState<GuardianDetailsScreen> {
  Future<void> _pickAndUploadPhoto(String schoolId, String guardianId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes == null) return;
        if (file.size > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected photo exceeds 5MB limit. Please choose a smaller photo.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final success = await ref.read(guardianActionsProvider.notifier).uploadGuardianPhoto(
              schoolId: schoolId,
              guardianId: guardianId,
              fileBytes: file.bytes!,
              fileName: file.name,
            );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardian profile photo updated successfully.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

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

  Future<void> _showEditGuardianDialog(BuildContext context, GuardianDto guardian, String schoolId) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => GuardianFormDialog(guardian: guardian),
    );
    if (updated == true && mounted) {
      ref.invalidate(guardianDetailProvider(widget.guardianId));
      ref.invalidate(guardianListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardian profile updated successfully.')),
      );
    }
  }

  Widget _buildCopyableField(String label, String value, {IconData? icon}) {
    final hasVal = value.isNotEmpty && value != 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontWeight: hasVal ? FontWeight.w500 : FontWeight.normal,
                fontSize: 13,
                color: hasVal ? null : Colors.grey,
              ),
            ),
          ),
          if (hasVal) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.blueGrey),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final detailAsync = ref.watch(guardianDetailProvider(widget.guardianId));
    final mappingsAsync = ref.watch(guardianMappingsProvider(widget.guardianId));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Profile Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.guardians),
        ),
        actions: [
          detailAsync.whenOrNull(
            data: (guardian) => Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                key: const Key('edit_guardian_header_btn'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
                onPressed: () => _showEditGuardianDialog(context, guardian, schoolId ?? ''),
              ),
            ),
          ) ?? const SizedBox.shrink(),
        ],
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    GuardianAvatar(
                                      guardianId: guardian.id,
                                      schoolId: schoolId,
                                      photoUrl: guardian.photoUrl,
                                      firstName: guardian.firstName,
                                      lastName: guardian.lastName,
                                      radius: 32,
                                      version: '${guardian.version}_${guardian.updatedAt}',
                                    ),
                                    InkWell(
                                      key: const Key('guardian_photo_edit_btn'),
                                      onTap: () => _pickAndUploadPhoto(schoolId, guardian.id),
                                      borderRadius: BorderRadius.circular(16),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${guardian.firstName} ${guardian.lastName}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text('Login ID: ${guardian.loginId ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Text('•', style: TextStyle(color: Colors.grey)),
                                          Text('Type: ${guardian.guardianType}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Text('•', style: TextStyle(color: Colors.grey)),
                                          Text('Gender: ${guardian.gender}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Text('•', style: TextStyle(color: Colors.grey)),
                                          Text('DOB: ${guardian.dateOfBirth}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: guardian.status == 'ACTIVE' ? Colors.green.shade100 : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        guardian.status,
                                        style: TextStyle(
                                          color: guardian.status == 'ACTIVE' ? Colors.green.shade800 : Colors.red.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      key: const Key('edit_guardian_profile_btn'),
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: () => _showEditGuardianDialog(context, guardian, schoolId),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // B. Contact, Credentials & Address Section (Responsive 3-Column on Desktop)
                    if (screenWidth >= 1100) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildContactCard(guardian)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCredentialsCard(guardian)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAddressCard(guardian)),
                        ],
                      ),
                    ] else if (screenWidth >= 768) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildContactCard(guardian)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCredentialsCard(guardian)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAddressCard(guardian),
                    ] else ...[
                      _buildContactCard(guardian),
                      const SizedBox(height: 12),
                      _buildCredentialsCard(guardian),
                      const SizedBox(height: 12),
                      _buildAddressCard(guardian),
                    ],
                    const SizedBox(height: 20),

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

                        return Container(
                          key: const Key('mappings_data_table'),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: mappings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final m = mappings[idx];
                              return LinkedStudentCard(
                                mapping: m,
                                schoolId: schoolId,
                                onEdit: () => _showEditMappingDialog(m, schoolId),
                                onUnlink: () => _unlinkStudent(m.id, schoolId),
                              );
                            },
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

  Widget _buildContactCard(GuardianDto guardian) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.contact_phone_outlined, size: 18, color: Colors.blueGrey),
                SizedBox(width: 6),
                Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _buildCopyableField('Mobile', guardian.mobile, icon: Icons.phone),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const SizedBox(width: 130 + 22, child: Text('Mobile Verified', style: TextStyle(color: Colors.grey, fontSize: 12))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: guardian.isMobileVerified ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      guardian.isMobileVerified ? 'VERIFIED' : 'UNVERIFIED',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: guardian.isMobileVerified ? Colors.green.shade800 : Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            _buildCopyableField('Alternate Mobile', guardian.alternateMobile ?? 'N/A', icon: Icons.phone_forwarded_outlined),
            _buildCopyableField('Email', guardian.email ?? 'N/A', icon: Icons.email_outlined),
            if (guardian.email != null && guardian.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    const SizedBox(width: 130 + 22, child: Text('Email Verified', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: guardian.isEmailVerified ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        guardian.isEmailVerified ? 'VERIFIED' : 'UNVERIFIED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: guardian.isEmailVerified ? Colors.green.shade800 : Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Divider(),
            const Text('Emergency Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 4),
            _buildCopyableField('Name', guardian.emergencyContactName ?? 'N/A'),
            _buildCopyableField('Mobile', guardian.emergencyContactMobile ?? 'N/A', icon: Icons.phone_in_talk_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsCard(GuardianDto guardian) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_outlined, size: 18, color: Colors.blueGrey),
                SizedBox(width: 6),
                Text('Credentials & Professional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _buildCopyableField('Aadhaar Number', guardian.aadhaarNumber ?? 'N/A'),
            _buildCopyableField('PAN Number', guardian.panNumber ?? 'N/A'),
            const SizedBox(height: 8),
            const Divider(),
            const Text('Professional Background', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 4),
            _buildCopyableField('Occupation', guardian.occupation ?? 'N/A'),
            _buildCopyableField('Qualification', guardian.qualification ?? 'N/A'),
            _buildCopyableField('Organization', guardian.organization ?? 'N/A'),
            _buildCopyableField('Annual Income', guardian.annualIncome != null ? '₹${guardian.annualIncome!.toStringAsFixed(2)}' : 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(GuardianDto guardian) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 6),
                    Text('Address Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (guardian.address.values.any((v) => v != null && v.toString().isNotEmpty))
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14, color: Colors.blueGrey),
                    tooltip: 'Copy Full Address',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final fullAddr = [
                        guardian.address['street'],
                        guardian.address['city'],
                        guardian.address['state'],
                        guardian.address['postal_code'],
                        guardian.address['country'],
                      ].where((p) => p != null && p.toString().isNotEmpty).join(', ');
                      Clipboard.setData(ClipboardData(text: fullAddr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied to clipboard')),
                      );
                    },
                  ),
              ],
            ),
            const Divider(),
            _buildCopyableField('Street', guardian.address['street']?.toString() ?? 'N/A'),
            _buildCopyableField('City/Town', guardian.address['city']?.toString() ?? 'N/A'),
            _buildCopyableField('State/Province', guardian.address['state']?.toString() ?? 'N/A'),
            _buildCopyableField('Postal Code', guardian.address['postal_code']?.toString() ?? 'N/A'),
            _buildCopyableField('Country', guardian.address['country']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}
