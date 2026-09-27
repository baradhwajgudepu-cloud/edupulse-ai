import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';
import '../../data/models/school_admin_models.dart';
import '../providers/school_admin_providers.dart';

class DocumentPreviewDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final SchoolDocumentDto document;

  const DocumentPreviewDialog({
    super.key,
    required this.schoolId,
    required this.document,
  });

  @override
  ConsumerState<DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends ConsumerState<DocumentPreviewDialog> {
  bool _isLoading = false;
  Uint8List? _fileBytes;
  String? _errorMessage;

  bool _isLocked = false;
  String? _unlockToken;
  final _passcodeController = TextEditingController();
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.document.isPasswordProtected;
    if (!_isLocked) {
      _loadDocumentBytes();
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentBytes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final bytes = await ref.read(schoolAdminActionProvider.notifier).fetchDocumentBytes(
      documentId: widget.document.id,
      unlockToken: _unlockToken,
      inline: true,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (bytes != null) {
          _fileBytes = bytes;
        } else {
          _errorMessage = 'Unable to stream document content from secure vault storage.';
        }
      });
    }
  }

  Future<void> _handleUnlock() async {
    final code = _passcodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isUnlocking = true);

    final token = await ref.read(schoolAdminActionProvider.notifier).unlockDocument(
      widget.document.id,
      code,
    );

    if (mounted) {
      setState(() => _isUnlocking = false);
      if (token != null) {
        setState(() {
          _unlockToken = token;
          _isLocked = false;
        });
        _loadDocumentBytes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid passcode. Access rejected.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleDownload() {
    if (_fileBytes != null) {
      downloadBinaryFile(
        widget.document.fileName,
        _fileBytes!,
        mimeType: widget.document.contentType,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${widget.document.fileName}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
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
          maxWidth: 840,
          maxHeight: (screenH * 0.92).clamp(480.0, 900.0),
        ),
        child: Column(
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
                      color: widget.document.isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.document.isPdf
                          ? Icons.picture_as_pdf
                          : (widget.document.isImage ? Icons.image : Icons.description_outlined),
                      color: widget.document.isPdf ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.document.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.document.category} • ${widget.document.fileName} • ${widget.document.formattedFileSize}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_fileBytes != null)
                    ElevatedButton.icon(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _buildBody(),
            ),

            // Footer info bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (widget.document.issuingAuthority != null)
                    Expanded(
                      child: Text(
                        'Issuing Authority: ${widget.document.issuingAuthority}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.document.issueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Issued: ${widget.document.issueDate}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  if (widget.document.expiryDate != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Expires: ${widget.document.expiryDate}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.document.isExpired ? Colors.red : (widget.document.isExpiringSoon ? Colors.amber[800] : const Color(0xFF64748B)),
                        ),
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

  Widget _buildBody() {
    if (_isLocked) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Color(0xFFE11D48), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Password Protected Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'This file is encrypted with PBKDF2 vault protection. Enter the passcode to unlock and view.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passcodeController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Secret Passcode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                onSubmitted: (_) => _handleUnlock(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUnlocking ? null : _handleUnlock,
                  icon: _isUnlocking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open),
                  label: Text(_isUnlocking ? 'Verifying...' : 'Unlock Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Streaming document content from secure vault...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDocumentBytes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_fileBytes == null) {
      return const Center(child: Text('No file content available.'));
    }

    // 1. Image Preview
    if (widget.document.isImage) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              _fileBytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('Failed to render image file.', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
    }

    // 2. PDF Preview Card with Download and Inspection
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              widget.document.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.document.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(widget.document.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(widget.document.formattedFileSize, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('SECURITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(widget.document.confidentialityLevel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleDownload,
              icon: const Icon(Icons.file_download, size: 20),
              label: const Text('Download Official PDF Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}