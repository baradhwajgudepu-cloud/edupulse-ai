import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_providers.dart';

class AttendanceCorrectionDialog extends StatefulWidget {
  final String sessionId;
  final String studentId;
  final String studentName;
  final String currentStatus;

  const AttendanceCorrectionDialog({
    super.key,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.currentStatus,
  });

  @override
  State<AttendanceCorrectionDialog> createState() => _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState extends State<AttendanceCorrectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _newStatus;

  @override
  void initState() {
    super.initState();
    // Default new status to current status if valid, otherwise empty
    _newStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final operationsState = ref.watch(attendanceOperationsProvider);
        final isLoading = operationsState.isLoading;

        return AlertDialog(
          title: const Text('Correct Attendance Record'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: ${widget.studentName}'),
                  const SizedBox(height: 8),
                  Text('Current Status: ${widget.currentStatus}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // New Status Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: const Key('correction_new_status_dropdown'),
                    value: _newStatus,
                    decoration: const InputDecoration(
                      labelText: 'New Status *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PRESENT', child: Text('PRESENT')),
                      DropdownMenuItem(value: 'ABSENT', child: Text('ABSENT')),
                      DropdownMenuItem(value: 'LATE', child: Text('LATE')),
                      DropdownMenuItem(value: 'HALF_DAY', child: Text('HALF_DAY')),
                      DropdownMenuItem(value: 'MEDICAL_LEAVE', child: Text('MEDICAL_LEAVE')),
                      DropdownMenuItem(value: 'EXCUSED', child: Text('EXCUSED')),
                      DropdownMenuItem(value: 'HOLIDAY', child: Text('HOLIDAY')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('ONLINE')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _newStatus = val;
                      });
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Correction Reason (Required)
                  TextFormField(
                    key: const Key('correction_reason_field'),
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Change *',
                      border: OutlineInputBorder(),
                      helperText: 'Required for administrative audit trail.',
                    ),
                    maxLines: 2,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Reason is required';
                      if (v.trim().length < 3) return 'Please provide a valid reason';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remarks (Optional)
                  TextFormField(
                    key: const Key('correction_remarks_field'),
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  // Display operations error if any
                  if (operationsState.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      operationsState.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_correction_btn'),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() == true) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Correction?'),
                            content: Text('Are you sure you want to change attendance status from "${widget.currentStatus}" to "$_newStatus"? This will be permanently recorded in the audit logs.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                key: const Key('confirm_correction_double_check_btn'),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes, Correct'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final success = await ref
                              .read(attendanceOperationsProvider.notifier)
                              .correctAttendance(
                                sessionId: widget.sessionId,
                                studentId: widget.studentId,
                                status: _newStatus!,
                                correctionReason: _reasonController.text.trim(),
                                remarks: _remarksController.text.trim(),
                              );

                          if (success && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Correction'),
            ),
          ],
        );
      },
    );
  }
}
