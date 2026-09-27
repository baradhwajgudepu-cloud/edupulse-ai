import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

class ResetSchoolDataDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String schoolName;
  final String? tenantName;
  final VoidCallback? onResetComplete;

  const ResetSchoolDataDialog({
    super.key,
    required this.schoolId,
    required this.schoolName,
    this.tenantName,
    this.onResetComplete,
  });

  @override
  ConsumerState<ResetSchoolDataDialog> createState() => _ResetSchoolDataDialogState();
}

class _ResetSchoolDataDialogState extends ConsumerState<ResetSchoolDataDialog> {
  bool _isLoadingSummary = true;
  String? _summaryError;
  Map<String, dynamic>? _summaryData;
  String? _confirmationToken;

  late final TextEditingController _nameController;
  late final TextEditingController _reasonController;
  bool _isConfirmed = false;
  bool _isResetting = false;
  String? _resetError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _reasonController = TextEditingController();
    _fetchSummary();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.get<Map<String, dynamic>>(
        '/schools/${widget.schoolId}/data-summary',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data'] as Map<String, dynamic>?) ?? payload;
        },
      );

      if (!mounted) return;

      result.when(
        onSuccess: (data) {
          setState(() {
            _isLoadingSummary = false;
            _summaryData = data;
            _confirmationToken = data['confirmation_token'] as String?;
          });
        },
        onFailure: (failure) {
          setState(() {
            _isLoadingSummary = false;
            _summaryError = failure.message;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
        _summaryError = e.toString();
      });
    }
  }

  bool get _isNameMatched => _nameController.text.trim() == widget.schoolName.trim();

  bool get _isEligible => (_summaryData?['eligible'] as bool?) ?? false;

  List<String> get _queryErrors {
    final list = _summaryData?['query_errors'] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }

  List<String> get _blockingDependencies {
    final list = _summaryData?['blocking_dependencies'] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }

  bool get _canSubmit {
    return !_isLoadingSummary &&
        !_isResetting &&
        _summaryError == null &&
        _isEligible &&
        _queryErrors.isEmpty &&
        _blockingDependencies.isEmpty &&
        _confirmationToken != null &&
        _confirmationToken!.isNotEmpty &&
        _isNameMatched &&
        _isConfirmed &&
        _reasonController.text.trim().length >= 3;
  }

  Future<void> _handleReset() async {
    if (!_canSubmit) return;

    setState(() {
      _isResetting = true;
      _resetError = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.post<Map<String, dynamic>>(
        '/schools/${widget.schoolId}/reset-data',
        data: {
          'school_name': _nameController.text.trim(),
          'confirm_destruction': true,
          'reason': _reasonController.text.trim(),
          'confirmation_token': _confirmationToken ?? '',
        },
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data'] as Map<String, dynamic>?) ?? payload;
        },
      );

      if (!mounted) return;

      result.when(
        onSuccess: (data) {
          setState(() {
            _isResetting = false;
          });
          Navigator.of(context).pop(true);
          widget.onResetComplete?.call();
          _showSuccessDialog(data);
        },
        onFailure: (failure) {
          setState(() {
            _isResetting = false;
            _resetError = failure.message;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResetting = false;
        _resetError = e.toString();
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final auditId = data['audit_id'] ?? 'N/A';
    final totalDeleted = data['total_records_deleted'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
        title: const Text('School Data Reset Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All operational and onboarding data for "${widget.schoolName}" has been safely cleared.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Total records deleted: $totalDeleted', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('• School identity & ID: Preserved', style: TextStyle(color: Colors.green)),
                  const SizedBox(height: 4),
                  const Text('• User accounts & credentials: Preserved', style: TextStyle(color: Colors.green)),
                  const SizedBox(height: 4),
                  Text('• Audit Reference: $auditId', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The school onboarding status has been reset to Step 1. You may now upload a corrected workbook.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          FilledButton(
            key: const ValueKey('reset_success_done_button'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Proceed to Onboarding'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = Colors.red.shade700;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 780.0);
    final insetPadding = EdgeInsets.symmetric(
      horizontal: screenW < 600 ? 12 : 24,
      vertical: screenH < 600 ? 12 : 24,
    );

    return Dialog(
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(screenW < 600 ? 16.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: errorColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset School Data and Start Onboarding Again',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: errorColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Target School: ${widget.schoolName}${widget.tenantName != null ? ' (${widget.tenantName})' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isResetting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reset error banner if any
              if (_resetError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resetError!,
                          style: TextStyle(color: errorColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Query errors / Blocking dependencies warning banner
              if (_queryErrors.isNotEmpty || _blockingDependencies.isNotEmpty || (!_isLoadingSummary && _summaryError == null && !_isEligible))
                Container(
                  key: const ValueKey('reset_dependencies_error_banner'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.block, color: errorColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'UNRESOLVED DEPENDENCIES - RESET DISABLED',
                            style: TextStyle(color: errorColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The dry-run audit detected database query errors or unresolved dependencies. Data reset cannot proceed safely until all system queries succeed:',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      for (final err in _queryErrors)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text('• $err', style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                        ),
                      for (final dep in _blockingDependencies)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text('• $dep', style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                        ),
                    ],
                  ),
                ),

              // Body content
              Expanded(
                child: _isLoadingSummary
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Analyzing school operational records...'),
                          ],
                        ),
                      )
                    : _summaryError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, color: errorColor, size: 40),
                                const SizedBox(height: 8),
                                Text('Failed to load school summary: $_summaryError'),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _fetchSummary,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Safety and Warning Callout
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade400),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'CAUTION: This action is permanent and irreversible. Only operational data belonging exclusively to "${widget.schoolName}" will be erased. The school entity, tenant, user accounts, and administrator access will be strictly preserved.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Summary Breakdown
                                _buildSummarySection(),
                                const SizedBox(height: 16),

                                // Exact Name Confirmation Input
                                Text(
                                  'Confirm School Name *',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Type "${widget.schoolName}" exactly to confirm destruction:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  key: const ValueKey('reset_confirm_school_name_field'),
                                  controller: _nameController,
                                  enabled: !_isResetting,
                                  decoration: InputDecoration(
                                    hintText: widget.schoolName,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: _nameController.text.isNotEmpty
                                        ? Icon(
                                            _isNameMatched ? Icons.check_circle : Icons.cancel,
                                            color: _isNameMatched ? Colors.green : Colors.grey,
                                          )
                                        : null,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                // Reason Input
                                Text(
                                  'Reason for Reset (Required) *',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  key: const ValueKey('reset_reason_field'),
                                  controller: _reasonController,
                                  enabled: !_isResetting,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Timetable import failed rows; clearing operational data to re-import from Step 1.',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                // Checkbox Confirmation
                                CheckboxListTile(
                                  key: const ValueKey('reset_confirm_checkbox'),
                                  value: _isConfirmed,
                                  enabled: !_isResetting,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'I understand that this action is permanent, cannot be undone, and will reset onboarding to Step 1.',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 16),

              // Actions Footer
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('reset_cancel_button'),
                    onPressed: _isResetting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('reset_submit_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: errorColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _canSubmit ? _handleReset : null,
                    icon: _isResetting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever, size: 18),
                    label: Text(_isResetting ? 'Resetting Data...' : 'Permanently Reset School Data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final recordsToDelete = (_summaryData?['records_to_delete'] as Map<String, dynamic>?) ?? {};
    final recordsToPreserve = (_summaryData?['records_to_preserve'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Data to be deleted overview
        const Text(
          'Records to be Permanently Deleted:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: recordsToDelete.entries.map((e) {
              final count = e.value;
              final label = e.key.replaceAll('_', ' ').toUpperCase();
              return Chip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: CircleAvatar(
                  backgroundColor: count > 0 ? Colors.red.shade700 : Colors.grey.shade400,
                  radius: 8,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                label: Text(label, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.red.shade100),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Preserved overview
        const Text(
          'Protected System Entities (Preserved):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreservedRow(Icons.domain, 'Tenant Organization', recordsToPreserve['tenant']?.toString() ?? 'Preserved'),
              _buildPreservedRow(Icons.school, 'School Identity & Code', recordsToPreserve['school_identity']?.toString() ?? 'Preserved'),
              _buildPreservedRow(Icons.people_alt, 'User Accounts & Credentials', 'No users deleted (Logins remain active)'),
              _buildPreservedRow(Icons.admin_panel_settings, 'Administrator Access', 'Super Admin & Tenant Admin access preserved'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreservedRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Text('$title: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.green.shade900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
