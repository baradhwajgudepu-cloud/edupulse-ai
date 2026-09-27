import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/student_providers.dart';
import '../widgets/student_avatar.dart';
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
  StudentDto? _initialStudent;

  // Photo management state
  Uint8List? _pickedPhotoBytes;
  String? _pickedPhotoName;
  bool _photoRemoved = false;

  Future<void> _pickPhoto() async {
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
        setState(() {
          _pickedPhotoBytes = file.bytes;
          _pickedPhotoName = file.name;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedPhotoBytes = null;
      _pickedPhotoName = null;
      _photoRemoved = true;
      _photoUrlController.clear();
    });
  }

  bool _hasPhoto() {
    if (_photoRemoved) return false;
    if (_pickedPhotoBytes != null) return true;
    return _isEditMode && _photoUrlController.text.trim().isNotEmpty;
  }

  Widget _buildPhotoPreview(ThemeData theme) {
    if (_pickedPhotoBytes != null) {
      return StudentAvatar(
        radius: 36,
        previewBytes: _pickedPhotoBytes,
      );
    }
    if (_isEditMode && !_photoRemoved && _photoUrlController.text.trim().isNotEmpty) {
      return StudentAvatar(
        studentId: widget.studentId,
        schoolId: widget.schoolId,
        photoUrl: _photoUrlController.text.trim(),
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        version: '$_entityVersion',
        radius: 36,
      );
    }
    return StudentAvatar(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      radius: 36,
    );
  }

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
      _initialStudent = s;
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

    final actionNotifier = ref.read(studentActionProvider.notifier);

    // If in Edit Mode: check what actually changed
    if (_isEditMode) {
      final hasPhotoToUpload = _pickedPhotoBytes != null;
      final hasPhotoToRemove = _photoRemoved && (_initialStudent?.photoUrl != null && _initialStudent!.photoUrl!.isNotEmpty);
      final photoChanged = hasPhotoToUpload || hasPhotoToRemove;

      final placementChanged = _initialStudent != null && (
        _selectedAyId != _initialStudent!.academicYearId ||
        _selectedClassId != _initialStudent!.classId ||
        _selectedSectionId != _initialStudent!.sectionId
      );

      final attributesChanged = _initialStudent == null || (
        _firstNameController.text != _initialStudent!.firstName ||
        _middleNameController.text != (_initialStudent!.middleName ?? '') ||
        _lastNameController.text != _initialStudent!.lastName ||
        _selectedGender != _initialStudent!.gender ||
        _dobController.text != _initialStudent!.dateOfBirth ||
        _bloodGroupController.text != (_initialStudent!.bloodGroup ?? '') ||
        _aadhaarController.text != (_initialStudent!.aadhaarNumber ?? '') ||
        _emisController.text != (_initialStudent!.emisNumber ?? '') ||
        _mobileController.text != (_initialStudent!.mobile ?? '') ||
        _emailController.text != (_initialStudent!.email ?? '') ||
        _photoUrlController.text != (_initialStudent!.photoUrl ?? '') ||
        _addressLineController.text != (_initialStudent!.address['line']?.toString() ?? '') ||
        _cityController.text != (_initialStudent!.address['city']?.toString() ?? '') ||
        _stateController.text != (_initialStudent!.address['state']?.toString() ?? '') ||
        _medicalController.text != (_initialStudent!.medicalInformation['allergies']?.toString() ?? '') ||
        _admissionNumberController.text != _initialStudent!.admissionNumber ||
        _rollNumberController.text != _initialStudent!.rollNumber ||
        _admissionDateController.text != _initialStudent!.admissionDate ||
        _selectedStatus != _initialStudent!.status
      );

      // Operation A: Only photo changed -> do NOT send student update or academic placement
      if (photoChanged && !placementChanged && !attributesChanged) {
        bool photoSuccess = false;
        if (hasPhotoToUpload) {
          photoSuccess = await actionNotifier.uploadStudentPhoto(
            schoolId: widget.schoolId,
            studentId: widget.studentId,
            fileBytes: _pickedPhotoBytes!,
            fileName: _pickedPhotoName ?? 'photo.jpg',
          );
        } else if (hasPhotoToRemove) {
          photoSuccess = await actionNotifier.deleteStudentPhoto(
            schoolId: widget.schoolId,
            studentId: widget.studentId,
          );
        }

        if (photoSuccess) {
          ref.invalidate(studentListProvider);
          ref.invalidate(studentDetailProvider(widget.studentId));
          ref.invalidate(studentAvatarBytesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(hasPhotoToUpload ? 'Student photo updated successfully' : 'Student photo removed successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop(true);
          }
        } else {
          final actionState = ref.read(studentActionProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(actionState.errorMessage ?? 'Photo operation failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      // Operation B & C: Profile attributes and/or Placement changed
      final updateData = <String, dynamic>{
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
        'status': _selectedStatus,
        'version': _entityVersion,
        // Only include academic placement if it was genuinely modified by user!
        if (placementChanged) ...{
          'academic_year_id': _selectedAyId,
          'class_id': _selectedClassId,
          'section_id': _selectedSectionId,
        },
      };

      final success = await actionNotifier.execute(
        method: 'PUT',
        path: '/students/${widget.studentId}?school_id=${widget.schoolId}',
        data: updateData,
        successMsg: 'Student profile updated',
      );

      if (success) {
        if (hasPhotoToUpload) {
          await actionNotifier.uploadStudentPhoto(
            schoolId: widget.schoolId,
            studentId: widget.studentId,
            fileBytes: _pickedPhotoBytes!,
            fileName: _pickedPhotoName ?? 'photo.jpg',
          );
        } else if (hasPhotoToRemove) {
          await actionNotifier.deleteStudentPhoto(
            schoolId: widget.schoolId,
            studentId: widget.studentId,
          );
        }

        ref.invalidate(studentListProvider);
        ref.invalidate(studentDetailProvider(widget.studentId));
        ref.invalidate(studentAvatarBytesProvider);
        if (mounted) context.pop(true);
      } else {
        final actionState = ref.read(studentActionProvider);
        if (mounted) {
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
      return;
    }

    // Operation D: Create Mode (Admit New Student)
    final createData = {
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
    };

    final success = await actionNotifier.execute(
      method: 'POST',
      path: '/students',
      data: createData,
      successMsg: 'Student admitted successfully',
    );

    if (success) {
      final targetStudentId = ref.read(studentActionProvider).createdStudent?.id ??
          (ref.read(studentActionProvider).lastData is Map &&
                  ref.read(studentActionProvider).lastData['data'] is Map
              ? ref.read(studentActionProvider).lastData['data']['id']?.toString()
              : null) ??
          '';

      if (targetStudentId.isNotEmpty && _pickedPhotoBytes != null) {
        await actionNotifier.uploadStudentPhoto(
          schoolId: widget.schoolId,
          studentId: targetStudentId,
          fileBytes: _pickedPhotoBytes!,
          fileName: _pickedPhotoName ?? 'photo.jpg',
        );
      }

      ref.invalidate(studentListProvider);
      if (mounted) context.pop(true);
    } else {
      final actionState = ref.read(studentActionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(actionState.errorMessage ?? 'Operation failed'),
            backgroundColor: Colors.red,
          ),
        );
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
      if (mounted) context.pop();
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 16,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('cancel_student_button'),
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                key: const Key('save_student_button'),
                onPressed: actionState.isLoading ? null : _saveForm,
                icon: actionState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Details'),
              ),
            ],
          ),
        ),
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

                    // Profile Photo (DP) Card
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student Profile Photo (DP)', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Upload a JPG, PNG, or WEBP photo (Max 5MB). Photo is optional.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildPhotoPreview(theme),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        key: const Key('upload_student_photo_button'),
                                        onPressed: _pickPhoto,
                                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                                        label: Text(_hasPhoto() ? 'Change Photo' : 'Upload Photo'),
                                      ),
                                      if (_hasPhoto())
                                        OutlinedButton.icon(
                                          key: const Key('remove_student_photo_button'),
                                          onPressed: _removePhoto,
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
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
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          key: const Key('edit_student_cancel_button'),
                          onPressed: () => context.pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          key: const Key('edit_student_save_button'),
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
      error: (error, stack) => LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final titleWidget = Text(
            'Guardian profile unavailable (${mapping.relationship})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
          final subtitleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${mapping.guardianId}'),
              Text(
                'Primary: ${mapping.isPrimary ? "YES" : "NO"} • Pickup: ${mapping.canPickupStudent ? "Allowed" : "Blocked"} • Notifications: ${mapping.receivesNotifications ? "Yes" : "No"}',
              ),
            ],
          );
          final actionsWidget = Wrap(
            spacing: 8,
            runSpacing: 4,
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
          );

          if (isNarrow) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 4),
                  subtitleWidget,
                  const SizedBox(height: 8),
                  actionsWidget,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 4),
                      subtitleWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                actionsWidget,
              ],
            ),
          );
        },
      ),
      data: (guardian) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            final titleWidget = Text(
              '${guardian.firstName} ${guardian.lastName} (${mapping.relationship})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
            final subtitleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${guardian.email ?? "N/A"} • Phone: ${guardian.mobile}'),
                Text(
                  'Primary: ${mapping.isPrimary ? "YES" : "NO"} • Pickup: ${mapping.canPickupStudent ? "Allowed" : "Blocked"} • Notifications: ${mapping.receivesNotifications ? "Yes" : "No"}',
                ),
              ],
            );
            final actionsWidget = Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
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
            );

            if (isNarrow) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 4),
                    subtitleWidget,
                    const SizedBox(height: 8),
                    actionsWidget,
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 4),
                        subtitleWidget,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  actionsWidget,
                ],
              ),
            );
          },
        );
      },
    );
  }
}
