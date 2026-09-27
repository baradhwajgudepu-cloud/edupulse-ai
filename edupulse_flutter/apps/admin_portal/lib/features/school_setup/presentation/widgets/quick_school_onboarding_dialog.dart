import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/school_setup_models.dart';
import '../providers/school_setup_providers.dart';

class QuickSchoolOnboardingDialog extends ConsumerStatefulWidget {
  const QuickSchoolOnboardingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QuickSchoolOnboardingDialog(),
    );
  }

  @override
  ConsumerState<QuickSchoolOnboardingDialog> createState() =>
      _QuickSchoolOnboardingDialogState();
}

class _QuickSchoolOnboardingDialogState
    extends ConsumerState<QuickSchoolOnboardingDialog> {
  final _formKey = GlobalKey<FormState>();

  final _schoolNameController = TextEditingController();
  final _principalNameController = TextEditingController();
  final _principalEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Optional fields
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _customBoardController = TextEditingController();
  final _customTypeController = TextEditingController();

  String _selectedBoard = 'CBSE';
  String _selectedType = 'HIGH_SCHOOL';
  bool _isObscurePassword = true;
  bool _isObscureConfirm = true;
  bool _showAdvanced = false;

  Uint8List? _logoBytes;
  String? _logoBase64;
  String? _logoFileName;
  String? _logoError;

  bool _isSubmitting = false;
  String? _errorMessage;
  QuickSchoolOnboardingResult? _result;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _principalNameController.dispose();
    _principalEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _customBoardController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    setState(() => _logoError = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        if (file.bytes != null) {
          if (file.size > 5 * 1024 * 1024) {
            setState(() => _logoError = 'Logo image must be smaller than 5 MB.');
            return;
          }
          final b64 = base64Encode(file.bytes!);
          setState(() {
            _logoBytes = file.bytes;
            _logoFileName = file.name;
            _logoBase64 = b64;
          });
        }
      }
    } catch (e) {
      setState(() => _logoError = 'Failed to select image: $e');
    }
  }

  void _clearLogo() {
    setState(() {
      _logoBytes = null;
      _logoBase64 = null;
      _logoFileName = null;
      _logoError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    String? boardValue;
    String? typeValue;
    if (_showAdvanced) {
      if (_selectedBoard == 'CUSTOM') {
        boardValue = _customBoardController.text.trim().isNotEmpty ? _customBoardController.text.trim() : null;
      } else if (_selectedBoard.isNotEmpty && _selectedBoard != 'NOT_CONFIGURED') {
        boardValue = _selectedBoard;
      }

      if (_selectedType == 'CUSTOM') {
        typeValue = _customTypeController.text.trim().isNotEmpty ? _customTypeController.text.trim() : null;
      } else if (_selectedType.isNotEmpty && _selectedType != 'NOT_CONFIGURED') {
        typeValue = _selectedType;
      }
    }

    final payload = QuickSchoolOnboardingPayload(
      schoolName: _schoolNameController.text.trim(),
      principalName: _principalNameController.text.trim(),
      principalEmail: _principalEmailController.text.trim(),
      principalPassword: _passwordController.text,
      logoBase64: _logoBase64,
      board: boardValue,
      schoolType: typeValue,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
    );

    final res = await ref.read(quickOnboardingProvider.notifier).onboard(payload);

    if (!mounted) return;

    if (res != null) {
      setState(() {
        _isSubmitting = false;
        _result = res;
      });
    } else {
      final failureState = ref.read(quickOnboardingProvider);
      setState(() {
        _isSubmitting = false;
        _errorMessage = failureState.error?.toString() ?? 'Failed to create school. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 640;
    final maxH = (screenH * 0.92).clamp(420.0, 780.0);
    final insetPadding = EdgeInsets.symmetric(
      horizontal: screenW < 600 ? 12 : 24,
      vertical: screenH < 600 ? 12 : 24,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: maxH,
        ),
        child: _result != null ? _buildCelebrationView(theme, isDesktop) : _buildFormView(theme, isDesktop),
      ),
    );
  }

  Widget _buildCheckRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildCelebrationView(ThemeData theme, bool isDesktop) {
    final res = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            '✓ School Created Successfully',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your institution workspace and Principal account are active and ready.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.schoolName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('School Code', res.schoolCode),
                const SizedBox(height: 8),
                _buildSummaryRow('Principal', _principalNameController.text.trim().isNotEmpty ? _principalNameController.text.trim() : res.principalEmail),
                const SizedBox(height: 8),
                _buildSummaryRow('Login', res.principalEmail),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'Tenant created'),
                const SizedBox(height: 6),
                _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'Principal account created'),
                const SizedBox(height: 6),
                _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'School workspace initialized'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Actions: [ Open School ] and [ Back to School Directory ]
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: isDesktop ? 260 : double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final sessionManager = ref.read(sessionManagerProvider);
                    await sessionManager.saveTenantId(res.tenantId);
                    await sessionManager.saveSchoolId(res.schoolId);
                    await sessionManager.saveSchoolName(res.schoolName);
                    await sessionManager.saveTenantName(res.tenantName);

                    ref.read(selectedSchoolIdProvider.notifier).state = res.schoolId;
                    ref.read(selectedTenantIdProvider.notifier).state = res.tenantId;

                    if (!mounted) return;
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    context.go(AppRoutes.dashboard);
                  },
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text('Open School'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 260 : double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Keep Platform Admin in PLATFORM SCOPE (do not mutate selectedSchoolIdProvider)
                    ref.read(schoolsListProvider.notifier).fetchSchools();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    context.go(AppRoutes.schools);
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back to School Directory'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildFormView(ThemeData theme, bool isDesktop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modal Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREATE YOUR SCHOOL',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Step 1 of 1: Initial Setup — Institution & Master Administrator',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Scrollable Form Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Platform Scope Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PLATFORM SCOPE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Scope: PLATFORM ADMINISTRATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Creating a new school & tenant without requiring active school context',
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 1. School Logo Upload Area
                  _buildLogoUploadBox(),
                  const SizedBox(height: 18),

                  // 2. School Name *
                  _buildLabel('School Name', isRequired: true),
                  TextFormField(
                    controller: _schoolNameController,
                    decoration: _inputDecoration('e.g. Hyderabad Public School', Icons.business_rounded),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'School name is required';
                      if (v.trim().length < 2) return 'School name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Principal Name *
                  _buildLabel('Principal Name', isRequired: true),
                  TextFormField(
                    controller: _principalNameController,
                    decoration: _inputDecoration('e.g. Dr. Sarah Smith', Icons.person_rounded),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Principal name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Principal Email / Login ID *
                  _buildLabel('Principal Email / Login ID', isRequired: true),
                  TextFormField(
                    controller: _principalEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('principal@school.edu.in', Icons.alternate_email_rounded),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Principal email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. Password & Confirm Password *
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Password', isRequired: true),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _isObscurePassword,
                                decoration: _inputDecoration('Min. 8 characters', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_isObscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                                    onPressed: () => setState(() => _isObscurePassword = !_isObscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Password is required';
                                  if (v.length < 8) return 'Password must be at least 8 characters';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Confirm Password', isRequired: true),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _isObscureConfirm,
                                decoration: _inputDecoration('Re-enter password', Icons.lock_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_isObscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                                    onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                                  ),
                                ),
                                validator: (v) {
                                  if (v != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildLabel('Password', isRequired: true),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isObscurePassword,
                      decoration: _inputDecoration('Min. 8 characters', Icons.lock_outline_rounded).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isObscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _isObscurePassword = !_isObscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('Confirm Password', isRequired: true),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _isObscureConfirm,
                      decoration: _inputDecoration('Re-enter password', Icons.lock_rounded).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isObscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Optional Details Expander
                  InkWell(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more, size: 20, color: const Color(0xFF0F766E)),
                          const SizedBox(width: 6),
                          Text(
                            _showAdvanced ? 'Hide Optional Settings' : '+ Optional Settings (Board, Type, Contact)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showAdvanced) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Affiliation Board'),
                              DropdownButtonFormField<String>(
                                value: _selectedBoard,
                                items: const [
                                  DropdownMenuItem(value: 'CBSE', child: Text('CBSE')),
                                  DropdownMenuItem(value: 'ICSE', child: Text('ICSE')),
                                  DropdownMenuItem(value: 'STATE', child: Text('State Board')),
                                  DropdownMenuItem(value: 'IB', child: Text('International (IB)')),
                                  DropdownMenuItem(value: 'CAMBRIDGE', child: Text('Cambridge')),
                                  DropdownMenuItem(value: 'CUSTOM', child: Text('+ Custom Board')),
                                ],
                                onChanged: (v) => setState(() => _selectedBoard = v ?? 'CBSE'),
                                decoration: _inputDecoration('', Icons.account_balance_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('School Type'),
                              DropdownButtonFormField<String>(
                                value: _selectedType,
                                items: const [
                                  DropdownMenuItem(value: 'HIGH_SCHOOL', child: Text('High School')),
                                  DropdownMenuItem(value: 'PRIMARY', child: Text('Primary School')),
                                  DropdownMenuItem(value: 'JR_COLLEGE', child: Text('Junior College')),
                                  DropdownMenuItem(value: 'DEGREE_COLLEGE', child: Text('Degree College')),
                                  DropdownMenuItem(value: 'CUSTOM', child: Text('+ Custom Type')),
                                ],
                                onChanged: (v) => setState(() => _selectedType = v ?? 'HIGH_SCHOOL'),
                                decoration: _inputDecoration('', Icons.category_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedBoard == 'CUSTOM') ...[
                      const SizedBox(height: 10),
                      _buildLabel('Custom Board Name'),
                      TextFormField(
                        controller: _customBoardController,
                        decoration: _inputDecoration('e.g. Telangana State Board (TSBIE)', Icons.edit_note_rounded),
                      ),
                    ],
                    if (_selectedType == 'CUSTOM') ...[
                      const SizedBox(height: 10),
                      _buildLabel('Custom School Type Name'),
                      TextFormField(
                        controller: _customTypeController,
                        decoration: _inputDecoration('e.g. Residential Intermediate College', Icons.edit_note_rounded),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildLabel('Contact Phone'),
                    TextFormField(
                      controller: _phoneController,
                      decoration: _inputDecoration('+91 9876543210', Icons.phone_rounded),
                    ),
                    const SizedBox(height: 10),
                    _buildLabel('Campus Address'),
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputDecoration('Street address, City', Icons.location_on_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Footer Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_isSubmitting ? 'Creating School...' : 'Create School'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoUploadBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF94A3B8), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'School Logo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Optional', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _logoFileName ?? 'PNG, JPG or WEBP (Max 5 MB)',
                  style: TextStyle(fontSize: 11, color: _logoFileName != null ? const Color(0xFF0F766E) : const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_logoError != null)
                  Text(_logoError!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
              ],
            ),
          ),
          if (_logoBytes != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
              onPressed: _clearLogo,
              tooltip: 'Remove logo',
            )
          else
            OutlinedButton(
              onPressed: _pickLogo,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Browse', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          if (isRequired)
            const Text(' *', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
