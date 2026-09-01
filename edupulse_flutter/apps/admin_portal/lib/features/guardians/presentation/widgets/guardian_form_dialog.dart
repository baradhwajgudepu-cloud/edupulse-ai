import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import '../providers/guardian_providers.dart';

class GuardianFormDialog extends ConsumerStatefulWidget {
  final GuardianDto? guardian;

  const GuardianFormDialog({super.key, this.guardian});

  @override
  ConsumerState<GuardianFormDialog> createState() => _GuardianFormDialogState();
}

class _GuardianFormDialogState extends ConsumerState<GuardianFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _guardianType;
  late String _gender;
  late DateTime? _dateOfBirth;

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _occupationController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _organizationController = TextEditingController();
  final _annualIncomeController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactMobileController = TextEditingController();

  // Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = widget.guardian;
    _guardianType = g?.guardianType ?? 'FATHER';
    _gender = g?.gender ?? 'MALE';
    _dateOfBirth = g != null ? DateTime.tryParse(g.dateOfBirth) : null;

    if (g != null) {
      _firstNameController.text = g.firstName;
      _middleNameController.text = g.middleName ?? '';
      _lastNameController.text = g.lastName;
      _aadhaarController.text = g.aadhaarNumber ?? '';
      _panController.text = g.panNumber ?? '';
      _occupationController.text = g.occupation ?? '';
      _qualificationController.text = g.qualification ?? '';
      _organizationController.text = g.organization ?? '';
      _annualIncomeController.text = g.annualIncome?.toString() ?? '';
      _mobileController.text = g.mobile;
      _alternateMobileController.text = g.alternateMobile ?? '';
      _emailController.text = g.email ?? '';
      _emergencyContactNameController.text = g.emergencyContactName ?? '';
      _emergencyContactMobileController.text = g.emergencyContactMobile ?? '';

      final addr = g.address;
      _streetController.text = addr['street']?.toString() ?? '';
      _cityController.text = addr['city']?.toString() ?? '';
      _stateController.text = addr['state']?.toString() ?? '';
      _postalCodeController.text = addr['postal_code']?.toString() ?? '';
      _countryController.text = addr['country']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _occupationController.dispose();
    _qualificationController.dispose();
    _organizationController.dispose();
    _annualIncomeController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _emailController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactMobileController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Date of Birth.')),
      );
      return;
    }

    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school campus first.')),
      );
      return;
    }

    final incomeText = _annualIncomeController.text.trim();
    final double? annualIncome = incomeText.isNotEmpty ? double.tryParse(incomeText) : null;

    final data = <String, dynamic>{
      'school_id': schoolId,
      'guardian_type': _guardianType,
      'first_name': _firstNameController.text.trim(),
      'middle_name': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'gender': _gender,
      'date_of_birth': _dateOfBirth!.toIso8601String().substring(0, 10),
      'aadhaar_number': _aadhaarController.text.trim().isEmpty ? null : _aadhaarController.text.trim(),
      'pan_number': _panController.text.trim().isEmpty ? null : _panController.text.trim().toUpperCase(),
      'occupation': _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
      'qualification': _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
      'organization': _organizationController.text.trim().isEmpty ? null : _organizationController.text.trim(),
      'annual_income': annualIncome,
      'mobile': _mobileController.text.trim(),
      'alternate_mobile': _alternateMobileController.text.trim().isEmpty ? null : _alternateMobileController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'emergency_contact_name': _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
      'emergency_contact_mobile': _emergencyContactMobileController.text.trim().isEmpty ? null : _emergencyContactMobileController.text.trim(),
      'address': {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'country': _countryController.text.trim(),
      },
      'communication_preferences': {
        'email': true,
        'sms': true,
        'push': true,
      }
    };

    final isEdit = widget.guardian != null;
    final path = isEdit ? '/guardians/${widget.guardian!.id}?school_id=$schoolId' : '/guardians';
    final method = isEdit ? 'PUT' : 'POST';
    final successMsg = isEdit ? 'Guardian profile updated successfully.' : 'Guardian profile created successfully.';

    final success = await ref.read(guardianActionsProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: successMsg,
          invalidationId: widget.guardian?.id,
        );

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(guardianActionsProvider);
    final isEdit = widget.guardian != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Guardian Profile' : 'Add Guardian Profile'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actionState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      actionState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _guardianType,
                        decoration: const InputDecoration(labelText: 'Guardian Type *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                          DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                          DropdownMenuItem(value: 'LEGAL_GUARDIAN', child: Text('Legal Guardian')),
                          DropdownMenuItem(value: 'GRANDPARENT', child: Text('Grandparent')),
                          DropdownMenuItem(value: 'UNCLE', child: Text('Uncle')),
                          DropdownMenuItem(value: 'AUNT', child: Text('Aunt')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _guardianType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        key: const Key('guardian_first_name_input'),
                        decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _middleNameController,
                        decoration: const InputDecoration(labelText: 'Middle Name', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        key: const Key('guardian_last_name_input'),
                        decoration: const InputDecoration(labelText: 'Last Name *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dateOfBirth == null
                                  ? 'Date of Birth *'
                                  : 'DOB: ${_dateOfBirth!.toIso8601String().substring(0, 10)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectDateOfBirth(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Contact Details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _mobileController,
                        key: const Key('guardian_mobile_input'),
                        decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Mobile is required';
                          if (v.trim().length < 5) return 'Invalid mobile format';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _alternateMobileController,
                        decoration: const InputDecoration(labelText: 'Alternate Mobile', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  key: const Key('guardian_email_input'),
                  decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@')) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text('Identity & Professional Info', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _aadhaarController,
                        key: const Key('guardian_aadhaar_input'),
                        decoration: const InputDecoration(labelText: 'Aadhaar Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 12 || int.tryParse(v.trim()) == null) {
                            return 'Aadhaar must be exactly 12 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _panController,
                        key: const Key('guardian_pan_input'),
                        decoration: const InputDecoration(labelText: 'PAN Number', border: OutlineInputBorder()),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                          if (!regex.hasMatch(v.trim().toUpperCase())) {
                            return 'Invalid PAN card format';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _occupationController,
                        decoration: const InputDecoration(labelText: 'Occupation', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _qualificationController,
                        decoration: const InputDecoration(labelText: 'Qualification', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _organizationController,
                        decoration: const InputDecoration(labelText: 'Organization', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _annualIncomeController,
                        key: const Key('guardian_income_input'),
                        decoration: const InputDecoration(labelText: 'Annual Income', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v.trim()) == null) return 'Must be a numeric value';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyContactNameController,
                        decoration: const InputDecoration(labelText: 'Emergency Contact Name', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyContactMobileController,
                        decoration: const InputDecoration(labelText: 'Emergency Contact Mobile', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Address Details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(labelText: 'Street Address', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(labelText: 'Postal Code', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('guardian_submit_btn'),
          onPressed: actionState.isLoading ? null : _submit,
          child: actionState.isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
