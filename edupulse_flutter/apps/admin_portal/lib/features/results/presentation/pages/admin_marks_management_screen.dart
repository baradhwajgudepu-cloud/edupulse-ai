import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/admin_marks_models.dart';
import '../../data/models/examination_models.dart';
import '../providers/admin_marks_providers.dart';
import '../providers/examination_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../planner/presentation/providers/planner_providers.dart';
import '../../../tenant_setup/presentation/providers/tenant_providers.dart';
import '../../../../core/routing/routes.dart';

class AdminMarksManagementScreen extends ConsumerStatefulWidget {
  final String? initialExamId;
  final String? initialClassId;
  final String? initialSectionId;
  final String? initialAcademicYearId;

  const AdminMarksManagementScreen({
    super.key,
    this.initialExamId,
    this.initialClassId,
    this.initialSectionId,
    this.initialAcademicYearId,
  });

  @override
  ConsumerState<AdminMarksManagementScreen> createState() => _AdminMarksManagementScreenState();
}

class _AdminMarksManagementScreenState extends ConsumerState<AdminMarksManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContext();
    });
  }

  void _initializeContext() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId != null) {
      ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
      ref.read(classesProvider(schoolId).notifier).fetchClasses();
      ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      ref.read(examinationsProvider.notifier).loadExaminations();

      if (widget.initialAcademicYearId != null) {
        ref.read(adminMarksFiltersProvider.notifier).setAcademicYear(widget.initialAcademicYearId);
      }
      if (widget.initialExamId != null) {
        ref.read(adminMarksFiltersProvider.notifier).setExamination(widget.initialExamId);
      }
      if (widget.initialClassId != null) {
        ref.read(adminMarksFiltersProvider.notifier).setClass(widget.initialClassId);
      }
      if (widget.initialSectionId != null) {
        ref.read(adminMarksFiltersProvider.notifier).setSection(widget.initialSectionId);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showOverrideDialog(AdminStudentMarkRow row) {
    final controller = TextEditingController(text: row.marksObtained?.toString() ?? '');
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Administrative Override – ${row.fullName}'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roll No: ${row.rollNumber} | Max Marks: ${row.maxMarks}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'New Marks',
                    border: OutlineInputBorder(),
                    helperText: 'Enter numerical score',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Marks value required';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null) return 'Must be a valid number';
                    if (parsed < 0 || parsed > row.maxMarks) {
                      return 'Must be between 0 and ${row.maxMarks}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Override Reason (Mandatory)',
                    border: OutlineInputBorder(),
                    helperText: 'Audit justification for marks correction',
                  ),
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Override justification reason is mandatory';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newMarks = double.parse(controller.text.trim());
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                ref.read(adminMarksBoardProvider.notifier).applyAdministrativeOverride(
                  row.studentId,
                  newMarks,
                  reason,
                );
              }
            },
            child: const Text('Apply Override'),
          ),
        ],
      ),
    );
  }

  void _showUnlockDialog() {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.blue),
            SizedBox(width: 8),
            Text('Administrative Unlock'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unlocking this examination schedule will permit further marks edits. An administrative reason is required for auditing.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Unlock Reason',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Reason required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                ref.read(adminMarksBoardProvider.notifier).unlockMarks(reason);
              }
            },
            child: const Text('Confirm Unlock'),
          ),
        ],
      ),
    );
  }

  void _showUploadMarksDialog() {
    final filters = ref.read(adminMarksFiltersProvider);
    final activeSchedule = ref.read(adminMarksBoardProvider).activeSchedule;
    final availableExams = ref.read(examinationsProvider).examinations;
    final selectedExam = availableExams.firstWhere(
      (e) => e.id == filters.examinationId,
      orElse: () => ExaminationModel(
        id: filters.examinationId ?? '',
        tenantId: '',
        schoolId: '',
        academicYearId: '',
        examName: activeSchedule?.examName ?? 'Selected Examination',
        examType: 'EXAMINATION',
        startDate: '',
        endDate: '',
        status: ExamStatusEnum.draft,
        isActive: true,
        version: 1,
      ),
    );

    if (filters.examinationId == null && activeSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Examination first to upload marks.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int uploadMode = activeSchedule == null ? 0 : 1; // 0: Complete Exam, 1: Selected Class & Subject
    PlatformFile? selectedFile;
    bool isProcessing = false;
    String? uploadError;
    ExamWideUploadPreviewModel? examWidePreview;
    ExamWideUploadResultModel? examWideResult;
    Map<String, dynamic>? singleUploadResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isCompleteExamMode = uploadMode == 0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.table_chart_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(isCompleteExamMode ? 'Bulk Examination Marks Upload' : 'Upload Marks for Selected Subject'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Examination Context Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school, size: 18, color: Colors.indigo),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Examination: ${selectedExam.examName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                ),
                              ),
                            ],
                          ),
                          if (!isCompleteExamMode && activeSchedule != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Target: ${activeSchedule.className} ${activeSchedule.sectionName ?? ''} - ${activeSchedule.subjectName} (${activeSchedule.maxMarks} Marks)',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mode Selection
                    const Text('Upload Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            value: 0,
                            groupValue: uploadMode,
                            title: const Text('Complete Examination Dataset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Upload multiple classes, sections & subjects in one file', style: TextStyle(fontSize: 11)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: isProcessing
                                ? null
                                : (val) {
                                    setDialogState(() {
                                      uploadMode = val!;
                                      selectedFile = null;
                                      uploadError = null;
                                      examWidePreview = null;
                                    });
                                  },
                          ),
                        ),
                        if (activeSchedule != null)
                          Expanded(
                            child: RadioListTile<int>(
                              value: 1,
                              groupValue: uploadMode,
                              title: const Text('Selected Class & Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Upload only for active slot', style: TextStyle(fontSize: 11)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: isProcessing
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        uploadMode = val!;
                                        selectedFile = null;
                                        uploadError = null;
                                        examWidePreview = null;
                                      });
                                    },
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Step 1: Download Template
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Step 1: Download Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                isCompleteExamMode
                                    ? 'Download an Excel template containing all classes, sections & subjects for this exam.'
                                    : 'Download template for ${activeSchedule?.subjectName ?? 'selected subject'}.',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(isCompleteExamMode ? 'Download Exam Template' : 'Download Subject Template'),
                          onPressed: () {
                            if (isCompleteExamMode) {
                              final examId = filters.examinationId ?? activeSchedule?.examId;
                              if (examId != null) {
                                ref.read(adminMarksBoardProvider.notifier).downloadExamWideTemplate(
                                      examId: examId,
                                      examName: selectedExam.examName,
                                    );
                              }
                            } else {
                              ref.read(adminMarksBoardProvider.notifier).downloadMarksTemplate(format: 'xlsx');
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Step 2: Choose File
                    const Text('Step 2: Choose Excel or CSV File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isProcessing
                          ? null
                          : () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['xlsx', 'xls', 'csv'],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                setDialogState(() {
                                  selectedFile = result.files.first;
                                  uploadError = null;
                                  examWidePreview = null;
                                  examWideResult = null;
                                  singleUploadResult = null;
                                });

                                if (isCompleteExamMode && selectedFile?.bytes != null) {
                                  setDialogState(() => isProcessing = true);
                                  try {
                                    final examId = filters.examinationId ?? activeSchedule!.examId;
                                    final preview = await ref.read(adminMarksBoardProvider.notifier).previewExamWideUpload(
                                          examId: examId,
                                          fileBytes: selectedFile!.bytes!,
                                          fileName: selectedFile!.name,
                                        );
                                    setDialogState(() {
                                      examWidePreview = preview;
                                      isProcessing = false;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      uploadError = e.toString().replaceAll('Exception: ', '');
                                      isProcessing = false;
                                    });
                                  }
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: selectedFile != null ? Colors.indigo : Colors.grey.shade400, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                          color: selectedFile != null ? Colors.indigo.shade50.withAlpha(50) : Colors.grey.shade50,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedFile != null ? Icons.description : Icons.cloud_upload_outlined,
                                size: 32,
                                color: selectedFile != null ? Colors.indigo : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedFile != null ? selectedFile!.name : 'Click to select Excel / CSV file',
                                    style: TextStyle(
                                      fontWeight: selectedFile != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (selectedFile != null)
                                    Text(
                                      '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isProcessing) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Analyzing and validating file data...', style: TextStyle(fontSize: 13, color: Colors.indigo)),
                          ],
                        ),
                      ),
                    ],

                    if (uploadError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(uploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Step 3: Exam-Wide Validation Preview
                    if (examWidePreview != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: examWidePreview!.invalidRowsCount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: examWidePreview!.invalidRowsCount > 0 ? Colors.amber.shade300 : Colors.green.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  examWidePreview!.invalidRowsCount > 0 ? Icons.warning_amber : Icons.check_circle_outline,
                                  color: examWidePreview!.invalidRowsCount > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Validation Preview: ${examWidePreview!.validRowsCount} Valid / ${examWidePreview!.totalRows} Total Rows',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: examWidePreview!.invalidRowsCount > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text('${examWidePreview!.classesDetected.length} Classes: ${examWidePreview!.classesDetected.join(", ")}', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.white,
                                ),
                                Chip(
                                  label: Text('${examWidePreview!.sectionsDetected.length} Sections', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.white,
                                ),
                                Chip(
                                  label: Text('${examWidePreview!.subjectsDetected.length} Subjects: ${examWidePreview!.subjectsDetected.join(", ")}', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.white,
                                ),
                                Chip(
                                  label: Text('${examWidePreview!.studentsCount} Students Detected', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.white,
                                ),
                              ],
                            ),
                            if (examWidePreview!.errors.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('Validation Issues:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 120),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: examWidePreview!.errors.length,
                                  itemBuilder: (ctx, idx) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text('• ${examWidePreview!.errors[idx]}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Step 4: Final Success Result
                    if (examWideResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Bulk Examination Marks Import Complete!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Text('Examination: ${examWideResult!.examinationName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('• Students Processed: ${examWideResult!.studentsProcessed}'),
                            Text('• Classes Processed: ${examWideResult!.classesCount}'),
                            Text('• Sections Processed: ${examWideResult!.sectionsCount}'),
                            Text('• Subjects Processed: ${examWideResult!.subjectsCount}'),
                            Text('• Total Marks Records Saved: ${examWideResult!.savedCount} / ${examWideResult!.totalRecords}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ],

                    if (singleUploadResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Successfully saved marks for ${singleUploadResult!['savedCount']} students!',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (examWideResult != null) ...[
                TextButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('View Marks Management'),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Go to AI Intelligence'),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    context.push(AppRoutes.aiIntelligence);
                  },
                ),
              ] else ...[
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                if (!isCompleteExamMode)
                  FilledButton.icon(
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(isProcessing ? 'Uploading...' : 'Upload Subject Marks'),
                    onPressed: (selectedFile == null || isProcessing || selectedFile!.bytes == null)
                        ? null
                        : () async {
                            setDialogState(() {
                              isProcessing = true;
                              uploadError = null;
                            });
                            try {
                              final res = await ref.read(adminMarksBoardProvider.notifier).uploadMarksExcel(
                                    fileBytes: selectedFile!.bytes!,
                                    fileName: selectedFile!.name,
                                  );
                              setDialogState(() {
                                isProcessing = false;
                                singleUploadResult = res;
                              });
                              Future.delayed(const Duration(milliseconds: 1200), () {
                                if (dialogCtx.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                }
                              });
                            } catch (e) {
                              setDialogState(() {
                                isProcessing = false;
                                uploadError = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                    icon: const Icon(Icons.cloud_done, size: 16),
                    label: Text(isProcessing ? 'Importing...' : 'Import Complete Exam Marks (${examWidePreview?.validRowsCount ?? 0} rows)'),
                    onPressed: (examWidePreview == null || examWidePreview!.validRowsCount == 0 || isProcessing)
                        ? null
                        : () async {
                            setDialogState(() {
                              isProcessing = true;
                              uploadError = null;
                            });
                            try {
                              final examId = filters.examinationId ?? activeSchedule!.examId;
                              final res = await ref.read(adminMarksBoardProvider.notifier).confirmExamWideUpload(
                                    examId: examId,
                                    rows: examWidePreview!.previewRows.where((r) => r.isValid).toList(),
                                    autoApprove: true,
                                  );
                              setDialogState(() {
                                isProcessing = false;
                                examWideResult = res;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isProcessing = false;
                                uploadError = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showPublishExaminationDialog() {
    final filters = ref.read(adminMarksFiltersProvider);
    final availableExams = ref.read(examinationsProvider).examinations;
    final examId = filters.examinationId;
    if (examId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Examination first to publish.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedExam = availableExams.firstWhere(
      (e) => e.id == examId,
      orElse: () => ExaminationModel(
        id: examId,
        tenantId: '',
        schoolId: '',
        academicYearId: '',
        examName: 'Examination',
        examType: 'EXAMINATION',
        startDate: '',
        endDate: '',
        status: ExamStatusEnum.draft,
        isActive: true,
        version: 1,
      ),
    );

    bool isPublishing = false;
    String? publishError;
    ExaminationPublishSummaryModel? publishSummary;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Text('Publish Complete Examination'),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Examination: ${selectedExam.examName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          const SizedBox(height: 4),
                          const Text(
                            'Publishing will transition all entered marks across all classes and subjects to official PUBLISHED state, unlocking report card generation and live AI analytics.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isPublishing) ...[
                      const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Publishing examination marks...', style: TextStyle(fontSize: 13, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ],

                    if (publishError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text(publishError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],

                    if (publishSummary != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: publishSummary!.isFullyPublished ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: publishSummary!.isFullyPublished ? Colors.green.shade300 : Colors.amber.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  publishSummary!.isFullyPublished ? Icons.check_circle : Icons.warning_amber,
                                  color: publishSummary!.isFullyPublished ? Colors.green : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  publishSummary!.isFullyPublished
                                      ? 'Ready & Published Successfully!'
                                      : 'Partial Publication (${publishSummary!.missingCount} Missing Records)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: publishSummary!.isFullyPublished ? Colors.green.shade900 : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('• Total Expected Records: ${publishSummary!.totalExpectedRecords}'),
                            Text('• Published Records: ${publishSummary!.publishedCount}'),
                            Text('• Missing Records: ${publishSummary!.missingCount}'),
                            if (publishSummary!.missingBreakdown.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('Actionable Missing Subjects:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: publishSummary!.missingBreakdown.map((item) {
                                  return ActionChip(
                                    avatar: const Icon(Icons.arrow_forward, size: 14, color: Colors.deepOrange),
                                    label: Text('${item.className}-${item.sectionName} ${item.subjectName} (${item.missingCount} missing)'),
                                    backgroundColor: Colors.orange.shade50,
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      ref.read(adminMarksFiltersProvider.notifier).setClass(item.classId);
                                      ref.read(adminMarksFiltersProvider.notifier).setSection(item.sectionId);
                                      ref.read(adminMarksFiltersProvider.notifier).setSchedule(item.scheduleId);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(publishSummary != null ? 'Close' : 'Cancel'),
              ),
              if (publishSummary == null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('Publish Examination Now'),
                  onPressed: isPublishing
                      ? null
                      : () async {
                          setDialogState(() {
                            isPublishing = true;
                            publishError = null;
                          });
                          try {
                            final summary = await ref.read(adminMarksBoardProvider.notifier).publishCompleteExamination(
                                  examId: examId,
                                );
                            setDialogState(() {
                              isPublishing = false;
                              publishSummary = summary;
                            });
                          } catch (e) {
                            setDialogState(() {
                              isPublishing = false;
                              publishError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAuditHistoryDialog(AdminStudentMarkRow row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Audit History – ${row.fullName}'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: row.auditHistory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No historical corrections recorded for this student.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: row.auditHistory.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (ctx, idx) {
                    final item = row.auditHistory[idx];
                    final dateStr = item.updatedAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(item.updatedAt!)
                        : 'Unknown Date';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        item.action == 'LOCK'
                            ? Icons.lock
                            : item.action == 'UNLOCK'
                                ? Icons.lock_open
                                : Icons.edit_note,
                        color: Colors.blueGrey,
                      ),
                      title: Text(
                        item.action != null
                            ? 'Action: ${item.action}'
                            : '${item.oldMarks ?? 'None'}  ➔  ${item.newMarks ?? 'None'} Marks',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.reason != null && item.reason!.isNotEmpty)
                            Text('Reason: ${item.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                          Text('By: ${item.updatedBy} | $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
      if (prev != next && next != null) {
        _initializeContext();
      }
    });

    final schoolId = ref.watch(selectedSchoolIdProvider);
    final schoolName = ref.watch(selectedSchoolNameProvider);
    final activeTenantId = ref.watch(activeTenantIdProvider);
    final tenants = ref.watch(tenantsListProvider).tenants;
    final tenant = tenants.where((t) => t.id == activeTenantId).firstOrNull;
    final tenantName = tenant?.name ?? (activeTenantId ?? 'None');

    final filters = ref.watch(adminMarksFiltersProvider);
    final boardState = ref.watch(adminMarksBoardProvider);

    final ayState = schoolId != null ? ref.watch(academicYearsProvider(schoolId)) : null;
    final classesState = schoolId != null ? ref.watch(classesProvider(schoolId)) : null;
    final sectionsState = schoolId != null ? ref.watch(sectionsProvider(schoolId)) : null;
    final examsAsync = ref.watch(marksExaminationsProvider(filters.academicYearId));
    final availableExams = examsAsync.value ?? [];

    final selectedExam = filters.examinationId != null
        ? availableExams.where((e) => e.id == filters.examinationId).firstOrNull
        : null;

    // 2. Available Classes (Filtered by Examination participating classes)
    final availableClasses = (classesState?.classes ?? []).where((c) {
      if (selectedExam != null && selectedExam.participatingClassIds.isNotEmpty) {
        return selectedExam.participatingClassIds.contains(c.id);
      }
      return true;
    }).toList();

    // 3. Available Sections (Filtered by Selected Class)
    final availableSections = (sectionsState?.sections ?? []).where((s) {
      return filters.classId == null || s.classId == filters.classId;
    }).toList();

    // 4. Schedules Query
    final schedulesAsync = filters.examinationId != null
        ? ref.watch(marksExamSchedulesProvider(filters.examinationId!))
        : const AsyncValue.data(<AdminExamScheduleOption>[]);

    final schedules = schedulesAsync.value ?? [];

    // Filter schedules matching Class and Section
    final availableSchedules = schedules.where((s) {
      if (filters.classId != null && s.classId != filters.classId) return false;
      if (filters.sectionId != null && s.sectionId != null && s.sectionId != filters.sectionId) return false;
      return true;
    }).toList();

    // Cascading selection validation
    final selectedAyId = (ayState?.years ?? []).any((ay) => ay.id == filters.academicYearId)
        ? filters.academicYearId
        : null;
    final selectedExamId = availableExams.any((e) => e.id == filters.examinationId)
        ? filters.examinationId
        : null;
    final selectedClassId = availableClasses.any((c) => c.id == filters.classId)
        ? filters.classId
        : null;
    final selectedSectionId = availableSections.any((s) => s.id == filters.sectionId)
        ? filters.sectionId
        : null;
    final selectedScheduleId = availableSchedules.any((s) => s.id == filters.scheduleId)
        ? filters.scheduleId
        : null;

    final isLoadEnabled = selectedAyId != null &&
        selectedExamId != null &&
        selectedClassId != null &&
        selectedSectionId != null &&
        selectedScheduleId != null &&
        !boardState.isLoading;

    // Filter student rows by search query
    final query = _searchController.text.toLowerCase().trim();
    final displayedRows = boardState.rows.where((row) {
      if (query.isEmpty) return true;
      return row.fullName.toLowerCase().contains(query) || row.rollNumber.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrative Marks Management Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Board',
            onPressed: () {
              ref.invalidate(marksExaminationsProvider(filters.academicYearId));
              if (filters.examinationId != null) {
                ref.invalidate(marksExamSchedulesProvider(filters.examinationId!));
              }
              if (selectedScheduleId != null) {
                final target = availableSchedules.firstWhere((s) => s.id == selectedScheduleId);
                ref.read(adminMarksBoardProvider.notifier).loadMarksForSchedule(target);
              }
            },
          ),
          if (boardState.hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                avatar: const Icon(Icons.warning, size: 16, color: Colors.white),
                label: const Text('Unsaved Changes', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.amber.shade800,
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Diagnostic Context Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Context: Tenant: $tenantName ($activeTenantId) | School: $schoolName ($schoolId)',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Filters Bar
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Academic Year
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: selectedAyId,
                      decoration: const InputDecoration(labelText: 'Academic Year', isDense: true, border: OutlineInputBorder()),
                      items: (ayState?.years ?? []).map((ay) {
                        return DropdownMenuItem(value: ay.id, child: Text(ay.name, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        ref.read(adminMarksFiltersProvider.notifier).setAcademicYear(val);
                        ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                      },
                    ),
                  ),

                  // Examination
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: selectedExamId,
                      decoration: InputDecoration(
                        labelText: 'Examination',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: filters.academicYearId == null
                            ? 'Select Academic Year first'
                            : (examsAsync.isLoading
                                ? 'Loading examinations...'
                                : (examsAsync.hasError
                                    ? 'Failed to load examinations'
                                    : (availableExams.isEmpty
                                        ? 'No examinations found'
                                        : 'Select Examination'))),
                      ),
                      items: availableExams.map((ex) {
                        return DropdownMenuItem(value: ex.id, child: Text(ex.examName, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: availableExams.isEmpty
                          ? null
                          : (val) {
                              ref.read(adminMarksFiltersProvider.notifier).setExamination(val);
                              ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                            },
                    ),
                  ),

                  // Class
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: selectedClassId,
                      decoration: InputDecoration(
                        labelText: 'Class',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: availableClasses.isEmpty ? 'No classes' : 'Select Class',
                      ),
                      items: availableClasses.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: availableClasses.isEmpty
                          ? null
                          : (val) {
                              ref.read(adminMarksFiltersProvider.notifier).setClass(val);
                              ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                            },
                    ),
                  ),

                  // Section
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: selectedSectionId,
                      decoration: InputDecoration(
                        labelText: 'Section',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: filters.classId == null
                            ? 'Select Class first'
                            : (availableSections.isEmpty ? 'No sections' : 'Select Section'),
                      ),
                      items: availableSections.map((sec) {
                        return DropdownMenuItem(value: sec.id, child: Text(sec.name, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: availableSections.isEmpty
                          ? null
                          : (val) {
                              ref.read(adminMarksFiltersProvider.notifier).setSection(val);
                              ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                            },
                    ),
                  ),

                  // Subject / Schedule Slot
                  SizedBox(
                    width: 270,
                    child: DropdownButtonFormField<String>(
                      value: selectedScheduleId,
                      decoration: InputDecoration(
                        labelText: 'Subject Slot',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: filters.examinationId == null
                            ? 'Select Examination first'
                            : (filters.classId == null
                                ? 'Select Class first'
                                : (filters.sectionId == null
                                    ? 'Select Section first'
                                    : (schedulesAsync.isLoading
                                        ? 'Loading subject papers...'
                                        : (schedulesAsync.hasError
                                            ? 'Failed to load papers'
                                            : (availableSchedules.isEmpty
                                                ? 'No papers scheduled'
                                                : 'Select Paper'))))),
                      ),
                      items: availableSchedules.map((s) {
                        final label = '${s.subjectName} (${s.maxMarks} Marks)';
                        return DropdownMenuItem(value: s.id, child: Text(label, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: availableSchedules.isEmpty
                          ? null
                          : (val) {
                              ref.read(adminMarksFiltersProvider.notifier).setSchedule(val);
                            },
                    ),
                  ),

                  // Load Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Load Marks'),
                    onPressed: isLoadEnabled
                        ? () {
                            final target = availableSchedules.firstWhere((s) => s.id == selectedScheduleId);
                            ref.read(adminMarksBoardProvider.notifier).loadMarksForSchedule(target);
                          }
                        : null,
                  ),

                  // Bulk Upload Button (Exam-wide or Single subject)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Upload Excel / CSV'),
                    onPressed: (selectedExamId == null && boardState.activeSchedule == null)
                        ? null
                        : _showUploadMarksDialog,
                  ),

                  // Publish Complete Examination Button
                  if (selectedExamId != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      icon: const Icon(Icons.verified),
                      label: const Text('Publish Examination'),
                      onPressed: _showPublishExaminationDialog,
                    ),
                ],
              ),
            ),
          ),

          // Contextual Empty State Banner for Missing Schedules
          if (filters.examinationId != null &&
              filters.classId != null &&
              filters.sectionId != null &&
              !schedulesAsync.isLoading &&
              availableSchedules.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                border: Border.all(color: const Color(0xFFFFE082)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No examination papers are scheduled for this class and section.',
                                style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            context.push('${AppRoutes.plannerExams}?examId=${filters.examinationId}');
                          },
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: const Text('Go to Examination Setup'),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No examination papers are scheduled for this class and section.',
                          style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          context.push('${AppRoutes.plannerExams}?examId=${filters.examinationId}');
                        },
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: const Text('Go to Examination Setup'),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Messages Banner
          if (boardState.errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(boardState.errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                ],
              ),
            ),

          if (boardState.successMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(boardState.successMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                ],
              ),
            ),

          // KPI Summary Row (RenderFlex Protected)
          if (boardState.activeSchedule != null && boardState.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildKpiCard('Total Students', '${boardState.totalStudents}', Icons.people, Colors.blue),
                    const SizedBox(width: 8),
                    _buildKpiCard('Marks Entered', '${boardState.enteredCount}', Icons.check_circle, Colors.green),
                    const SizedBox(width: 8),
                    _buildKpiCard('Marks Missing', '${boardState.missingCount}', Icons.pending, Colors.orange),
                    const SizedBox(width: 8),
                    _buildKpiCard('Class Average', boardState.classAverage.toStringAsFixed(1), Icons.calculate, Colors.purple),
                    const SizedBox(width: 8),
                    _buildKpiCard('Highest Marks', '${boardState.highestMarks}', Icons.trending_up, Colors.teal),
                    const SizedBox(width: 8),
                    _buildKpiCard('Lowest Marks', '${boardState.lowestMarks}', Icons.trending_down, Colors.deepOrange),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Action Toolbar & Search (Responsive LayoutBuilder & Wrap)
          if (boardState.activeSchedule != null && boardState.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth < 600 ? constraints.maxWidth : 260,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search Students',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Upload Excel / CSV'),
                        onPressed: boardState.isSaving ? null : _showUploadMarksDialog,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Marks'),
                        onPressed: boardState.isSaving ? null : () => ref.read(adminMarksBoardProvider.notifier).bulkSaveMarks(submit: false),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        icon: const Icon(Icons.publish),
                        label: const Text('Publish Marks'),
                        onPressed: boardState.isSaving
                            ? null
                            : () => ref.read(adminMarksBoardProvider.notifier).publishMarks(),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        icon: const Icon(Icons.lock),
                        label: const Text('Lock Marks'),
                        onPressed: boardState.isSaving
                            ? null
                            : () => ref.read(adminMarksBoardProvider.notifier).lockMarks(),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unlock Marks'),
                        onPressed: boardState.isSaving ? null : _showUnlockDialog,
                      ),
                    ],
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Main Table Area
          Expanded(
            child: boardState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : boardState.rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildEmptyStateContent(
                            context: context,
                            filters: filters,
                            availableExams: availableExams,
                            availableClasses: availableClasses,
                            availableSections: availableSections,
                            availableSchedules: availableSchedules,
                            boardState: boardState,
                          ),
                        ),
                      )
                    : Card(
                        margin: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              columns: const [
                                DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Max', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Obtained Marks', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Lifecycle', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: displayedRows.map((row) {
                                final isAbsent = row.resultStatus == AdminMarkResultStatus.absent;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(row.rollNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(row.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (row.validationError != null)
                                            Text(row.validationError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('${row.maxMarks}')),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          initialValue: row.marksObtained?.toString() ?? '',
                                          enabled: !isAbsent && row.status != AdminMarkStatus.locked,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            border: const OutlineInputBorder(),
                                            errorText: row.validationError,
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (val) {
                                            final parsed = val.trim().isEmpty ? null : double.tryParse(val.trim());
                                            ref.read(adminMarksBoardProvider.notifier).updateStudentMark(row.studentId, parsed);
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      DropdownButton<AdminMarkResultStatus>(
                                        value: row.resultStatus,
                                        isDense: true,
                                        underline: const SizedBox(),
                                        items: const [
                                          DropdownMenuItem(value: AdminMarkResultStatus.present, child: Text('Present')),
                                          DropdownMenuItem(value: AdminMarkResultStatus.absent, child: Text('Absent', style: TextStyle(color: Colors.red))),
                                          DropdownMenuItem(value: AdminMarkResultStatus.exempted, child: Text('Exempted', style: TextStyle(color: Colors.orange))),
                                          DropdownMenuItem(value: AdminMarkResultStatus.malpractice, child: Text('Malpractice', style: TextStyle(color: Colors.purple))),
                                        ],
                                        onChanged: row.status == AdminMarkStatus.locked
                                            ? null
                                            : (newStatus) {
                                                if (newStatus != null) {
                                                  ref.read(adminMarksBoardProvider.notifier).updateStudentStatus(row.studentId, newStatus);
                                                }
                                              },
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 160,
                                        child: TextFormField(
                                          initialValue: row.remarks ?? '',
                                          enabled: row.status != AdminMarkStatus.locked,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            border: OutlineInputBorder(),
                                            hintText: 'Optional remark',
                                          ),
                                          onChanged: (val) {
                                            ref.read(adminMarksBoardProvider.notifier).updateStudentRemarks(row.studentId, val);
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          row.status.toBackendValue(),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: _getLifecycleColor(row.status),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                                            tooltip: 'Administrative Override',
                                            onPressed: () => _showOverrideDialog(row),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.history, color: Colors.blueGrey, size: 20),
                                            tooltip: 'Audit History',
                                            onPressed: () => _showAuditHistoryDialog(row),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateContent({
    required BuildContext context,
    required AdminMarksFiltersState filters,
    required List<ExaminationModel> availableExams,
    required List<dynamic> availableClasses,
    required List<dynamic> availableSections,
    required List<AdminExamScheduleOption> availableSchedules,
    required AdminMarksBoardState boardState,
  }) {
    if (boardState.activeSchedule != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'No students enrolled for this class and section.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      );
    }

    if (filters.academicYearId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Select an Academic Year to get started.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }

    if (filters.examinationId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            availableExams.isEmpty
                ? 'No examinations found for the selected Academic Year.'
                : 'Select an Examination to continue.',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          if (availableExams.isEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.examinations),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Examination in Setup'),
            ),
          ],
        ],
      );
    }

    if (availableClasses.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined, size: 48, color: Colors.orange[300]),
          const SizedBox(height: 12),
          const Text(
            'No participating classes configured for this examination.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Assign participating classes to this examination in Examination Setup.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push('${AppRoutes.examinations}?examId=${filters.examinationId}'),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Configure Classes in Examination Setup'),
          ),
        ],
      );
    }

    if (filters.classId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Select a Class to continue.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }

    if (availableSections.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 48, color: Colors.orange[300]),
          const SizedBox(height: 12),
          const Text(
            'No sections available for the selected class.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    if (filters.sectionId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Select a Section to continue.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }

    if (availableSchedules.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 48, color: Colors.amber[700]),
          const SizedBox(height: 12),
          const Text(
            'No examination papers are scheduled for this selection.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure timetable papers for this class and section to enable marks entry.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push('${AppRoutes.plannerExams}?examId=${filters.examinationId}'),
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text('Go to Examination Setup'),
          ),
        ],
      );
    }

    if (filters.scheduleId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 48, color: Colors.blue[400]),
          const SizedBox(height: 12),
          const Text(
            'Select a Subject Slot and click "Load Marks".',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.download_outlined, size: 48, color: Colors.blue[400]),
        const SizedBox(height: 12),
        const Text(
          'Click "Load Marks" above to load student records.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 0,
        color: color.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLifecycleColor(AdminMarkStatus status) {
    switch (status) {
      case AdminMarkStatus.draft:
        return Colors.grey.shade200;
      case AdminMarkStatus.submitted:
        return Colors.blue.shade100;
      case AdminMarkStatus.approved:
        return Colors.amber.shade100;
      case AdminMarkStatus.published:
        return Colors.green.shade100;
      case AdminMarkStatus.locked:
        return Colors.purple.shade100;
    }
  }
}
