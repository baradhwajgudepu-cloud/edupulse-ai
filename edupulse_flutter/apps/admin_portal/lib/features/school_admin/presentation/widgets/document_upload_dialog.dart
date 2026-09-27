import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';
import '../providers/school_admin_providers.dart';

class DocumentUploadDialog extends ConsumerStatefulWidget {
  final String schoolId;

  const DocumentUploadDialog({
    super.key,
    required this.schoolId,
  });

  @override
  ConsumerState<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends ConsumerState<DocumentUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorityController = TextEditingController();
  final _docNumController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _remarksController = TextEditingController();
  final _passcodeController = TextEditingController();

  String _category = 'CERTIFICATE';
  String _confidentiality = 'STANDARD';
  bool _isPasswordProtected = false;
  bool _obscurePasscode = true;

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileError;
  bool _isSubmitting = false;

  static const int maxFileSize = 15 * 1024 * 1024; // 15 MB
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  @override
  void dispose() {
    _titleController.dispose();
    _authorityController.dispose();
    _docNumController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _remarksController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _fileError = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() => _fileError = 'Unable to read file bytes. Please try another file.');
        return;
      }

      if (file.size > maxFileSize) {
        setState(() => _fileError = 'File exceeds maximum limit of 15 MB (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB).');
        return;
      }

      final ext = file.extension?.toLowerCase() ?? '';
      if (!allowedExtensions.contains(ext)) {
        setState(() => _fileError = 'Unsupported format ".$ext". Allowed: PDF, JPG, JPEG, PNG.');
        return;
      }

      setState(() {
        _selectedFile = file;
        _fileBytes = file.bytes;
        _fileError = null;
        if (_titleController.text.trim().isEmpty) {
          final rawName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
          _titleController.text = rawName;
        }
      });
    } catch (e) {
      setState(() => _fileError = 'File picker error: $e');
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFile = null;
      _fileBytes = null;
      _fileError = null;
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool get _isImage =>
      _selectedFile != null &&
      ['png', 'jpg', 'jpeg'].contains(_selectedFile!.extension?.toLowerCase());

  bool get _isPdf =>
      _selectedFile != null &&
      (_selectedFile!.extension?.toLowerCase() == 'pdf');

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fileBytes == null || _selectedFile == null) {
      setState(() => _fileError = 'Please select a document file (PDF or Image) to upload.');
      return;
    }

    if (_isPasswordProtected && _passcodeController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password protected documents require a passcode of at least 4 characters.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref.read(schoolAdminActionProvider.notifier).uploadDocumentWithFile(
      schoolId: widget.schoolId,
      fileBytes: _fileBytes!,
      fileName: _selectedFile!.name,
      category: _category,
      title: _titleController.text.trim(),
      issuingAuthority: _authorityController.text.trim().isEmpty ? null : _authorityController.text.trim(),
      documentNumber: _docNumController.text.trim().isEmpty ? null : _docNumController.text.trim(),
      issueDate: _issueDateController.text.trim().isEmpty ? null : _issueDateController.text.trim(),
      expiryDate: _expiryDateController.text.trim().isEmpty ? null : _expiryDateController.text.trim(),
      confidentialityLevel: _confidentiality,
      isPasswordProtected: _isPasswordProtected,
      passcode: _isPasswordProtected ? _passcodeController.text.trim() : null,
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document and file uploaded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        final err = ref.read(schoolAdminActionProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${err ?? "Please check your network and retry."}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12.0 : 40.0,
        vertical: isNarrow ? 16.0 : 24.0,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: (screenH * 0.90).clamp(480.0, 840.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload & Register Document',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Select document file and enter official verification details.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Content with Clearly Separated Sections
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ====================================================
                      // SECTION 1: UPLOAD FILE
                      // ====================================================
                      _buildSectionHeader(
                        icon: Icons.attach_file,
                        title: '1. Upload File',
                        subtitle: 'Attach official PDF or image certificate from device',
                      ),
                      const SizedBox(height: 12),
                      _buildFilePickerSection(),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // ====================================================
                      // SECTION 2: DOCUMENT DETAILS
                      // ====================================================
                      _buildSectionHeader(
                        icon: Icons.article_outlined,
                        title: '2. Document Details',
                        subtitle: 'Record compliance classification, dates, and security policies',
                      ),
                      const SizedBox(height: 16),
                      _buildMetadataFields(),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isSubmitting ? 'Uploading...' : 'Save & Upload Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerSection() {
    if (_selectedFile == null) {
      return InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _fileError != null ? Colors.red : const Color(0xFFCBD5E1),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(height: 10),
              const Text(
                'Click or tap here to select a file from device',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Supported formats: PDF, JPG, JPEG, PNG (Max 15 MB)',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (_fileError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fileError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon or thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: _isPdf
                    ? const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 26)
                    : const Icon(Icons.image, color: Color(0xFF4F46E5), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFile!.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (_selectedFile!.extension ?? 'FILE').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _isPdf ? const Color(0xFFDC2626) : const Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        Text(
                          _formatBytes(_selectedFile!.size),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ready to upload',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'Remove selected file',
                onPressed: _clearSelectedFile,
              ),
              OutlinedButton(
                onPressed: _pickFile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Change', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          // Live Image Preview Thumbnail
          if (_isImage && _fileBytes != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                _fileBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Image preview unavailable', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Document Title *',
            hintText: 'e.g., Structural Safety Certificate 2026',
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a document title' : null,
        ),
        const SizedBox(height: 12),

        // Category & Confidentiality
        Row(
          children: [
            Expanded(
              child: SafeDropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'GOVERNMENT', child: Text('Government')),
                  DropdownMenuItem(value: 'RECOGNITION', child: Text('Recognition')),
                  DropdownMenuItem(value: 'AFFILIATION', child: Text('Affiliation')),
                  DropdownMenuItem(value: 'CERTIFICATE', child: Text('Certificate')),
                  DropdownMenuItem(value: 'SCHOOL_REGISTRATION', child: Text('School Registration')),
                  DropdownMenuItem(value: 'FIRE_SAFETY', child: Text('Fire Safety')),
                  DropdownMenuItem(value: 'BUILDING', child: Text('Building Fitness')),
                  DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                  DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                  DropdownMenuItem(value: 'FINANCIAL', child: Text('Financial / Audit')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SafeDropdownButtonFormField<String>(
                value: _confidentiality,
                decoration: const InputDecoration(labelText: 'Confidentiality', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                  DropdownMenuItem(value: 'CONFIDENTIAL', child: Text('Confidential')),
                  DropdownMenuItem(value: 'HIGHLY_CONFIDENTIAL', child: Text('Highly Confidential')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _confidentiality = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Issuing Authority & Doc Number
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _authorityController,
                decoration: const InputDecoration(
                  labelText: 'Issuing Authority',
                  hintText: 'e.g., CBSE, State Fire Dept',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _docNumController,
                decoration: const InputDecoration(
                  labelText: 'Document / Order #',
                  hintText: 'e.g., NOC/2026/089',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Issue Date & Expiry Date
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _issueDateController,
                readOnly: true,
                onTap: () => _pickDate(_issueDateController),
                decoration: InputDecoration(
                  labelText: 'Issue Date',
                  hintText: 'YYYY-MM-DD',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: () => _pickDate(_issueDateController),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _expiryDateController,
                readOnly: true,
                onTap: () => _pickDate(_expiryDateController),
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  hintText: 'YYYY-MM-DD',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    onPressed: () => _pickDate(_expiryDateController),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Remarks
        TextFormField(
          controller: _remarksController,
          decoration: const InputDecoration(
            labelText: 'Remarks / Notes',
            hintText: 'Internal filing comments or compliance instructions',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),

        // Password Protection Section
        CheckboxListTile(
          title: const Text(
            'Encrypt with Secret Passcode Protection',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          subtitle: const Text(
            'Requires users to enter passcode before viewing or downloading this file.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          value: _isPasswordProtected,
          onChanged: (v) => setState(() => _isPasswordProtected = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_isPasswordProtected) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _passcodeController,
            obscureText: _obscurePasscode,
            decoration: InputDecoration(
              labelText: 'Secret Passcode *',
              hintText: 'Minimum 4 characters',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePasscode ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePasscode = !_obscurePasscode),
              ),
            ),
          ),
        ],
      ],
    );
  }
}