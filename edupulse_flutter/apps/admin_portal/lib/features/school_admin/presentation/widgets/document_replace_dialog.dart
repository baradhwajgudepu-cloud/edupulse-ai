import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/school_admin_models.dart';
import '../providers/school_admin_providers.dart';

class DocumentReplaceDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final SchoolDocumentDto document;

  const DocumentReplaceDialog({
    super.key,
    required this.schoolId,
    required this.document,
  });

  @override
  ConsumerState<DocumentReplaceDialog> createState() => _DocumentReplaceDialogState();
}

class _DocumentReplaceDialogState extends ConsumerState<DocumentReplaceDialog> {
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileError;
  bool _isSubmitting = false;

  static const int maxFileSize = 15 * 1024 * 1024; // 15 MB
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

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
    if (_fileBytes == null || _selectedFile == null) {
      setState(() => _fileError = 'Please select a replacement file to upload.');
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref.read(schoolAdminActionProvider.notifier).replaceDocumentFile(
      schoolId: widget.schoolId,
      documentId: widget.document.id,
      fileBytes: _fileBytes!,
      fileName: _selectedFile!.name,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document file replaced successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        final err = ref.read(schoolAdminActionProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Replace failed: ${err ?? "Please check your network and retry."}'),
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
          maxWidth: 580,
          maxHeight: (screenH * 0.85).clamp(400.0, 720.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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
                    child: const Icon(Icons.sync_alt, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Replace Document File',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          widget.document.title,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Existing Document Info Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT ATTACHED FILE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                widget.document.isPdf
                                    ? Icons.picture_as_pdf
                                    : (widget.document.isImage ? Icons.image : Icons.description_outlined),
                                size: 20,
                                color: widget.document.isPdf ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.document.hasFile ? widget.document.fileName : 'No physical file attached yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: widget.document.hasFile ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.document.hasFile)
                                Text(
                                  widget.document.formattedFileSize,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Select New Replacement File',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Replaces the existing digital file in storage while preserving all metadata, approval histories, and audit records without duplication.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // File Picker Control
                    if (_selectedFile == null)
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fileError != null ? Colors.red : const Color(0xFFCBD5E1),
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
                                child: const Icon(Icons.file_upload_outlined, color: Color(0xFF4F46E5), size: 28),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Click or tap here to choose new file',
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
                      )
                    else
                      Container(
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
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isPdf
                                      ? const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 24)
                                      : const Icon(Icons.image, color: Color(0xFF4F46E5), size: 24),
                                ),
                                const SizedBox(width: 12),
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'Remove',
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

                            // Thumbnail preview if image
                            if (_isImage && _fileBytes != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 110,
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
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer
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
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                        : const Icon(Icons.sync, size: 18),
                    label: Text(_isSubmitting ? 'Replacing File...' : 'Replace File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
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
}