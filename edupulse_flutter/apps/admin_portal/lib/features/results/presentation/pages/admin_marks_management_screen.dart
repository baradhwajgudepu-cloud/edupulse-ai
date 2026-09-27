import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import '../../data/models/admin_marks_models.dart';
import '../../data/models/examination_models.dart';
import '../providers/admin_marks_providers.dart';
import '../providers/examination_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
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
    final schoolId = ref.read(selectedSchoolIdProvider);
    final filters = ref.read(adminMarksFiltersProvider);
    final activeSchedule = ref.read(adminMarksBoardProvider).activeSchedule;
    final examsList = ref.read(marksExaminationsProvider(filters.academicYearId)).value ??
        ref.read(examinationsProvider).examinations;
    final selectedExam = examsList.firstWhere(
      (e) => e.id == filters.examinationId,
      orElse: () => ExaminationModel(
        id: filters.examinationId ?? activeSchedule?.examId ?? '',
        tenantId: '',
        schoolId: schoolId ?? '',
        academicYearId: filters.academicYearId ?? '',
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

    final classesState = schoolId != null ? ref.read(classesProvider(schoolId)) : null;
    final sectionsState = schoolId != null ? ref.read(sectionsProvider(schoolId)) : null;

    final allClasses = classesState?.classes ?? const <ClassDto>[];
    final allSections = sectionsState?.sections ?? const <SectionDto>[];

    final classIdToName = <String, String>{
      for (final c in allClasses) c.id: c.name,
    };

    // Determine exam schedules to enforce valid schedules for upload
    final cachedSchedules = filters.examinationId != null
        ? ref.read(marksExamSchedulesProvider(filters.examinationId!)).value
        : null;
    final scheduledClassIds = cachedSchedules != null
        ? cachedSchedules.map((s) => s.classId).toSet()
        : selectedExam.schedules.map((s) => s.classId).toSet();
    final hasSchedules = cachedSchedules != null
        ? cachedSchedules.isNotEmpty
        : selectedExam.schedules.isNotEmpty;

    // Scheduled classes for this examination
    final uploadableClasses = scheduledClassIds.isNotEmpty
        ? allClasses.where((c) => scheduledClassIds.contains(c.id)).toList()
        : (selectedExam.participatingClassIds.isNotEmpty
            ? allClasses.where((c) => selectedExam.participatingClassIds.contains(c.id)).toList()
            : allClasses);

    String? selectedClassId = filters.classId ?? activeSchedule?.classId;
    if (selectedClassId == null || !uploadableClasses.any((c) => c.id == selectedClassId)) {
      selectedClassId = uploadableClasses.isNotEmpty ? uploadableClasses.first.id : null;
    }

    List<SectionDto> getSectionsForClass(String? classId) {
      if (classId == null) return allSections;
      return allSections.where((s) => s.classId == classId).toList();
    }

    var availableSectionsForClass = getSectionsForClass(selectedClassId);
    String? selectedSectionId = filters.sectionId ?? activeSchedule?.sectionId;
    if (selectedSectionId == null || !availableSectionsForClass.any((s) => s.id == selectedSectionId)) {
      selectedSectionId = availableSectionsForClass.isNotEmpty ? availableSectionsForClass.first.id : null;
    }

    // 0: Complete Exam, 1: Selected Class & Subject, 2: Selected Class & All Subjects
    int uploadMode = activeSchedule != null ? 1 : 2;
    PlatformFile? selectedFile;
    bool isProcessing = false;
    String? uploadError;
    ExamWideUploadPreviewModel? examWidePreview;
    ExamWideUploadResultModel? examWideResult;
    Map<String, dynamic>? singleUploadResult;
    ClassAllSubjectsUploadResultModel? classAllSubjectsResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isCompleteExamMode = uploadMode == 0;
          final isSingleSubjectMode = uploadMode == 1;
          final isClassAllSubjectsMode = uploadMode == 2;

          String dialogTitleText;
          if (isCompleteExamMode) {
            dialogTitleText = 'Bulk Examination Marks Upload';
          } else if (isClassAllSubjectsMode) {
            dialogTitleText = 'Upload Marks (Selected Class & All Subjects)';
          } else {
            dialogTitleText = 'Upload Marks for Selected Subject';
          }

          final currentSections = getSectionsForClass(selectedClassId);
          final currentClassName = allClasses.where((c) => c.id == selectedClassId).firstOrNull?.name ?? 'Class';
          final currentSectionName = allSections.where((s) => s.id == selectedSectionId).firstOrNull?.name ?? 'Section';

          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth < 740 ? screenWidth * 0.94 : 700.0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.table_chart_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dialogTitleText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
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
                                  selectedExam.getDisambiguatedTitle(classIdToName: classIdToName),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                ),
                              ),
                            ],
                          ),
                          if (isSingleSubjectMode && activeSchedule != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Target: ${activeSchedule.className} ${activeSchedule.sectionName ?? ''} - ${displaySubjectName(subjectName: activeSchedule.subjectName, subjectCode: activeSchedule.subjectCode, subjectId: activeSchedule.subjectId)} (${activeSchedule.maxMarks} Marks)',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                          if (isClassAllSubjectsMode) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Target: $currentClassName $currentSectionName • All Scheduled Subjects',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!hasSchedules) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This examination has no scheduled papers configured. Please configure examination schedules before uploading marks.',
                                style: TextStyle(color: Colors.brown, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Mode Selection
                    const Text('Upload Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Column(
                      children: [
                        RadioListTile<int>(
                          value: 2,
                          groupValue: uploadMode,
                          title: const Text('Selected Class & All Subjects (Recommended)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Upload marks for all subjects for one class + section in a single sheet', style: TextStyle(fontSize: 11)),
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
                                    examWideResult = null;
                                    singleUploadResult = null;
                                    classAllSubjectsResult = null;
                                  });
                                },
                        ),
                        RadioListTile<int>(
                          value: 0,
                          groupValue: uploadMode,
                          title: const Text('Complete Examination Dataset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Upload multiple classes, sections & subjects across the entire exam', style: TextStyle(fontSize: 11)),
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
                                    examWideResult = null;
                                    singleUploadResult = null;
                                    classAllSubjectsResult = null;
                                  });
                                },
                        ),
                        RadioListTile<int>(
                          value: 1,
                          groupValue: uploadMode,
                          title: const Text('Selected Class & Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            activeSchedule != null
                                ? 'Upload only for ${displaySubjectName(subjectName: activeSchedule.subjectName, subjectCode: activeSchedule.subjectCode, subjectId: activeSchedule.subjectId)} (${activeSchedule.className})'
                                : 'Upload single subject (Select an active slot first in timetable view)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (isProcessing || activeSchedule == null)
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    uploadMode = val!;
                                    selectedFile = null;
                                    uploadError = null;
                                    examWidePreview = null;
                                    examWideResult = null;
                                    singleUploadResult = null;
                                    classAllSubjectsResult = null;
                                  });
                                },
                        ),
                      ],
                    ),

                    // When Mode 2 is selected: Class & Section selector with automatic subject notice
                    if (isClassAllSubjectsMode) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Class & Section Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: DropdownButtonFormField<String>(
                                    value: selectedClassId,
                                    isDense: true,
                                     decoration: InputDecoration(
                                       labelText: 'Class',
                                       contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                       border: const OutlineInputBorder(),
                                       hintText: uploadableClasses.isEmpty ? 'No scheduled classes' : 'Select Class',
                                     ),
                                     items: uploadableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 12)))).toList(),
                                     onChanged: (isProcessing || uploadableClasses.isEmpty)
                                         ? null
                                         : (val) {
                                             if (val != null) {
                                               setDialogState(() {
                                                 selectedClassId = val;
                                                 final secs = getSectionsForClass(val);
                                                 selectedSectionId = secs.isNotEmpty ? secs.first.id : null;
                                                 selectedFile = null;
                                                 uploadError = null;
                                                 classAllSubjectsResult = null;
                                               });
                                             }
                                           },
                                   ),
                                 ),
                                 SizedBox(
                                   width: 180,
                                   child: DropdownButtonFormField<String>(
                                     value: selectedSectionId,
                                     isDense: true,
                                     decoration: InputDecoration(
                                       labelText: 'Section',
                                       contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                       border: const OutlineInputBorder(),
                                       hintText: currentSections.isEmpty ? 'No sections' : 'Select Section',
                                     ),
                                     items: currentSections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12)))).toList(),
                                     onChanged: (isProcessing || currentSections.isEmpty)
                                        ? null
                                        : (val) {
                                            setDialogState(() {
                                              selectedSectionId = val;
                                              selectedFile = null;
                                              uploadError = null;
                                              classAllSubjectsResult = null;
                                            });
                                          },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.indigo.shade200),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 14, color: Colors.indigo),
                                      SizedBox(width: 4),
                                      Text('Subject: All Subjects (Automatic)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

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
                                    : (isClassAllSubjectsMode
                                        ? 'Download template with columns for all subjects scheduled for $currentClassName $currentSectionName.'
                                        : 'Download template for ${displaySubjectName(subjectName: activeSchedule?.subjectName, subjectCode: activeSchedule?.subjectCode, subjectId: activeSchedule?.subjectId)}.'),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(
                            isCompleteExamMode
                                ? 'Download Exam Template'
                                : (isClassAllSubjectsMode ? 'Download All Subjects Template' : 'Download Subject Template'),
                          ),
                          onPressed: () {
                            if (isCompleteExamMode) {
                              final examId = filters.examinationId ?? activeSchedule?.examId;
                              if (examId != null) {
                                ref.read(adminMarksBoardProvider.notifier).downloadExamWideTemplate(
                                      examId: examId,
                                      examName: selectedExam.examName,
                                    );
                              }
                            } else if (isClassAllSubjectsMode) {
                              final examId = filters.examinationId ?? activeSchedule?.examId;
                              if (examId != null && selectedClassId != null && selectedSectionId != null) {
                                ref.read(adminMarksBoardProvider.notifier).downloadClassAllSubjectsTemplate(
                                      examId: examId,
                                      classId: selectedClassId!,
                                      sectionId: selectedSectionId!,
                                      className: currentClassName,
                                      sectionName: currentSectionName,
                                    );
                              } else {
                                setDialogState(() {
                                  uploadError = 'Please choose both Class and Section to download template.';
                                });
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
                                  classAllSubjectsResult = null;
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
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFile != null ? selectedFile!.name : 'Click to select Excel / CSV file',
                                      overflow: TextOverflow.ellipsis,
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
                            Text('Analyzing and processing file data...', style: TextStyle(fontSize: 13, color: Colors.indigo)),
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

                    // Step 3: Exam-Wide Validation Preview (Mode 0)
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

                    // Mode 2 Result Summary
                    if (classAllSubjectsResult != null) ...[
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
                                Expanded(
                                  child: Text(
                                    'Class All-Subjects Marks Upload Complete!',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Text(
                              'Target: ${classAllSubjectsResult!.className} ${classAllSubjectsResult!.sectionName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text('• Students Processed: ${classAllSubjectsResult!.totalStudentsProcessed}'),
                                Text('• Subjects Detected: ${classAllSubjectsResult!.totalSubjectsDetected}'),
                                Text('• Records Created: ${classAllSubjectsResult!.totalMarksCreated}'),
                                Text('• Records Updated: ${classAllSubjectsResult!.totalMarksUpdated}'),
                                if (classAllSubjectsResult!.failedRows > 0)
                                  Text('• Failed Rows: ${classAllSubjectsResult!.failedRows}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (classAllSubjectsResult!.validationErrors.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Validation Warnings / Errors (${classAllSubjectsResult!.validationErrors.length}):',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 120),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: classAllSubjectsResult!.validationErrors.length,
                                  itemBuilder: (ctx, idx) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                    child: Text(
                                      '• ${classAllSubjectsResult!.validationErrors[idx]}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Mode 0 Result Summary
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

                    // Mode 1 Result Summary
                    if (singleUploadResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Successfully saved marks for ${singleUploadResult!['savedCount']} students!',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
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
              if (examWideResult != null || classAllSubjectsResult != null) ...[
                TextButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Close & Refresh Board'),
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
                if (isClassAllSubjectsMode)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(isProcessing ? 'Uploading...' : 'Upload All Subjects Marks'),
                    onPressed: (selectedFile == null || isProcessing || selectedFile!.bytes == null || selectedClassId == null || selectedSectionId == null)
                        ? null
                        : () async {
                            setDialogState(() {
                              isProcessing = true;
                              uploadError = null;
                            });
                            try {
                              final examId = filters.examinationId ?? activeSchedule!.examId;
                              final res = await ref.read(adminMarksBoardProvider.notifier).uploadClassAllSubjectsMarks(
                                    examId: examId,
                                    classId: selectedClassId!,
                                    sectionId: selectedSectionId!,
                                    fileBytes: selectedFile!.bytes!,
                                    fileName: selectedFile!.name,
                                  );
                              setDialogState(() {
                                isProcessing = false;
                                classAllSubjectsResult = res;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isProcessing = false;
                                uploadError = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                  )
                else if (isSingleSubjectMode)
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
                                    label: Text('${item.className}-${item.sectionName} ${displaySubjectName(subjectName: item.subjectName, subjectCode: item.subjectCode, subjectId: item.subjectId)} (${item.missingCount} missing)'),
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

    // 4. Schedules Query (queried early to derive effective class scope)
    final schedulesAsync = filters.examinationId != null
        ? ref.watch(marksExamSchedulesProvider(filters.examinationId!))
        : const AsyncValue.data(<AdminExamScheduleOption>[]);

    final schedules = schedulesAsync.value ?? [];

    // Effective class scope = participatingClassIds UNION scheduled classes
    final effectiveClassIds = <String>{
      if (selectedExam != null) ...selectedExam.effectiveClassIds,
      ...schedules.map((s) => s.classId),
    };

    // Class ID to name lookup map for disambiguated labels
    final classIdToName = <String, String>{
      for (final c in classesState?.classes ?? const <ClassDto>[]) c.id: c.name,
    };

    // 2. Available Classes (Filtered by Examination effective class scope)
    final availableClasses = (classesState?.classes ?? const <ClassDto>[]).where((c) {
      if (selectedExam != null && effectiveClassIds.isNotEmpty) {
        return effectiveClassIds.contains(c.id);
      }
      return true;
    }).toList();

    // 3. Available Sections (Filtered by Selected Class)
    final availableSections = (sectionsState?.sections ?? const <SectionDto>[]).where((s) {
      return filters.classId == null || s.classId == filters.classId;
    }).toList();

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

    // Post-frame cleanup for stale cascading filter selections
    if (filters.academicYearId != null && selectedAyId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminMarksFiltersProvider.notifier).setAcademicYear(null);
      });
    }
    if (filters.examinationId != null && selectedExamId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminMarksFiltersProvider.notifier).setExamination(null);
      });
    }
    if (filters.classId != null && selectedClassId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminMarksFiltersProvider.notifier).setClass(null);
      });
    }
    if (filters.sectionId != null && selectedSectionId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminMarksFiltersProvider.notifier).setSection(null);
      });
    }
    if (filters.scheduleId != null && selectedScheduleId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminMarksFiltersProvider.notifier).setSchedule(null);
      });
    }

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
          OutlinedButton.icon(
            key: const Key('header_import_marks_board_btn'),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Import Marks'),
            onPressed: () {
              final queryParams = <String, String>{};
              if (selectedExamId != null) queryParams['exam_id'] = selectedExamId;
              if (selectedClassId != null) queryParams['class_id'] = selectedClassId;
              if (selectedSectionId != null) queryParams['section_id'] = selectedSectionId;
              if (selectedAyId != null) queryParams['ay_id'] = selectedAyId;
              final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
              context.push(uri.toString());
            },
          ),
          const SizedBox(width: 8),
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
          // Diagnostic Context Header (Responsive Wrap)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Tenant: $tenantName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (activeTenantId != null)
                      Text(
                        ' ($activeTenantId)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 16, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'School: $schoolName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (schoolId != null)
                      Text(
                        ' ($schoolId)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Bar (Production-Grade Responsive LayoutBuilder)
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Builder(
                builder: (context) {
                  // Dropdown 1: Academic Year
                  final ayDropdown = DropdownButtonFormField<String>(
                    value: selectedAyId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Academic Year', isDense: true, border: OutlineInputBorder()),
                    items: (ayState?.years ?? []).map((ay) {
                      return DropdownMenuItem(value: ay.id, child: Text(ay.name, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      ref.read(adminMarksFiltersProvider.notifier).setAcademicYear(val);
                      ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                    },
                  );

                  // Dropdown 2: Examination
                  final examDropdown = DropdownButtonFormField<String>(
                    value: selectedExamId,
                    isExpanded: true,
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
                      final title = ex.getDisambiguatedTitle(classIdToName: classIdToName);
                      return DropdownMenuItem(value: ex.id, child: Text(title, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: availableExams.isEmpty
                        ? null
                        : (val) {
                            ref.read(adminMarksFiltersProvider.notifier).setExamination(val);
                            ref.read(adminMarksBoardProvider.notifier).clearActiveSchedule();
                          },
                  );

                  // Dropdown 3: Class
                  final classDropdown = DropdownButtonFormField<String>(
                    value: selectedClassId,
                    isExpanded: true,
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
                  );

                  // Dropdown 4: Section
                  final sectionDropdown = DropdownButtonFormField<String>(
                    value: selectedSectionId,
                    isExpanded: true,
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
                  );

                  // Dropdown 5: Subject / Schedule Slot
                  final scheduleDropdown = DropdownButtonFormField<String>(
                    value: selectedScheduleId,
                    isExpanded: true,
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
                      final label = '${displaySubjectName(subjectName: s.subjectName, subjectCode: s.subjectCode, subjectId: s.subjectId)} (${s.maxMarks} Marks)';
                      return DropdownMenuItem(value: s.id, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: availableSchedules.isEmpty
                        ? null
                        : (val) {
                            ref.read(adminMarksFiltersProvider.notifier).setSchedule(val);
                          },
                  );

                  // Action Buttons
                  final loadButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Load Marks'),
                    onPressed: isLoadEnabled
                        ? () {
                            final target = availableSchedules.firstWhere((s) => s.id == selectedScheduleId);
                            ref.read(adminMarksBoardProvider.notifier).loadMarksForSchedule(target);
                          }
                        : null,
                  );

                  final uploadButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Upload Excel / CSV'),
                    onPressed: (selectedExamId == null && boardState.activeSchedule == null)
                        ? null
                        : _showUploadMarksDialog,
                  );

                  final publishButton = selectedExamId != null
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          icon: const Icon(Icons.verified),
                          label: const Text('Publish Examination'),
                          onPressed: _showPublishExaminationDialog,
                        )
                      : null;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      // 1. Wide Desktop Layout (>= 1400 px)
                      if (width >= 1400) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 3, child: ayDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 4, child: examDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: classDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: sectionDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 4, child: scheduleDropdown),
                                const SizedBox(width: 12),
                                loadButton,
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                uploadButton,
                                if (publishButton != null) ...[
                                  const SizedBox(width: 10),
                                  publishButton,
                                ],
                              ],
                            ),
                          ],
                        );
                      }

                      // 2. Medium Desktop / Tablet Layout (1000 - 1399 px)
                      if (width >= 1000) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 3, child: ayDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 4, child: examDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: classDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: sectionDropdown),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: scheduleDropdown),
                                const SizedBox(width: 10),
                                loadButton,
                                const SizedBox(width: 10),
                                uploadButton,
                                if (publishButton != null) ...[
                                  const SizedBox(width: 10),
                                  publishButton,
                                ],
                              ],
                            ),
                          ],
                        );
                      }

                      // 3. Small Screens / Tablet Portrait (650 - 999 px)
                      if (width >= 650) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: ayDropdown),
                                const SizedBox(width: 10),
                                Expanded(child: examDropdown),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: classDropdown),
                                const SizedBox(width: 10),
                                Expanded(child: sectionDropdown),
                              ],
                            ),
                            const SizedBox(height: 10),
                            scheduleDropdown,
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                loadButton,
                                uploadButton,
                                if (publishButton != null) publishButton,
                              ],
                            ),
                          ],
                        );
                      }

                      // 4. Mobile Screens (< 650 px)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ayDropdown,
                          const SizedBox(height: 10),
                          examDropdown,
                          const SizedBox(height: 10),
                          classDropdown,
                          const SizedBox(height: 10),
                          sectionDropdown,
                          const SizedBox(height: 10),
                          scheduleDropdown,
                          const SizedBox(height: 12),
                          loadButton,
                          const SizedBox(height: 8),
                          uploadButton,
                          if (publishButton != null) ...[
                            const SizedBox(height: 8),
                            publishButton,
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),


          // Error Banner for Schedules Failure
          if (filters.examinationId != null && schedulesAsync.hasError)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Failed to load examination schedules: ${schedulesAsync.error}',
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (filters.examinationId != null) {
                        ref.invalidate(marksExamSchedulesProvider(filters.examinationId!));
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Contextual Empty State Banner for Missing Schedules
          if (filters.examinationId != null &&
              filters.classId != null &&
              filters.sectionId != null &&
              !schedulesAsync.isLoading &&
              !schedulesAsync.hasError &&
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
                        key: const Key('toolbar_import_marks_board_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: const Text('Import Marks (Wizard)'),
                        onPressed: () {
                          final queryParams = <String, String>{};
                          if (selectedExamId != null) queryParams['exam_id'] = selectedExamId;
                          if (selectedClassId != null) queryParams['class_id'] = selectedClassId;
                          if (selectedSectionId != null) queryParams['section_id'] = selectedSectionId;
                          if (selectedAyId != null) queryParams['ay_id'] = selectedAyId;
                          final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
                          context.push(uri.toString());
                        },
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
                            schedulesAsync: schedulesAsync,
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
    required AsyncValue<List<AdminExamScheduleOption>> schedulesAsync,
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('empty_state_import_marks_btn'),
            onPressed: () {
              final queryParams = <String, String>{};
              if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
              if (filters.classId != null) queryParams['class_id'] = filters.classId!;
              if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
              if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
              final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
              context.push(uri.toString());
            },
            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
            label: const Text('Import Marks via 9-Step Wizard'),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (availableExams.isEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => context.push(AppRoutes.examinations),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Examination in Setup'),
                ),
              OutlinedButton.icon(
                key: const Key('empty_state_import_marks_btn'),
                onPressed: () {
                  final queryParams = <String, String>{};
                  if (filters.examinationId != null) queryParams['exam_id'] = filters.examinationId!;
                  if (filters.classId != null) queryParams['class_id'] = filters.classId!;
                  if (filters.sectionId != null) queryParams['section_id'] = filters.sectionId!;
                  if (filters.academicYearId != null) queryParams['ay_id'] = filters.academicYearId!;
                  final uri = Uri(path: AppRoutes.marksImport, queryParameters: queryParams);
                  context.push(uri.toString());
                },
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text('Import Marks via 9-Step Wizard'),
              ),
            ],
          ),
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

    if (schedulesAsync.isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Loading examination schedules...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }

    if (schedulesAsync.hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          const Text(
            'Failed to load examination schedules',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${schedulesAsync.error}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              if (filters.examinationId != null) {
                ref.invalidate(marksExamSchedulesProvider(filters.examinationId!));
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
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
      width: 185,
      child: Card(
        elevation: 0,
        color: color.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      value,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
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
