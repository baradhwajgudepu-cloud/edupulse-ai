import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../providers/teacher_leave_provider.dart';

class TeacherLeaveFormScreen extends ConsumerStatefulWidget {
  const TeacherLeaveFormScreen({super.key});

  @override
  ConsumerState<TeacherLeaveFormScreen> createState() => _TeacherLeaveFormScreenState();
}

class _TeacherLeaveFormScreenState extends ConsumerState<TeacherLeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();

  final List<Map<String, String>> _leaveTypes = [
    {'value': 'CASUAL', 'label': 'Casual Leave'},
    {'value': 'SICK', 'label': 'Sick Leave'},
    {'value': 'EARNED', 'label': 'Earned Leave'},
    {'value': 'EMERGENCY', 'label': 'Emergency Leave'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, reset end date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date first.')),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLeaveType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave type.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates.')),
      );
      return;
    }

    ref.read(teacherLeaveFormNotifierProvider.notifier).submitLeave(
      leaveType: _selectedLeaveType!,
      startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
      reason: _reasonController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final formState = ref.watch(teacherLeaveFormNotifierProvider);

    ref.listen<TeacherLeaveFormState>(teacherLeaveFormNotifierProvider, (prev, next) {
      if (next is TeacherLeaveFormSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully.')),
        );
        Navigator.of(context).pop();
      } else if (next is TeacherLeaveFormError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final isLoading = formState is TeacherLeaveFormLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Leave Request'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedLeaveType,
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _leaveTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: isLoading
                      ? null
                      : (val) {
                          setState(() {
                            _selectedLeaveType = val;
                          });
                        },
                  validator: (val) {
                    if (val == null) return 'Leave type is required';
                    return null;
                  },
                ),
                SizedBox(height: spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isLoading ? null : () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.date_range_rounded),
                          ),
                          child: Text(
                            _startDate == null
                                ? 'Select Start Date'
                                : DateFormat('yyyy-MM-dd').format(_startDate!),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: InkWell(
                        onTap: isLoading ? null : () => _selectEndDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.date_range_rounded),
                          ),
                          child: Text(
                            _endDate == null
                                ? 'Select End Date'
                                : DateFormat('yyyy-MM-dd').format(_endDate!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                TextFormField(
                  controller: _reasonController,
                  enabled: !isLoading,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Reason is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing.md),
                TextFormField(
                  controller: _remarksController,
                  enabled: !isLoading,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                    prefixIcon: Icon(Icons.comment_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                SizedBox(height: spacing.lg),
                ElevatedButton(
                  onPressed: isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.md),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Submit Leave Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
