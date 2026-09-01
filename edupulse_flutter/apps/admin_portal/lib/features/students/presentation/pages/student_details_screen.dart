import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../data/models/student_models.dart';

class StudentDetailsScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String studentId;

  const StudentDetailsScreen({
    super.key,
    required this.schoolId,
    required this.studentId,
  });

  @override
  ConsumerState<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends ConsumerState<StudentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  // Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController(); // YYYY-MM-DD
  final _bloodGroupController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _emisController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _medicalController = TextEditingController();

  final _admissionNumberController = TextEditingController();
  final _admissionDateController = TextEditingController(); // YYYY-MM-DD
  final _rollNumberController = TextEditingController();

  String _selectedGender = 'MALE';
  String _selectedStatus = 'ACTIVE';
  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.studentId != 'new';
    Future.microtask(() {
      ref.read(academicYearsProvider(widget.schoolId).notifier).fetchYears();
      if (_isEditMode) {
        _loadStudentDetails();
      }
    });
  }

  Future<void> _loadStudentDetails() async {
    final s = await ref.read(studentDetailProvider(widget.studentId).future);
    setState(() {
      _firstNameController.text = s.firstName;
      _middleNameController.text = s.middleName ?? '';
      _lastNameController.text = s.lastName;
      _dobController.text = s.dateOfBirth;
      _bloodGroupController.text = s.bloodGroup ?? '';
      _aadhaarController.text = s.aadhaarNumber ?? '';
      _emisController.text = s.emisNumber ?? '';
      _mobileController.text = s.mobile ?? '';
      _emailController.text = s.email ?? '';
      _photoUrlController.text = s.photoUrl ?? '';
      _addressLineController.text = s.address['line']?.toString() ?? '';
      _cityController.text = s.address['city']?.toString() ?? '';
      _stateController.text = s.address['state']?.toString() ?? '';
      _medicalController.text = s.medicalInformation['allergies']?.toString() ?? '';
      _admissionNumberController.text = s.admissionNumber;
      _admissionDateController.text = s.admissionDate;
      _rollNumberController.text = s.rollNumber;
      _selectedGender = s.gender;
      _selectedStatus = s.status;
      _selectedAyId = s.academicYearId;
      _selectedClassId = s.classId;
      _selectedSectionId = s.sectionId;
      _entityVersion = s.version;
    });

    // Populate dependent dropdowns
    ref.read(classesProvider(widget.schoolId).notifier).fetchClasses(academicYearId: s.academicYearId);
    ref.read(sectionsProvider(widget.schoolId).notifier).fetchSections(classId: s.classId);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _bloodGroupController.dispose();
    _aadhaarController.dispose();
    _emisController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _photoUrlController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _medicalController.dispose();
    _admissionNumberController.dispose();
    _admissionDateController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAyId == null || _selectedClassId == null || _selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify academic hierarchy details'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = {
      'first_name': _firstNameController.text,
      'middle_name': _middleNameController.text.isEmpty ? null : _middleNameController.text,
      'last_name': _lastNameController.text,
      'gender': _selectedGender,
      'date_of_birth': _dobController.text,
      'blood_group': _bloodGroupController.text.isEmpty ? null : _bloodGroupController.text,
      'aadhaar_number': _aadhaarController.text.isEmpty ? null : _aadhaarController.text,
      'emis_number': _emisController.text.isEmpty ? null : _emisController.text,
      'mobile': _mobileController.text.isEmpty ? null : _mobileController.text,
      'email': _emailController.text.isEmpty ? null : _emailController.text,
      'photo_url': _photoUrlController.text.isEmpty ? null : _photoUrlController.text,
      'address': {
        'line': _addressLineController.text,
        'city': _cityController.text,
        'state': _stateController.text,
      },
      'medical_information': {
        'allergies': _medicalController.text,
      },
      'admission_number': _admissionNumberController.text,
      'roll_number': _rollNumberController.text,
      'admission_date': _admissionDateController.text,
      'school_id': widget.schoolId,
      'academic_year_id': _selectedAyId,
      'class_id': _selectedClassId,
      'section_id': _selectedSectionId,
      'status': _selectedStatus,
      if (_isEditMode) 'version': _entityVersion,
    };

    final path = _isEditMode ? '/students/${widget.studentId}?school_id=${widget.schoolId}' : '/students';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(studentActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Student profile updated' : 'Student admitted successfully',
        );

    if (success) {
      ref.invalidate(studentListProvider);
      if (_isEditMode) {
        ref.invalidate(studentDetailProvider(widget.studentId));
      }
      context.pop();
    } else {
      final actionState = ref.read(studentActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
      if (actionState.isConflict) {
        _loadStudentDetails();
      }
    }
  }

  Future<void> _deleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soft-delete Student Profile?'),
        content: const Text(
          'This student will be marked inactive and withdrawn rather than physically removed from database history.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(studentActionProvider.notifier).execute(
          method: 'DELETE',
          path: '/students/${widget.studentId}?school_id=${widget.schoolId}',
          successMsg: 'Student soft-deleted successfully',
        );

    if (success) {
      ref.invalidate(studentListProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(studentActionProvider);
    final ayState = ref.watch(academicYearsProvider(widget.schoolId));
    final classState = ref.watch(classesProvider(widget.schoolId));
    final sectionState = ref.watch(sectionsProvider(widget.schoolId));
    final theme = Theme.of(context);

    // Dependent list filtering
    final activeYears = ayState.years;
    final activeClasses = classState.classes.where((c) {
      if (_selectedAyId != null) return c.academicYearId == _selectedAyId;
      return true;
    }).toList();
    final activeSections = sectionState.sections.where((s) {
      if (_selectedClassId != null) return s.classId == _selectedClassId;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Student Profile Attributes' : 'New Student Admission'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Soft delete profile',
              onPressed: _deleteStudent,
            ),
        ],
      ),
      body: actionState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Academic settings card
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Academic Placement Mapping', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 16),
                            // Academic Year Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedAyId,
                              decoration: const InputDecoration(
                                labelText: 'Academic Year *',
                                border: OutlineInputBorder(),
                              ),
                              items: activeYears.map((ay) {
                                return DropdownMenuItem(value: ay.id, child: Text(ay.name));
                              }).toList(),
                              validator: (v) => v == null ? 'Required' : null,
                              onChanged: (val) {
                                setState(() {
                                  _selectedAyId = val;
                                  _selectedClassId = null;
                                  _selectedSectionId = null;
                                });
                                if (val != null) {
                                  ref.read(classesProvider(widget.schoolId).notifier).fetchClasses(academicYearId: val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            // Class Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedClassId,
                              decoration: const InputDecoration(
                                labelText: 'Class *',
                                border: OutlineInputBorder(),
                              ),
                              items: activeClasses.map((c) {
                                return DropdownMenuItem(value: c.id, child: Text(c.name));
                              }).toList(),
                              validator: (v) => v == null ? 'Required' : null,
                              onChanged: (val) {
                                setState(() {
                                  _selectedClassId = val;
                                  _selectedSectionId = null;
                                });
                                if (val != null) {
                                  ref.read(sectionsProvider(widget.schoolId).notifier).fetchSections(classId: val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            // Section Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Section *',
                                border: OutlineInputBorder(),
                              ),
                              items: activeSections.map((s) {
                                return DropdownMenuItem(value: s.id, child: Text(s.name));
                              }).toList(),
                              validator: (v) => v == null ? 'Required' : null,
                              onChanged: (val) => setState(() => _selectedSectionId = val),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Personal details card
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Personal Profile details', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _middleNameController,
                              decoration: const InputDecoration(labelText: 'Middle Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(labelText: 'Last Name *', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                              ],
                              onChanged: (val) => setState(() => _selectedGender = val ?? 'MALE'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dobController,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth (YYYY-MM-DD) *',
                                border: OutlineInputBorder(),
                                hintText: 'YYYY-MM-DD',
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bloodGroupController,
                              decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Admission codes card
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admission & Registration parameters', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _admissionNumberController,
                              decoration: const InputDecoration(labelText: 'Admission Number *', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _rollNumberController,
                              decoration: const InputDecoration(labelText: 'Roll Number *', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _admissionDateController,
                              decoration: const InputDecoration(
                                labelText: 'Admission Date (YYYY-MM-DD) *',
                                border: OutlineInputBorder(),
                                hintText: 'YYYY-MM-DD',
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Identity & contact details
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Identifiers, Contacts & Medical', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _aadhaarController,
                              decoration: const InputDecoration(labelText: 'Aadhaar (12 digits)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emisController,
                              decoration: const InputDecoration(labelText: 'EMIS Code', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _mobileController,
                              decoration: const InputDecoration(labelText: 'Mobile Phone', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _photoUrlController,
                              decoration: const InputDecoration(labelText: 'Photo URL', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressLineController,
                              decoration: const InputDecoration(labelText: 'Address Line', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _medicalController,
                              decoration: const InputDecoration(labelText: 'Medical Allergies / History', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                                DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                                DropdownMenuItem(value: 'WITHDRAWN', child: Text('Withdrawn')),
                                DropdownMenuItem(value: 'ALUMNI', child: Text('Alumni')),
                              ],
                              onChanged: (val) => setState(() => _selectedStatus = val ?? 'ACTIVE'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Guardian mapping panel (only visible in edit mode)
                    if (_isEditMode) _buildGuardianSection(theme),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _saveForm,
                          child: const Text('Save Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGuardianSection(ThemeData theme) {
    final mappingState = ref.watch(studentGuardianProvider(widget.studentId));

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
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
                    'Guardian Associations',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddGuardianDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('Link Guardian'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            mappingState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading mappings: $err', style: TextStyle(color: theme.colorScheme.error)),
              data: (mappings) {
                if (mappings.isEmpty) {
                  return const Text('No guardian records mapped to this student profile yet.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mappings.length,
                  separatorBuilder: (c, idx) => const Divider(),
                  itemBuilder: (context, index) {
                    final map = mappings[index];
                    return GuardianAssociationTile(
                      mapping: map,
                      schoolId: widget.schoolId,
                      onEdit: () => _showEditGuardianDialog(map),
                      onUnlink: () => _removeGuardianMapping(map.id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddGuardianDialog() async {
    final guardianIdController = TextEditingController();
    String relationship = 'FATHER';
    bool isPrimary = false;
    bool canPickup = true;
    bool receiveNotifications = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Link Guardian Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: guardianIdController,
                  decoration: const InputDecoration(labelText: 'Guardian UUID *', border: OutlineInputBorder()),
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
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Primary Contact'),
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
                  value: receiveNotifications,
                  onChanged: (v) => setDialogState(() => receiveNotifications = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => context.pop(true), child: const Text('Link')),
          ],
        ),
      ),
    );

    if (confirm == true && guardianIdController.text.isNotEmpty) {
      final success = await ref.read(studentActionProvider.notifier).execute(
            method: 'POST',
            path: '/student-guardians',
            data: {
              'school_id': widget.schoolId,
              'student_id': widget.studentId,
              'guardian_id': guardianIdController.text,
              'relationship': relationship,
              'is_primary': isPrimary,
              'can_pickup_student': canPickup,
              'receives_notifications': receiveNotifications,
            },
            successMsg: 'Guardian linked successfully',
          );
      if (success) {
        ref.invalidate(studentGuardianProvider(widget.studentId));
      }
    }
  }

  Future<void> _showEditGuardianDialog(StudentGuardianDto mapping) async {
    String relationship = mapping.relationship;
    bool isPrimary = mapping.isPrimary;
    bool canPickup = mapping.canPickupStudent;
    bool receiveNotifications = mapping.receivesNotifications;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Guardian Association'),
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
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Primary Contact'),
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
                value: receiveNotifications,
                onChanged: (v) => setDialogState(() => receiveNotifications = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => context.pop(true), child: const Text('Update')),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final success = await ref.read(studentActionProvider.notifier).execute(
            method: 'PUT',
            path: '/student-guardians/${mapping.id}?school_id=${widget.schoolId}',
            data: {
              'relationship': relationship,
              'is_primary': isPrimary,
              'can_pickup_student': canPickup,
              'receives_notifications': receiveNotifications,
            },
            successMsg: 'Association updated successfully',
          );
      if (success) {
        ref.invalidate(studentGuardianProvider(widget.studentId));
      }
    }
  }

  Future<void> _removeGuardianMapping(String mappingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Guardian Association?'),
        content: const Text('This will unlink the guardian from this student record.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(studentActionProvider.notifier).execute(
            method: 'DELETE',
            path: '/student-guardians/$mappingId?school_id=${widget.schoolId}',
            successMsg: 'Guardian unlinked successfully',
          );
      if (success) {
        ref.invalidate(studentGuardianProvider(widget.studentId));
      }
    }
  }
}

class GuardianAssociationTile extends ConsumerWidget {
  final StudentGuardianDto mapping;
  final String schoolId;
  final VoidCallback onEdit;
  final VoidCallback onUnlink;

  const GuardianAssociationTile({
    super.key,
    required this.mapping,
    required this.schoolId,
    required this.onEdit,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsState = ref.watch(guardianDetailsProvider(mapping.guardianId));

    return detailsState.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading guardian profile...'),
      ),
      error: (error, stack) => ListTile(
        title: Text(
          'Guardian profile unavailable (${mapping.relationship})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${mapping.guardianId}'),
            Text(
              'Primary: ${mapping.isPrimary ? "YES" : "NO"} • Pickup: ${mapping.canPickupStudent ? "Allowed" : "Blocked"} • Notifications: ${mapping.receivesNotifications ? "Yes" : "No"}',
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.red),
              onPressed: onUnlink,
            ),
          ],
        ),
      ),
      data: (guardian) {
        return ListTile(
          title: Text(
            '${guardian.firstName} ${guardian.lastName} (${mapping.relationship})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${guardian.email ?? "N/A"} • Phone: ${guardian.mobile}'),
              Text(
                'Primary: ${mapping.isPrimary ? "YES" : "NO"} • Pickup: ${mapping.canPickupStudent ? "Allowed" : "Blocked"} • Notifications: ${mapping.receivesNotifications ? "Yes" : "No"}',
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Parent'),
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    final status = await ref.read(
                      guardianUserStatusProvider(mapping.guardianId).future,
                    );
                    if (status['is_provisioned'] == true && status['user_id'] != null) {
                      final userId = status['user_id'].toString();
                      if (context.mounted) {
                        context.push('/users/$userId');
                      }
                    } else {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No User Account has been provisioned for this guardian yet.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error checking user status: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.link_off, color: Colors.red),
                onPressed: onUnlink,
              ),
            ],
          ),
        );
      },
    );
  }
}
