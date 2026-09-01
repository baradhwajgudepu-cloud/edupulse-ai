import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/communication_provider.dart';
import 'package:edupulse_api/edupulse_api.dart';

class CreateQueryScreen extends ConsumerStatefulWidget {
  const CreateQueryScreen({super.key});

  @override
  ConsumerState<CreateQueryScreen> createState() => _CreateQueryScreenState();
}

class _CreateQueryScreenState extends ConsumerState<CreateQueryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  StudentProfile? _selectedStudent;
  String _recipientType = 'CLASS_TEACHER';
  String _category = 'ACADEMIC';
  String _priority = 'NORMAL';

  String? _attachmentName;
  Uint8List? _attachmentBytes;
  String? _attachmentMime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardState = ref.read(dashboardStateProvider);
      if (dashboardState is DashboardSuccess && dashboardState.data.students.isNotEmpty) {
        setState(() {
          _selectedStudent = dashboardState.data.selectedStudent ?? dashboardState.data.students.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final sizeMb = file.size / (1024 * 1024);
          if (sizeMb > 10.0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size exceeds the 10MB limit.')),
            );
            return;
          }
          setState(() {
            _attachmentName = file.name;
            _attachmentBytes = file.bytes;
            // Infer mime type or default
            _attachmentMime = _getMimeType(file.extension);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  String _getMimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedStudent == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final client = ref.read(communicationApiClientProvider);
    final createResult = await client.createRequest(
      studentId: _selectedStudent!.id,
      recipientType: _recipientType,
      category: _category,
      subject: _subjectController.text,
      priority: _priority,
      message: _messageController.text,
    );

    await createResult.when(
      onSuccess: (req) async {
        if (_attachmentBytes != null && _attachmentName != null) {
          // Fetch details to find the initial message id
          final detailResult = await client.getRequestDetails(req.id);
          await detailResult.when(
            onSuccess: (detail) async {
              if (detail.messages.isNotEmpty) {
                final messageId = detail.messages.first.id;
                await client.uploadAttachment(
                  messageId: messageId,
                  fileName: _attachmentName!,
                  fileBytes: _attachmentBytes!,
                  mimeType: _attachmentMime ?? 'application/octet-stream',
                );
              }
            },
            onFailure: (_) {},
          );
        }
        // Refresh list
        ref.read(queriesListProvider.notifier).fetchRequests(studentId: _selectedStudent!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request created successfully.')),
          );
          context.pop();
        }
      },
      onFailure: (failure) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create request: ${failure.message}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dashboardState = ref.watch(dashboardStateProvider);
    List<StudentProfile> students = [];
    if (dashboardState is DashboardSuccess) {
      students = dashboardState.data.students;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Connect Request'),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(spacing.md),
                children: [
                  // Student Selector
                  DropdownButtonFormField<StudentProfile>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'Select Child',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.face),
                    ),
                    items: students.map((std) {
                      return DropdownMenuItem(
                        value: std,
                        child: Text(std.fullName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedStudent = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please select a child' : null,
                  ),
                  SizedBox(height: spacing.md),

                  // Recipient Selector
                  DropdownButtonFormField<String>(
                    value: _recipientType,
                    decoration: const InputDecoration(
                      labelText: 'Send Request To',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_pin),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CLASS_TEACHER', child: Text('Class Teacher')),
                      DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principal')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _recipientType = val;
                        });
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic')),
                      DropdownMenuItem(value: 'ATTENDANCE', child: Text('Attendance')),
                      DropdownMenuItem(value: 'BEHAVIORAL', child: Text('Behavioral')),
                      DropdownMenuItem(value: 'FINANCIAL', child: Text('Financial / Fees')),
                      DropdownMenuItem(value: 'MEDICAL', child: Text('Medical')),
                      DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _category = val;
                        });
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),

                  // Priority Selector
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.priority_high),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Low')),
                      DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _priority = val;
                        });
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),

                  // Subject Text Box
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Please enter a subject' : null,
                  ),
                  SizedBox(height: spacing.md),

                  // Message Text Box
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                      alignLabelWithHint: true,
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Please enter a message description' : null,
                  ),
                  SizedBox(height: spacing.md),

                  // Attachment Selector
                  InkWell(
                    onTap: _pickAttachment,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: spacing.md, horizontal: spacing.sm),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(radius.sm),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, color: theme.colorScheme.primary),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Text(
                              _attachmentName ?? 'Attach Document or Image (Max 10MB)',
                              style: TextStyle(
                                color: _attachmentName != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          if (_attachmentName != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _attachmentName = null;
                                  _attachmentBytes = null;
                                  _attachmentMime = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.lg),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: spacing.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                    ),
                    child: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
