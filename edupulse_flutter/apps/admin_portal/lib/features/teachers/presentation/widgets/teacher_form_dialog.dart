import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/teachers_models.dart';
import '../providers/teachers_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class TeacherFormDialog extends ConsumerStatefulWidget {
  final TeacherDto? teacher; // Null for Create, non-null for Edit

  const TeacherFormDialog({super.key, this.teacher});

  @override
  ConsumerState<TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends ConsumerState<TeacherFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _employeeCodeController;
  late final TextEditingController _staffCodeController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _alternateMobileController;
  late final TextEditingController _officialEmailController;
  late final TextEditingController _personalEmailController;
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _panController;
  late final TextEditingController _emergencyContactNameController;
  late final TextEditingController _emergencyContactMobileController;
  late final TextEditingController _emergencyContactRelationController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _specializationController;
  late final TextEditingController _experienceYearsController;
  late final TextEditingController _designationController;
  late final TextEditingController _departmentController;
  late final TextEditingController _salaryController;

  String? _selectedGender;
  String? _selectedEmploymentType;
  String? _selectedStatus;
  
  DateTime? _dateOfBirth;
  DateTime? _joiningDate;
  DateTime? _dateOfConfirmation;
  DateTime? _dateOfResignation;
  DateTime? _dateOfRetirement;

  bool get _isEdit => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;

    _employeeCodeController = TextEditingController(text: t?.employeeCode);
    _staffCodeController = TextEditingController(text: t?.staffCode);
    _firstNameController = TextEditingController(text: t?.firstName);
    _middleNameController = TextEditingController(text: t?.middleName);
    _lastNameController = TextEditingController(text: t?.lastName);
    _mobileController = TextEditingController(text: t?.mobile);
    _alternateMobileController = TextEditingController(text: t?.alternateMobile);
    _officialEmailController = TextEditingController(text: t?.officialEmail);
    _personalEmailController = TextEditingController(text: t?.personalEmail);
    _bloodGroupController = TextEditingController(text: t?.bloodGroup);
    _aadhaarController = TextEditingController(text: t?.aadhaarNumber);
    _panController = TextEditingController(text: t?.panNumber);
    _emergencyContactNameController = TextEditingController(text: t?.emergencyContactName);
    _emergencyContactMobileController = TextEditingController(text: t?.emergencyContactMobile);
    _emergencyContactRelationController = TextEditingController(text: t?.emergencyContactRelation);
    _photoUrlController = TextEditingController(text: t?.photoUrl);
    _qualificationController = TextEditingController(text: t?.qualification);
    _specializationController = TextEditingController(text: t?.specialization);
    _experienceYearsController = TextEditingController(text: t?.experienceYears?.toString());
    _designationController = TextEditingController(text: t?.designation);
    _departmentController = TextEditingController(text: t?.department);
    _salaryController = TextEditingController(text: t?.salary?.toString());

    _selectedGender = t?.gender ?? 'MALE';
    _selectedEmploymentType = t?.employmentType ?? 'FULL_TIME';
    _selectedStatus = t?.status ?? 'ACTIVE';

    if (t?.dateOfBirth != null) {
      _dateOfBirth = DateTime.tryParse(t!.dateOfBirth);
    } else {
      _dateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 30));
    }
    if (t?.joiningDate != null) {
      _joiningDate = DateTime.tryParse(t!.joiningDate);
    } else {
      _joiningDate = DateTime.now();
    }
    if (t?.dateOfConfirmation != null) {
      _dateOfConfirmation = DateTime.tryParse(t!.dateOfConfirmation!);
    }
    if (t?.dateOfResignation != null) {
      _dateOfResignation = DateTime.tryParse(t!.dateOfResignation!);
    }
    if (t?.dateOfRetirement != null) {
      _dateOfRetirement = DateTime.tryParse(t!.dateOfRetirement!);
    }
  }

  @override
  void dispose() {
    _employeeCodeController.dispose();
    _staffCodeController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _officialEmailController.dispose();
    _personalEmailController.dispose();
    _bloodGroupController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactMobileController.dispose();
    _emergencyContactRelationController.dispose();
    _photoUrlController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    DateTime initialDate;
    if (type == 'dob') {
      initialDate = _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18));
    } else if (type == 'joining') {
      initialDate = _joiningDate ?? DateTime.now();
    } else if (type == 'confirmation') {
      initialDate = _dateOfConfirmation ?? DateTime.now();
    } else if (type == 'resignation') {
      initialDate = _dateOfResignation ?? DateTime.now();
    } else {
      initialDate = _dateOfRetirement ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (type == 'dob') {
          _dateOfBirth = picked;
        } else if (type == 'joining') {
          _joiningDate = picked;
        } else if (type == 'confirmation') {
          _dateOfConfirmation = picked;
        } else if (type == 'resignation') {
          _dateOfResignation = picked;
        } else {
          _dateOfRetirement = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No school campus selected.')),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of Birth is required.')),
      );
      return;
    }

    if (_joiningDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joining Date is required.')),
      );
      return;
    }

    // Age validation (age >= 18)
    final age = DateTime.now().year - _dateOfBirth!.year - 
        ((DateTime.now().month < _dateOfBirth!.month || 
          (DateTime.now().month == _dateOfBirth!.month && DateTime.now().day < _dateOfBirth!.day)) ? 1 : 0);
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher must be at least 18 years old.')),
      );
      return;
    }

    // Joining date validation (cannot be in the future)
    if (_joiningDate!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joining date cannot be in the future.')),
      );
      return;
    }

    final data = <String, dynamic>{
      'employee_code': _employeeCodeController.text.trim(),
      'staff_code': _staffCodeController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'middle_name': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'gender': _selectedGender,
      'date_of_birth': _formatDate(_dateOfBirth),
      'blood_group': _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
      'aadhaar_number': _aadhaarController.text.trim().isEmpty ? null : _aadhaarController.text.trim(),
      'pan_number': _panController.text.trim().isEmpty ? null : _panController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'alternate_mobile': _alternateMobileController.text.trim().isEmpty ? null : _alternateMobileController.text.trim(),
      'official_email': _officialEmailController.text.trim(),
      'personal_email': _personalEmailController.text.trim().isEmpty ? null : _personalEmailController.text.trim(),
      'emergency_contact_name': _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
      'emergency_contact_mobile': _emergencyContactMobileController.text.trim().isEmpty ? null : _emergencyContactMobileController.text.trim(),
      'emergency_contact_relation': _emergencyContactRelationController.text.trim().isEmpty ? null : _emergencyContactRelationController.text.trim(),
      'photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'address': const <String, dynamic>{}, // Optional address dictionary
      'qualification': _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
      'specialization': _specializationController.text.trim().isEmpty ? null : _specializationController.text.trim(),
      'experience_years': _experienceYearsController.text.trim().isEmpty ? null : int.tryParse(_experienceYearsController.text.trim()),
      'joining_date': _formatDate(_joiningDate),
      'date_of_confirmation': _formatDate(_dateOfConfirmation).isEmpty ? null : _formatDate(_dateOfConfirmation),
      'date_of_resignation': _formatDate(_dateOfResignation).isEmpty ? null : _formatDate(_dateOfResignation),
      'date_of_retirement': _formatDate(_dateOfRetirement).isEmpty ? null : _formatDate(_dateOfRetirement),
      'employment_type': _selectedEmploymentType,
      'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
      'department': _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
      'salary': _salaryController.text.trim().isEmpty ? null : double.tryParse(_salaryController.text.trim()),
    };

    if (_isEdit) {
      data['status'] = _selectedStatus;
    } else {
      data['school_id'] = schoolId;
    }

    final notifier = ref.read(teacherActionProvider.notifier);
    final success = await notifier.execute(
      method: _isEdit ? 'PUT' : 'POST',
      path: _isEdit ? '/teachers/${widget.teacher!.id}?school_id=$schoolId' : '/teachers',
      data: data,
      successMsg: _isEdit ? 'Teacher profile updated successfully.' : 'Teacher profile registered successfully.',
      invalidationId: _isEdit ? widget.teacher!.id : null,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(teacherActionProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? 'Edit Teacher Profile' : 'Register New Teacher',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Section: Identity Info
                      _buildSectionTitle(theme, 'Identity & Primary Information'),
                      _buildTextField(
                        controller: _employeeCodeController,
                        label: 'Employee Code *',
                        width: 220,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      _buildTextField(
                        controller: _staffCodeController,
                        label: 'Staff Code *',
                        width: 220,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      _buildDropdownField(
                        label: 'Employment Type *',
                        value: _selectedEmploymentType,
                        items: const ['FULL_TIME', 'PART_TIME', 'CONTRACT', 'VISITING'],
                        width: 220,
                        onChanged: (val) => setState(() => _selectedEmploymentType = val),
                      ),
                      _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name *',
                        width: 220,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      _buildTextField(
                        controller: _middleNameController,
                        label: 'Middle Name',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name *',
                        width: 220,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      _buildDropdownField(
                        label: 'Gender *',
                        value: _selectedGender,
                        items: const ['MALE', 'FEMALE', 'OTHER'],
                        width: 220,
                        onChanged: (val) => setState(() => _selectedGender = val),
                      ),
                      _buildDatePickerField(
                        label: 'Date of Birth *',
                        value: _dateOfBirth,
                        width: 220,
                        onTap: () => _selectDate(context, 'dob'),
                      ),
                      _buildDatePickerField(
                        label: 'Joining Date *',
                        value: _joiningDate,
                        width: 220,
                        onTap: () => _selectDate(context, 'joining'),
                      ),

                      // Section: Contact & Identity Checkups
                      _buildSectionTitle(theme, 'Contact & Document Information'),
                      _buildTextField(
                        controller: _mobileController,
                        label: 'Mobile Number *',
                        width: 220,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 8) return 'Invalid phone number';
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _alternateMobileController,
                        label: 'Alternate Mobile',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _officialEmailController,
                        label: 'Official Email *',
                        width: 220,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!value.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _personalEmailController,
                        label: 'Personal Email',
                        width: 220,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !value.contains('@')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _aadhaarController,
                        label: 'Aadhaar Number (12 digits)',
                        width: 220,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(value)) {
                            return 'Must be exactly 12 digits';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _panController,
                        label: 'PAN Number (Capital Letters)',
                        width: 220,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value)) {
                            return 'Format: ABCDE1234F';
                          }
                          return null;
                        },
                      ),

                      // Section: Qualifications & Employment Detail
                      _buildSectionTitle(theme, 'Qualifications & Employment Details'),
                      _buildTextField(
                        controller: _qualificationController,
                        label: 'Qualification',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _specializationController,
                        label: 'Specialization',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _experienceYearsController,
                        label: 'Experience (Years)',
                        width: 220,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                            return 'Must be an integer';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _designationController,
                        label: 'Designation',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _departmentController,
                        label: 'Department',
                        width: 220,
                      ),
                      _buildTextField(
                        controller: _salaryController,
                        label: 'Salary',
                        width: 220,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Must be a numeric value';
                          }
                          return null;
                        },
                      ),

                      // Optional Resignation/Retirement dates (Edit mode)
                      if (_isEdit) ...[
                        _buildSectionTitle(theme, 'Exit & Status Administration'),
                        _buildDropdownField(
                          label: 'Status *',
                          value: _selectedStatus,
                          items: const ['ACTIVE', 'INACTIVE', 'ON_LEAVE', 'RETIRED'],
                          width: 220,
                          onChanged: (val) => setState(() => _selectedStatus = val),
                        ),
                        _buildDatePickerField(
                          label: 'Confirmation Date',
                          value: _dateOfConfirmation,
                          width: 220,
                          onTap: () => _selectDate(context, 'confirmation'),
                        ),
                        _buildDatePickerField(
                          label: 'Resignation Date',
                          value: _dateOfResignation,
                          width: 220,
                          onTap: () => _selectDate(context, 'resignation'),
                        ),
                        _buildDatePickerField(
                          label: 'Retirement Date',
                          value: _dateOfRetirement,
                          width: 220,
                          onTap: () => _selectDate(context, 'retirement'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // Backend error printout
              if (actionState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    actionState.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

              // Actions Panel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: actionState.isLoading ? null : _submit,
                    child: actionState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save Changes' : 'Register Teacher'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required double width,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required double width,
    required void Function(String?) onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: IgnorePointer(
          child: TextFormField(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            controller: TextEditingController(text: value == null ? '' : _formatDate(value)),
          ),
        ),
      ),
    );
  }
}
