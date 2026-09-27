import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/routing/routes.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../data/models/admin_marks_models.dart';
import '../../data/models/examination_models.dart';
import '../providers/admin_marks_providers.dart';
import '../providers/examination_providers.dart';
import '../providers/results_download_helper.dart';

class MarksImportWizardScreen extends ConsumerStatefulWidget {
  final String? initialExamId;
  final String? initialClassId;
  final String? initialSectionId;
  final String? initialAcademicYearId;

  const MarksImportWizardScreen({
    super.key,
    this.initialExamId,
    this.initialClassId,
    this.initialSectionId,
    this.initialAcademicYearId,
  });

  @override
  ConsumerState<MarksImportWizardScreen> createState() => _MarksImportWizardScreenState();
}

class _MarksImportWizardScreenState extends ConsumerState<MarksImportWizardScreen> {
  int _currentStep = 0; // 0 to 8 representing Steps 1 to 9

  // Selections
  String? _selectedAyId;
  String? _selectedExamId;
  ExaminationModel? _detailedExam;

  // Step 3: Multi-Class & Section Selection
  bool _allClassesSelected = true;
  Set<String> _selectedClassIds = {};
  bool _allSectionsSelected = true;
  Set<String> _selectedSectionIds = {};

  // Duplicate Handling Behavior (Step 7)
  String _duplicateBehavior = 'UPDATE_EXISTING'; // 'UPDATE_EXISTING', 'SKIP_EXISTING', 'FAIL_DUPLICATE'

  // File
  PlatformFile? _pickedFile;
  List<int>? _fileBytes;
  String? _fileName;

  // Column Mapping
  String _colIdentifier = 'Admission_Number';
  String _colStudentName = 'Student_Name';
  String _colClass = 'Class';
  String _colSection = 'Section';
  String _colSubject = 'Subject';
  String _colMaxMarks = 'Max_Marks';
  String _colMarksObtained = 'Marks_Obtained';
  String _colStatus = 'Status';
  String _colGrade = 'Grade';

  // Preview & Result
  ExamWideUploadPreviewModel? _previewData;
  ExamWideUploadResultModel? _importResult;
  bool _isProcessing = false;
  String? _errorMessage;
  double _importProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedAyId = widget.initialAcademicYearId;
    _selectedExamId = widget.initialExamId;

    // Default to All Participating Classes for multi-class import
    _allClassesSelected = true;
    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      _selectedClassIds = {widget.initialClassId!};
    }
    if (widget.initialSectionId != null && widget.initialSectionId!.isNotEmpty) {
      _allSectionsSelected = false;
      _selectedSectionIds = {widget.initialSectionId!};
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDependencies();
    });
  }

  void _initDependencies() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId != null) {
      ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
      ref.read(classesProvider(schoolId).notifier).fetchClasses();
      ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      ref.read(examinationsProvider.notifier).loadExaminations();
    }

    if (_selectedExamId != null) {
      _fetchExamDetail(_selectedExamId!);
    }
  }

  Future<void> _fetchExamDetail(String examId) async {
    final detailed = await ref.read(examinationsProvider.notifier).getExaminationDetail(examId);
    if (mounted && detailed != null) {
      setState(() {
        _detailedExam = detailed;
        if (_allClassesSelected && detailed.effectiveClassIds.isNotEmpty) {
          _selectedClassIds = Set<String>.from(detailed.effectiveClassIds);
        }
      });
    }
  }

  void _onExamChanged(String? examId) {
    if (examId == _selectedExamId) return;

    setState(() {
      _selectedExamId = examId;
      _allClassesSelected = true;
      _selectedClassIds.clear();
      _allSectionsSelected = true;
      _selectedSectionIds.clear();
      _detailedExam = null;
      _previewData = null;
      _importResult = null;
      _errorMessage = null;
    });

    if (examId != null) {
      _fetchExamDetail(examId);
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        setState(() {
          _pickedFile = f;
          _fileBytes = f.bytes;
          _fileName = f.name;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _runPreviewValidation() async {
    if (_selectedExamId == null || _fileBytes == null || _fileName == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final List<String>? classIdsParam = _allClassesSelected ? null : _selectedClassIds.toList();
      final List<String>? sectionIdsParam = _allSectionsSelected ? null : _selectedSectionIds.toList();

      final preview = await ref.read(adminMarksBoardProvider.notifier).previewExamWideUpload(
        examId: _selectedExamId!,
        fileBytes: _fileBytes!,
        fileName: _fileName!,
        classIds: classIdsParam,
        sectionIds: sectionIdsParam,
        academicYearId: _selectedAyId,
        scope: _allClassesSelected ? 'ALL_PARTICIPATING_CLASSES' : 'SELECTED_CLASSES',
        duplicateBehavior: _duplicateBehavior,
      );

      setState(() {
        _previewData = preview;
        _isProcessing = false;
        _currentStep = 5; // Step 6: Preview Data
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to parse file: $e';
      });
    }
  }

  Future<void> _executeImport() async {
    if (_selectedExamId == null || _previewData == null) return;

    setState(() {
      _isProcessing = true;
      _importProgress = 0.2;
      _errorMessage = null;
    });

    try {
      final rowsToImport = _previewData!.previewRows.where((r) => r.isValid).toList();
      setState(() => _importProgress = 0.6);

      final List<String>? classIdsParam = _allClassesSelected ? null : _selectedClassIds.toList();
      final List<String>? sectionIdsParam = _allSectionsSelected ? null : _selectedSectionIds.toList();

      final result = await ref.read(adminMarksBoardProvider.notifier).confirmExamWideUpload(
        examId: _selectedExamId!,
        rows: rowsToImport,
        autoApprove: true,
        duplicateBehavior: _duplicateBehavior,
        classIds: classIdsParam,
        sectionIds: sectionIdsParam,
        academicYearId: _selectedAyId,
        scope: _allClassesSelected ? 'ALL_PARTICIPATING_CLASSES' : 'SELECTED_CLASSES',
      );

      setState(() {
        _importProgress = 1.0;
        _isProcessing = false;
        _importResult = result;
        _currentStep = 8; // Step 9: Summary
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Import execution error: $e';
      });
    }
  }

  Future<void> _downloadMultiClassTemplate() async {
    if (_selectedExamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an examination cycle first.')),
      );
      return;
    }

    try {
      final examState = ref.read(examinationsProvider);
      final exam = _detailedExam ?? examState.examinations.where((e) => e.id == _selectedExamId).firstOrNull;
      final examName = exam?.examName ?? 'Examination';

      final List<String>? classIdsParam = _allClassesSelected ? null : _selectedClassIds.toList();
      final List<String>? sectionIdsParam = _allSectionsSelected ? null : _selectedSectionIds.toList();

      await ref.read(adminMarksBoardProvider.notifier).downloadExamWideTemplate(
        examId: _selectedExamId!,
        examName: examName,
        classIds: classIdsParam,
        sectionIds: sectionIdsParam,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template for "$examName" downloaded successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download template: $e')),
        );
      }
    }
  }

  void _downloadImportLogCsv() {
    if (_previewData == null) return;

    final buffer = StringBuffer();
    buffer.writeln('Row,Class,Section,Roll/Adm No,Student Name,Subject,Max Marks,Marks Obtained,Status,Type,Validation Error');
    for (final row in _previewData!.previewRows) {
      final student = (row.studentName ?? '').replaceAll('"', '""');
      final err = (row.errorMessage ?? '').replaceAll('"', '""');
      final type = row.isExisting ? 'Existing' : 'New';
      buffer.writeln(
        '${row.rowNumber},"${row.className}","${row.sectionName}","${row.rollNumber}","$student","${row.subjectName}",${row.maxMarks},${row.marksObtained ?? ''},"${row.status}","$type","$err"',
      );
    }

    final bytes = buffer.toString().codeUnits;
    final examName = _importResult?.examinationName ?? 'Marks_Import';
    final filename = '${examName.replaceAll(' ', '_')}_import_log_${DateTime.now().millisecondsSinceEpoch}.csv';
    downloadBytes(filename, bytes, 'text/csv');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams / Assessments → Import Marks Wizard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Import Guide'),
            onPressed: _showHelpGuide,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: schoolId == null
          ? const Center(child: Text('Please select a school to proceed.'))
          : Column(
              children: [
                _buildStepHeader(context),
                const Divider(height: 1),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildCurrentStepContent(context),
                  ),
                ),
                const Divider(height: 1),
                _buildNavigationFooter(context),
              ],
            ),
    );
  }

  Widget _buildStepHeader(BuildContext context) {
    final steps = [
      '1. Academic Year',
      '2. Examination Cycle',
      '3. Class & Section',
      '4. Upload File',
      '5. Map Columns',
      '6. Preview Data',
      '7. Validation',
      '8. Execute Import',
      '9. Summary',
    ];

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length, (idx) {
            final isCurrent = idx == _currentStep;
            final isCompleted = idx < _currentStep;
            return Row(
              children: [
                InkWell(
                  onTap: () {
                    if (idx < _currentStep) {
                      setState(() => _currentStep = idx);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF0D9488)
                          : isCompleted
                              ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        if (isCompleted)
                          const Icon(Icons.check, size: 14, color: Color(0xFF0D9488))
                        else
                          Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          steps[idx].substring(3),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent
                                ? Colors.white
                                : isCompleted
                                    ? const Color(0xFF0D9488)
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (idx < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildStep1AcademicYear(context);
      case 1:
        return _buildStep2Examination(context);
      case 2:
        return _buildStep3ClassSection(context);
      case 3:
        return _buildStep4UploadFile(context);
      case 4:
        return _buildStep5MapColumns(context);
      case 5:
        return _buildStep6PreviewParsedData(context);
      case 6:
        return _buildStep7ValidationCheck(context);
      case 7:
        return _buildStep8ExecuteImport(context);
      case 8:
        return _buildStep9ImportSummary(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1AcademicYear(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final years = schoolId != null ? (ref.watch(academicYearsProvider(schoolId)).years.whereType<AcademicYearDto>().toList()) : <AcademicYearDto>[];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Step 1 — Select Academic Year', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('All imported marks will be associated with the selected academic year.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedAyId,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  items: years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAyId = val),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2Examination(BuildContext context) {
    final examState = ref.watch(examinationsProvider);
    final exams = examState.examinations;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Step 2 — Select Examination Cycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Select the target examination cycle for this marks entry.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedExamId,
                  decoration: const InputDecoration(
                    labelText: 'Examination Cycle *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                  ),
                  items: exams.map((e) => DropdownMenuItem(value: e.id, child: Text(e.examName))).toList(),
                  onChanged: _onExamChanged,
                ),
                if (_selectedExamId != null) ...[
                  const SizedBox(height: 16),
                  Builder(builder: (ctx) {
                    final selected = exams.where((e) => e.id == _selectedExamId).firstOrNull;
                    final classesCount = selected?.effectiveClassIds.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Color(0xFF0D9488)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              classesCount > 0
                                  ? '$classesCount participating classes configured for this examination cycle.'
                                  : 'School-wide examination cycle.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F766E), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep3ClassSection(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final allClasses = schoolId != null
        ? (ref.watch(classesProvider(schoolId)).classes.whereType<ClassDto>().toList())
        : <ClassDto>[];
    final allSections = schoolId != null
        ? (ref.watch(sectionsProvider(schoolId)).sections.whereType<SectionDto>().toList())
        : <SectionDto>[];

    final examState = ref.watch(examinationsProvider);
    final examFromList = examState.examinations.where((e) => e.id == _selectedExamId).firstOrNull;
    final activeExam = _detailedExam ?? examFromList;

    // Strict Filtering: Only classes participating in the selected examination cycle!
    final participatingClassIds = activeExam?.effectiveClassIds ?? <String>{};
    final availableClasses = participatingClassIds.isNotEmpty
        ? allClasses.where((c) => participatingClassIds.contains(c.id)).toList()
        : allClasses;

    // Determine effective selected class IDs
    final effectiveClassIds = _allClassesSelected
        ? availableClasses.map((c) => c.id).toSet()
        : _selectedClassIds;

    // Sections for selected classes
    final availableSections = allSections.where((s) => effectiveClassIds.contains(s.classId)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Step 3 — Select Participating Classes & Sections',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            'Import marks for all participating classes in one unified workflow or filter specific classes.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${availableClasses.length} Participating Classes',
                        style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Primary Choice: [✓] All Participating Classes
                Container(
                  decoration: BoxDecoration(
                    color: _allClassesSelected
                        ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _allClassesSelected ? const Color(0xFF0D9488) : Colors.grey.shade300,
                      width: _allClassesSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _allClassesSelected,
                    activeColor: const Color(0xFF0D9488),
                    title: const Text(
                      'All Participating Classes (Recommended)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Import all classes in ${activeExam?.examName ?? 'this cycle'} (${availableClasses.map((c) => c.name).join(', ')}) in a single upload.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        _allClassesSelected = val ?? true;
                        if (_allClassesSelected) {
                          _selectedClassIds = availableClasses.map((c) => c.id).toSet();
                        } else {
                          _selectedClassIds.clear();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Individual Class Checkboxes Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Participating Classes (${_allClassesSelected ? availableClasses.length : _selectedClassIds.length} of ${availableClasses.length} Selected):',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.select_all_rounded, size: 16),
                          label: const Text('Select All', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _allClassesSelected = true;
                              _selectedClassIds = availableClasses.map((c) => c.id).toSet();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _allClassesSelected = false;
                              _selectedClassIds.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Grid / List of Individual Classes
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: availableClasses.map((cls) {
                    final isChecked = _allClassesSelected || _selectedClassIds.contains(cls.id);
                    final classSecCount = allSections.where((s) => s.classId == cls.id).length;

                    return FilterChip(
                      selected: isChecked,
                      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.18),
                      checkmarkColor: const Color(0xFF0D9488),
                      label: Text(
                        '${cls.name} ($classSecCount ${classSecCount == 1 ? 'sec' : 'secs'})',
                        style: TextStyle(
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                          color: isChecked ? const Color(0xFF0F766E) : Colors.black87,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (_allClassesSelected) {
                            // Break out of all selected
                            _selectedClassIds = availableClasses.map((c) => c.id).toSet();
                            if (!selected) {
                              _selectedClassIds.remove(cls.id);
                            }
                            _allClassesSelected = false;
                          } else {
                            if (selected) {
                              _selectedClassIds.add(cls.id);
                              if (_selectedClassIds.length == availableClasses.length) {
                                _allClassesSelected = true;
                              }
                            } else {
                              _selectedClassIds.remove(cls.id);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Section Filtering
                const Text('Section Filtering (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                const Text(
                  'By default, marks can be uploaded for all sections. You can optionally restrict to specific sections.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),

                RadioListTile<bool>(
                  value: true,
                  groupValue: _allSectionsSelected,
                  activeColor: const Color(0xFF0D9488),
                  title: const Text('All Sections (Recommended)', style: TextStyle(fontSize: 14)),
                  onChanged: (val) {
                    setState(() {
                      _allSectionsSelected = val ?? true;
                      _selectedSectionIds.clear();
                    });
                  },
                ),
                RadioListTile<bool>(
                  value: false,
                  groupValue: _allSectionsSelected,
                  activeColor: const Color(0xFF0D9488),
                  title: const Text('Filter Specific Sections', style: TextStyle(fontSize: 14)),
                  onChanged: (val) {
                    setState(() {
                      _allSectionsSelected = false;
                      _selectedSectionIds = availableSections.map((s) => s.id).toSet();
                    });
                  },
                ),

                if (!_allSectionsSelected) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSections.map((sec) {
                        final isSecChecked = _selectedSectionIds.contains(sec.id);
                        final clsName = allClasses.where((c) => c.id == sec.classId).firstOrNull?.name ?? '';
                        return FilterChip(
                          selected: isSecChecked,
                          selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF0D9488),
                          label: Text('$clsName - ${sec.name}', style: const TextStyle(fontSize: 12)),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSectionIds.add(sec.id);
                              } else {
                                _selectedSectionIds.remove(sec.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep4UploadFile(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Step 4 — Upload Spreadsheet / CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Supports multi-class spreadsheets (Excel .xlsx, .xls or CSV). Rows from multiple classes (e.g. Class 5, 6, 7, 8, 9, 10) are validated against master papers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 28),
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF0D9488).withValues(alpha: 0.05),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _pickedFile != null ? Icons.file_present_rounded : Icons.cloud_upload_outlined,
                          size: 48,
                          color: const Color(0xFF0D9488),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _fileName ?? 'Click to Browse File (CSV or Excel)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB • File selected and ready to parse',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Download Multi-Class Template (.xlsx)'),
                      onPressed: _downloadMultiClassTemplate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep5MapColumns(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Step 5 — Map Column Headers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Map columns in your multi-class spreadsheet to EduPulse marks fields. The system automatically recognizes common aliases such as Adm No, Roll No, Class, Subject, and Score.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _buildColumnMapperRow('Student Identifier *', _colIdentifier, 'Adm No, Roll No, Student ID', (v) => setState(() => _colIdentifier = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Student Name', _colStudentName, 'Student Name, Name, Full Name', (v) => setState(() => _colStudentName = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Class *', _colClass, 'Class, Grade, Standard', (v) => setState(() => _colClass = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Section', _colSection, 'Section, Sec', (v) => setState(() => _colSection = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Subject *', _colSubject, 'Subject, Paper, Course', (v) => setState(() => _colSubject = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Max Marks *', _colMaxMarks, 'Max Marks, Total Marks', (v) => setState(() => _colMaxMarks = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Marks Obtained *', _colMarksObtained, 'Marks, Score, Marks Obtained', (v) => setState(() => _colMarksObtained = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Status (Optional)', _colStatus, 'Status, Attendance (PRESENT/ABSENT)', (v) => setState(() => _colStatus = v)),
                const SizedBox(height: 14),
                _buildColumnMapperRow('Grade (Optional)', _colGrade, 'Grade', (v) => setState(() => _colGrade = v)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnMapperRow(String label, String value, String hint, ValueChanged<String> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(hint, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            initialValue: value,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildStep6PreviewParsedData(BuildContext context) {
    if (_previewData == null) {
      return const Center(child: Text('No preview data available. Please re-upload.'));
    }

    final p = _previewData!;
    final rows = p.previewRows;

    // Group rows by class name for organized multi-class preview
    final Map<String, List<ExamWideUploadRowModel>> rowsByClass = {};
    for (final r in rows) {
      rowsByClass.putIfAbsent(r.className.isNotEmpty ? r.className : 'Unassigned Class', () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 6 — Parsed Rows Preview (${p.totalRows} Total Rows across ${rowsByClass.keys.length} Classes)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Classes: ${p.classesDetected.join(', ')} • Sections: ${p.sectionsDetected.join(', ')} • Subjects: ${p.subjectsDetected.join(', ')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                _buildMiniBadge('${p.validRowsCount} Valid', Colors.green),
                const SizedBox(width: 8),
                if (p.invalidRowsCount > 0) ...[
                  _buildMiniBadge('${p.invalidRowsCount} Issues', Colors.red),
                  const SizedBox(width: 8),
                ],
                if (p.existingMarksCount > 0)
                  _buildMiniBadge('${p.existingMarksCount} Existing', const Color(0xFF0D9488)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Display Class-by-Class Grouped Accordions
        ...rowsByClass.entries.map((entry) {
          final className = entry.key;
          final classRows = entry.value;
          final validCount = classRows.where((r) => r.isValid).length;
          final invalidCount = classRows.where((r) => !r.isValid).length;
          final existingCount = classRows.where((r) => r.isExisting).length;
          final classSections = classRows.map((r) => r.sectionName).where((s) => s.isNotEmpty).toSet();
          final classSubjects = classRows.map((r) => r.subjectName).where((s) => s.isNotEmpty).toSet();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sections: ${classSections.isNotEmpty ? classSections.join(", ") : "All"} • Subjects: ${classSubjects.length} (${classSubjects.join(", ")})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 20, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    className,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${classRows.length} Rows',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$validCount Valid',
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (invalidCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$invalidCount Issues',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (existingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$existingCount Existing Marks',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Row')),
                      DataColumn(label: Text('Section')),
                      DataColumn(label: Text('Roll / Adm No')),
                      DataColumn(label: Text('Student Name')),
                      DataColumn(label: Text('Subject')),
                      DataColumn(label: Text('Max Marks')),
                      DataColumn(label: Text('Obtained')),
                      DataColumn(label: Text('Entry Type')),
                      DataColumn(label: Text('Status & Validity')),
                    ],
                    rows: classRows.take(50).map((r) {
                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (!r.isValid) return Colors.red.withValues(alpha: 0.08);
                          if (r.isExisting) return const Color(0xFF0D9488).withValues(alpha: 0.04);
                          return null;
                        }),
                        cells: [
                          DataCell(Text('#${r.rowNumber}')),
                          DataCell(Text(r.sectionName)),
                          DataCell(Text(r.rollNumber)),
                          DataCell(Text(r.studentName ?? 'Matched Student')),
                          DataCell(Text(r.subjectName)),
                          DataCell(Text('${r.maxMarks}')),
                          DataCell(Text(r.marksObtained != null ? '${r.marksObtained}' : '-')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.isExisting
                                    ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.isExisting ? 'Existing Mark' : 'New Entry',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: r.isExisting ? const Color(0xFF0F766E) : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  r.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: r.isValid ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.isValid ? 'Valid' : (r.errorMessage ?? 'Error'),
                                  style: TextStyle(color: r.isValid ? Colors.green : Colors.red, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildStep7ValidationCheck(BuildContext context) {
    if (_previewData == null) {
      return const Center(child: Text('No validation data found.'));
    }

    final p = _previewData!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Column(
          children: [
            const Text('Step 7 — Validation & Duplicate Handling Audit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'EduPulse verifies student enrollment across participating classes, checks mark boundaries, and handles existing database records based on your selected strategy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Valid Rows',
                    value: '${p.validRowsCount}',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Invalid Issues',
                    value: '${p.invalidRowsCount}',
                    icon: Icons.error_outline,
                    color: p.invalidRowsCount > 0 ? Colors.red : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Existing Marks',
                    value: '${p.existingMarksCount}',
                    icon: Icons.history_rounded,
                    color: p.existingMarksCount > 0 ? const Color(0xFF0D9488) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Students Matched',
                    value: '${p.studentsCount}',
                    icon: Icons.people_outline,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Duplicate Handling Strategy Selection
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0D9488)),
                        SizedBox(width: 8),
                        Text('Duplicate Handling Strategy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose how EduPulse should handle marks for students that already have records saved in the system.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    RadioListTile<String>(
                      value: 'UPDATE_EXISTING',
                      groupValue: _duplicateBehavior,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Update Existing Marks (Default & Recommended)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                        'Overwrites existing marks with values from the spreadsheet and records an administrative audit entry.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) => setState(() => _duplicateBehavior = val ?? 'UPDATE_EXISTING'),
                    ),
                    RadioListTile<String>(
                      value: 'SKIP_EXISTING',
                      groupValue: _duplicateBehavior,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Skip Existing Marks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                        'Leaves existing marks records untouched in the database; only newly discovered student marks are inserted.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) => setState(() => _duplicateBehavior = val ?? 'SKIP_EXISTING'),
                    ),
                    RadioListTile<String>(
                      value: 'FAIL_DUPLICATE',
                      groupValue: _duplicateBehavior,
                      activeColor: const Color(0xFF0D9488),
                      title: const Text('Fail on Duplicate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                        'Rejects the entire upload if any duplicate marks records already exist in the database.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) => setState(() => _duplicateBehavior = val ?? 'FAIL_DUPLICATE'),
                    ),
                  ],
                ),
              ),
            ),

            if (p.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detected Validation Messages:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 8),
                    ...p.errors.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $e', style: const TextStyle(fontSize: 13, color: Colors.red)),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep8ExecuteImport(BuildContext context) {
    final validRowsCount = _previewData?.validRowsCount ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Step 8 — Execute Marks Import', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Ready to commit $validRowsCount verified marks records across all selected classes into the database.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, size: 20, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Strategy: ${_getDuplicateStrategyLabel()} • Transaction Safe',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_isProcessing) ...[
                  LinearProgressIndicator(value: _importProgress > 0 ? _importProgress : null),
                  const SizedBox(height: 16),
                  const Text('Processing marks upserts across participating classes...'),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text('Execute Multi-Class Import ($validRowsCount Records)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    onPressed: validRowsCount > 0 ? _executeImport : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDuplicateStrategyLabel() {
    switch (_duplicateBehavior) {
      case 'SKIP_EXISTING':
        return 'Skip Existing Records';
      case 'FAIL_DUPLICATE':
        return 'Fail on Duplicate';
      case 'UPDATE_EXISTING':
      default:
        return 'Update Existing Records';
    }
  }

  Widget _buildStep9ImportSummary(BuildContext context) {
    final res = _importResult;
    final totalSelectedClasses = _allClassesSelected
        ? (_detailedExam?.effectiveClassIds.length ?? _selectedClassIds.length)
        : _selectedClassIds.length;
    final processedClasses = res?.classesCount ?? 0;
    final failedRecords = res?.failedCount ?? 0;
    final missingClasses = (res?.classesBreakdown ?? [])
        .where((cb) => (cb.status == 'NOT_FOUND' || cb.status == 'FAILED' || cb.totalRecords == 0))
        .toList();
    final bool hasIssues = (totalSelectedClasses > 0 && processedClasses < totalSelectedClasses) ||
        failedRecords > 0 ||
        missingClasses.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Icon(
              hasIssues ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: hasIssues ? Colors.amber.shade800 : const Color(0xFF0D9488),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              hasIssues ? 'Import Completed with Issues' : 'Multi-Class Marks Import Completed',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasIssues && totalSelectedClasses > 0 && processedClasses < totalSelectedClasses
                  ? '$processedClasses of $totalSelectedClasses selected classes processed. Some classes were not found or encountered issues.'
                  : 'Examination: ${res?.examinationName ?? 'Selected Examination'} • $processedClasses Classes Processed',
              style: TextStyle(
                fontSize: 14,
                color: hasIssues ? Colors.amber.shade900 : Colors.grey,
                fontWeight: hasIssues ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasIssues && missingClasses.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Classes Requiring Attention (${missingClasses.length}):',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...missingClasses.map((mc) => Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '${mc.className}: ',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                              ),
                              Expanded(
                                child: Text(
                                  mc.reason ?? (mc.totalRecords == 0 ? 'No student marks records found in upload file' : 'Encountered issues during processing'),
                                  style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Total Processed',
                    value: '${res?.totalRecords ?? 0}',
                    icon: Icons.list_alt_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'New Inserted',
                    value: '${res?.createdCount ?? 0}',
                    icon: Icons.add_chart_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Updated',
                    value: '${res?.updatedCount ?? 0}',
                    icon: Icons.update_rounded,
                    color: const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Skipped',
                    value: '${res?.skippedCount ?? 0}',
                    icon: Icons.skip_next_rounded,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildValidationKpiCard(
                    title: 'Failed',
                    value: '${res?.failedCount ?? 0}',
                    icon: Icons.cancel_outlined,
                    color: (res?.failedCount ?? 0) > 0 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),

            // Class-by-Class Breakdown Table
            if (res != null && res.classesBreakdown.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Class-by-Class Processing Breakdown',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${res.classesBreakdown.length} Classes',
                              style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.05)),
                          columns: const [
                            DataColumn(label: Text('Class Name')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Sections')),
                            DataColumn(label: Text('Students')),
                            DataColumn(label: Text('Total Processed')),
                            DataColumn(label: Text('New Inserted')),
                            DataColumn(label: Text('Updated')),
                            DataColumn(label: Text('Skipped')),
                            DataColumn(label: Text('Failed')),
                          ],
                          rows: res.classesBreakdown.map((cb) {
                            final statusStr = (cb.status ?? (cb.totalRecords == 0 ? 'NOT_FOUND' : 'SUCCESS')).toUpperCase();
                            Color statusBg;
                            Color statusFg;
                            String statusLabel;
                            if (statusStr == 'SUCCESS') {
                              statusBg = Colors.green.shade50;
                              statusFg = Colors.green.shade800;
                              statusLabel = 'SUCCESS';
                            } else if (statusStr == 'PARTIAL') {
                              statusBg = Colors.teal.shade50;
                              statusFg = Colors.teal.shade800;
                              statusLabel = 'PARTIAL';
                            } else if (statusStr == 'NOT_FOUND' || statusStr == 'NO DATA') {
                              statusBg = Colors.amber.shade50;
                              statusFg = Colors.amber.shade900;
                              statusLabel = 'NOT FOUND';
                            } else {
                              statusBg = Colors.red.shade50;
                              statusFg = Colors.red.shade800;
                              statusLabel = statusStr;
                            }

                            final badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusFg.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                              ),
                            );

                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(cb.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (cb.reason != null && cb.reason!.isNotEmpty)
                                        Text(
                                          cb.reason!,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  cb.reason != null && cb.reason!.isNotEmpty
                                      ? Tooltip(message: cb.reason!, child: badge)
                                      : badge,
                                ),
                                DataCell(Text(cb.sections.isNotEmpty ? cb.sections.join(', ') : '${cb.sectionsCount}')),
                                DataCell(Text('${cb.studentsCount}')),
                                DataCell(Text('${cb.totalRecords}')),
                                DataCell(Text(
                                  '${cb.createdCount}',
                                  style: TextStyle(
                                    color: cb.createdCount > 0 ? Colors.green : null,
                                    fontWeight: cb.createdCount > 0 ? FontWeight.bold : null,
                                  ),
                                )),
                                DataCell(Text(
                                  '${cb.updatedCount}',
                                  style: TextStyle(
                                    color: cb.updatedCount > 0 ? const Color(0xFF0D9488) : null,
                                    fontWeight: cb.updatedCount > 0 ? FontWeight.bold : null,
                                  ),
                                )),
                                DataCell(Text(
                                  '${cb.skippedCount}',
                                  style: TextStyle(
                                    color: cb.skippedCount > 0 ? Colors.amber.shade800 : null,
                                  ),
                                )),
                                DataCell(Text(
                                  '${cb.failedCount}',
                                  style: TextStyle(
                                    color: cb.failedCount > 0 ? Colors.red : null,
                                    fontWeight: cb.failedCount > 0 ? FontWeight.bold : null,
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Failure Breakdown Card
            if ((res?.failedCount ?? 0) > 0 && res?.failureBreakdown != null && res!.failureBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Failure Reason Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: res.failureBreakdown.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            '${entry.key}: ${entry.value} failed',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Import Log (CSV)'),
                  onPressed: _downloadImportLogCsv,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Go to Marks Management'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final queryParams = <String, String>{};
                    if (_selectedExamId != null) queryParams['exam_id'] = _selectedExamId!;
                    if (_selectedAyId != null) queryParams['ay_id'] = _selectedAyId!;
                    final uri = Uri(path: AppRoutes.marksManagement, queryParameters: queryParams);
                    context.go(uri.toString());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationFooter(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0 && _currentStep < 8)
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous Step'),
              onPressed: _isProcessing ? null : () => setState(() => _currentStep--),
            )
          else
            const SizedBox.shrink(),

          if (_currentStep < 8)
            ElevatedButton.icon(
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_forward),
              label: Text(_getNextButtonLabel()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing || !_canProceedNext() ? null : _handleNextStep,
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              onPressed: () => context.go(AppRoutes.results),
              child: const Text('Back to Results Dashboard'),
            ),
        ],
      ),
    );
  }

  String _getNextButtonLabel() {
    switch (_currentStep) {
      case 3:
        return 'Parse & Validate File';
      case 4:
        return 'Proceed to Preview';
      case 6:
        return 'Go to Execute Import';
      case 7:
        return 'Execute Import';
      default:
        return 'Continue';
    }
  }

  bool _canProceedNext() {
    switch (_currentStep) {
      case 0:
        return _selectedAyId != null;
      case 1:
        return _selectedExamId != null;
      case 2:
        return _allClassesSelected || _selectedClassIds.isNotEmpty;
      case 3:
        return _fileBytes != null;
      case 4:
        return true;
      case 5:
        return _previewData != null;
      case 6:
        return (_previewData?.validRowsCount ?? 0) > 0;
      default:
        return true;
    }
  }

  void _handleNextStep() {
    if (_currentStep == 3) {
      setState(() => _currentStep = 4);
    } else if (_currentStep == 4) {
      _runPreviewValidation();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _showHelpGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Multi-Class Marks Import Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. School-Wide Examination Import:\n'
                'You can import marks for all classes participating in this cycle (e.g. Class 5, 6, 7, 8, 9, 10) in a single upload.\n\n'
                '2. Student Identifiers:\n'
                'The system matches students by Admission Number, Roll Number, or Student ID.\n\n'
                '3. Paper & Class Overrides:\n'
                'Max marks are automatically resolved per class (e.g. Class 5 max 50 vs Class 10 max 100).\n\n'
                '4. Duplicate Handling Strategies:\n'
                '• Update Existing: Replaces marks and logs audit trail.\n'
                '• Skip Existing: Preserves existing database marks.\n'
                '• Fail on Duplicate: Aborts if any existing marks are detected.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
