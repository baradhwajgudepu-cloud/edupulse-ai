import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';

class SyllabusEditorScreen extends ConsumerStatefulWidget {
  final String? initialClassId;
  final String? initialSubjectId;

  const SyllabusEditorScreen({
    super.key,
    this.initialClassId,
    this.initialSubjectId,
  });

  @override
  ConsumerState<SyllabusEditorScreen> createState() => _SyllabusEditorScreenState();
}

class _SyllabusEditorScreenState extends ConsumerState<SyllabusEditorScreen> {
  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    _selectedSubjectId = widget.initialSubjectId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      }
    });
  }

  void _invalidateSyllabusProviders({
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    ref.invalidate(syllabusListProvider((
      schoolId: schoolId,
      academicYearId: ayId,
      classId: classId,
      subjectId: subjectId,
      sectionId: null,
    )));
    if (_selectedSectionId != null) {
      ref.invalidate(syllabusListProvider((
        schoolId: schoolId,
        academicYearId: ayId,
        classId: classId,
        subjectId: subjectId,
        sectionId: _selectedSectionId,
      )));
    }
    ref.invalidate(coverageSummaryProvider((
      schoolId: schoolId,
      academicYearId: ayId,
      classId: classId,
      subjectId: subjectId,
      sectionId: null,
    )));
    if (_selectedSectionId != null) {
      ref.invalidate(coverageSummaryProvider((
        schoolId: schoolId,
        academicYearId: ayId,
        classId: classId,
        subjectId: subjectId,
        sectionId: _selectedSectionId,
      )));
    }
  }

  void _showPopulateBoardDialog(
    BuildContext context,
    String schoolId,
    String ayId, {
    String? classId,
    String? subjectId,
  }) {
    String selectedBoard = 'CBSE';
    String stateName = '';
    final classesState = ref.read(classesProvider(schoolId));
    final selectedClassIds = <String>{};
    final activeClass = classId ?? _selectedClassId;
    if (activeClass != null) selectedClassIds.add(activeClass);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.auto_stories, color: Color(0xFF0F766E)),
                  SizedBox(width: 8),
                  Text('Populate from Verified Board Curriculum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the education board to populate canonical curricula directly into your school catalog. The global master remains unmutated.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      const Text('Education Board *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedBoard,
                        items: const [
                          DropdownMenuItem(value: 'CBSE', child: Text('CBSE (Central Board of Secondary Education)')),
                          DropdownMenuItem(value: 'ICSE', child: Text('ICSE (Indian Certificate of Secondary Education)')),
                          DropdownMenuItem(value: 'STATE', child: Text('State Board (Custom State)')),
                          DropdownMenuItem(value: 'UNKNOWN_BOARD', child: Text('Other / International Board (Fallback)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedBoard = val);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      if (selectedBoard == 'STATE') ...[
                        const SizedBox(height: 12),
                        const Text('State Name (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'e.g. Karnataka, Maharashtra',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) => stateName = val,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Apply To Classes *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: classesState.classes.map((c) {
                          final isSelected = selectedClassIds.contains(c.id);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(c.name),
                            selectedColor: const Color(0xFF0F766E).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF0F766E),
                            onSelected: (val) {
                              setDialogState(() {
                                if (val) {
                                  selectedClassIds.add(c.id);
                                } else {
                                  selectedClassIds.remove(c.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Color(0xFF0F766E)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verified curriculum resolution copies topics into your school private database. '
                                'If board templates are unavailable for the selected class/board, you can safely create custom syllabus or import CSV.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Populate Curriculum'),
                  onPressed: selectedClassIds.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final controller = ref.read(academicPlanningControllerProvider.notifier);
                          final result = await controller.populateFromBoard(
                            schoolId: schoolId,
                            academicYearId: ayId,
                            board: selectedBoard,
                            classIds: selectedClassIds.toList(),
                            stateName: stateName.isNotEmpty ? stateName : null,
                          );

                          if (result != null && context.mounted) {
                            if (result.available) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text(result.message),
                                ),
                              );
                              // Refresh syllabus list
                              final targetClass = classId ?? _selectedClassId;
                              final targetSubject = subjectId ?? _selectedSubjectId;
                              if (targetClass != null && targetSubject != null) {
                                _invalidateSyllabusProviders(
                                  schoolId: schoolId,
                                  ayId: ayId,
                                  classId: targetClass,
                                  subjectId: targetSubject,
                                );
                              }
                            } else {
                              final targetClass = classId ?? _selectedClassId;
                              final targetSubject = subjectId ?? _selectedSubjectId;
                              _showFallbackModal(
                                context,
                                result.message,
                                schoolId: schoolId,
                                ayId: ayId,
                                classId: targetClass,
                                subjectId: targetSubject,
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFallbackModal(
    BuildContext context,
    String message, {
    required String schoolId,
    required String ayId,
    String? classId,
    String? subjectId,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Curriculum Notice', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
            const SizedBox(height: 12),
            const Text(
              'Zero-hallucination policy: EduPulse AI will not invent official syllabus outlines. '
              'You can create custom topics or import a CSV/Excel outline below.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: const Text('Import CSV'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV Import wizard ready.')),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create Custom Topic'),
            onPressed: () {
              Navigator.pop(ctx);
              if (classId != null && subjectId != null) {
                _showAddTopicDialog(
                  context,
                  schoolId: schoolId,
                  ayId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                  currentSectionId: _selectedSectionId,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog(
    BuildContext context, {
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
    String? currentSectionId,
    List<SectionDto> availableSections = const [],
  }) {
    final formKey = GlobalKey<FormState>();
    final unitCtrl = TextEditingController();
    final chapCtrl = TextEditingController(text: 'Chapter 1: Overview');
    final topicCtrl = TextEditingController(text: 'Introduction & Foundations');
    final periodsCtrl = TextEditingController(text: '4');
    String? targetSectionId = currentSectionId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Add New Curriculum Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Creating a Unit establishes a primary curriculum block, an initial chapter, and a foundational topic.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit Name *',
                        hintText: 'e.g. Unit 1: Number Systems & Algebra',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: chapCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Initial Chapter Name (Optional)',
                        hintText: 'e.g. Chapter 1: Real Numbers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Initial Topic Name (Optional)',
                        hintText: 'e.g. Fundamental Theorem of Arithmetic',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: periodsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimated Periods *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return 'Must be >= 1';
                              return null;
                            },
                          ),
                        ),
                        if (availableSections.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: targetSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Scope *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Sections (Class-wide)'),
                                ),
                                ...availableSections.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text('Section ${s.name}'),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => targetSectionId = val),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Create Unit'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final controller = ref.read(academicPlanningControllerProvider.notifier);
                final res = await controller.createUnit(
                  schoolId: schoolId,
                  academicYearId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                  sectionId: targetSectionId,
                  unitName: unitCtrl.text.trim(),
                  initialChapterName: chapCtrl.text.trim().isNotEmpty ? chapCtrl.text.trim() : null,
                  initialTopicName: topicCtrl.text.trim().isNotEmpty ? topicCtrl.text.trim() : null,
                  estimatedPeriods: int.tryParse(periodsCtrl.text) ?? 4,
                );
                if (res != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Unit "${res.unitName}" created successfully!'),
                    ),
                  );
                  _invalidateSyllabusProviders(
                    schoolId: schoolId,
                    ayId: ayId,
                    classId: classId,
                    subjectId: subjectId,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChapterDialog(
    BuildContext context, {
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
    String? currentSectionId,
    String? prefilledUnit,
    List<String> existingUnits = const [],
    List<SectionDto> availableSections = const [],
  }) {
    final formKey = GlobalKey<FormState>();
    final unitCtrl = TextEditingController(text: prefilledUnit ?? (existingUnits.isNotEmpty ? existingUnits.first : 'Unit 1'));
    final chapCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final periodsCtrl = TextEditingController(text: '4');
    final descCtrl = TextEditingController();
    String? targetSectionId = currentSectionId;
    String selectedUnitMode = prefilledUnit != null ? 'FIXED' : (existingUnits.isNotEmpty ? 'SELECT' : 'CUSTOM');
    String? selectedExistingUnit = existingUnits.isNotEmpty ? existingUnits.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.note_add, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Add New Chapter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (prefilledUnit != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder, size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Under Unit: $prefilledUnit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      if (existingUnits.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Existing Unit', style: TextStyle(fontSize: 12)),
                                value: 'SELECT',
                                groupValue: selectedUnitMode,
                                onChanged: (v) => setDialogState(() => selectedUnitMode = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('New Unit', style: TextStyle(fontSize: 12)),
                                value: 'CUSTOM',
                                groupValue: selectedUnitMode,
                                onChanged: (v) => setDialogState(() => selectedUnitMode = v!),
                              ),
                            ),
                          ],
                        ),
                        if (selectedUnitMode == 'SELECT')
                          DropdownButtonFormField<String>(
                            value: selectedExistingUnit,
                            decoration: const InputDecoration(labelText: 'Select Unit *', border: OutlineInputBorder()),
                            items: existingUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setDialogState(() => selectedExistingUnit = v),
                          )
                        else
                          TextFormField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(labelText: 'New Unit Name *', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                          ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextFormField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(labelText: 'Unit Name *', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    TextFormField(
                      controller: chapCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Chapter Name *',
                        hintText: 'e.g. Chapter 2: Polynomials',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Chapter name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Initial Topic Name (Optional)',
                        hintText: 'e.g. Geometrical Meaning of Zeroes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: periodsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimated Periods *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return 'Must be >= 1';
                              return null;
                            },
                          ),
                        ),
                        if (availableSections.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: targetSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Scope *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Sections (Class-wide)'),
                                ),
                                ...availableSections.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text('Section ${s.name}'),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => targetSectionId = val),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Learning Objectives (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Create Chapter'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final resolvedUnit = prefilledUnit ?? (selectedUnitMode == 'SELECT' ? selectedExistingUnit! : unitCtrl.text.trim());
                if (resolvedUnit.isEmpty) return;
                Navigator.pop(ctx);
                final controller = ref.read(academicPlanningControllerProvider.notifier);
                final res = await controller.createChapter(
                  schoolId: schoolId,
                  academicYearId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                  sectionId: targetSectionId,
                  unitName: resolvedUnit,
                  chapterName: chapCtrl.text.trim(),
                  initialTopicName: topicCtrl.text.trim().isNotEmpty ? topicCtrl.text.trim() : null,
                  estimatedPeriods: int.tryParse(periodsCtrl.text) ?? 4,
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                );
                if (res != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Chapter "${res.chapterName}" created successfully!'),
                    ),
                  );
                  _invalidateSyllabusProviders(
                    schoolId: schoolId,
                    ayId: ayId,
                    classId: classId,
                    subjectId: subjectId,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTopicDialog(
    BuildContext context, {
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
    String? currentSectionId,
    String? prefilledUnit,
    String? prefilledChapter,
    List<String> existingUnits = const [],
    Map<String, List<String>> existingChaptersByUnit = const {},
    List<SectionDto> availableSections = const [],
  }) {
    final formKey = GlobalKey<FormState>();
    final unitCtrl = TextEditingController(text: prefilledUnit ?? (existingUnits.isNotEmpty ? existingUnits.first : 'Unit 1: Foundations'));
    final chapterCtrl = TextEditingController(text: prefilledChapter ?? 'Chapter 1');
    final topicCtrl = TextEditingController();
    final periodsCtrl = TextEditingController(text: '3');
    final descCtrl = TextEditingController();
    String? targetSectionId = currentSectionId;

    String selectedUnitMode = prefilledUnit != null ? 'FIXED' : (existingUnits.isNotEmpty ? 'SELECT' : 'CUSTOM');
    String? selectedUnit = prefilledUnit ?? (existingUnits.isNotEmpty ? existingUnits.first : null);

    List<String> availableChapters = selectedUnit != null ? (existingChaptersByUnit[selectedUnit] ?? []) : [];
    String selectedChapterMode = prefilledChapter != null ? 'FIXED' : (availableChapters.isNotEmpty ? 'SELECT' : 'CUSTOM');
    String? selectedChapter = prefilledChapter ?? (availableChapters.isNotEmpty ? availableChapters.first : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.add_task, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Add Syllabus Topic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (prefilledUnit != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder, size: 16, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Unit: $prefilledUnit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      if (existingUnits.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Existing Unit', style: TextStyle(fontSize: 12)),
                                value: 'SELECT',
                                groupValue: selectedUnitMode,
                                onChanged: (v) => setDialogState(() {
                                  selectedUnitMode = v!;
                                  availableChapters = selectedUnit != null ? (existingChaptersByUnit[selectedUnit] ?? []) : [];
                                  if (availableChapters.isNotEmpty) {
                                    selectedChapter = availableChapters.first;
                                    selectedChapterMode = 'SELECT';
                                  } else {
                                    selectedChapterMode = 'CUSTOM';
                                  }
                                }),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('New Unit', style: TextStyle(fontSize: 12)),
                                value: 'CUSTOM',
                                groupValue: selectedUnitMode,
                                onChanged: (v) => setDialogState(() {
                                  selectedUnitMode = v!;
                                  selectedChapterMode = 'CUSTOM';
                                }),
                              ),
                            ),
                          ],
                        ),
                        if (selectedUnitMode == 'SELECT')
                          DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(labelText: 'Unit *', border: OutlineInputBorder()),
                            items: existingUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setDialogState(() {
                              selectedUnit = v;
                              availableChapters = v != null ? (existingChaptersByUnit[v] ?? []) : [];
                              if (availableChapters.isNotEmpty) {
                                selectedChapter = availableChapters.first;
                                selectedChapterMode = 'SELECT';
                              } else {
                                selectedChapterMode = 'CUSTOM';
                              }
                            }),
                          )
                        else
                          TextFormField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(labelText: 'New Unit Name *', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                          ),
                        const SizedBox(height: 10),
                      ] else ...[
                        TextFormField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(labelText: 'Unit Name *', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    if (prefilledChapter != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.article_outlined, size: 16, color: Color(0xFF334155)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Chapter: $prefilledChapter', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      if (availableChapters.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Existing Chapter', style: TextStyle(fontSize: 12)),
                                value: 'SELECT',
                                groupValue: selectedChapterMode,
                                onChanged: (v) => setDialogState(() => selectedChapterMode = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('New Chapter', style: TextStyle(fontSize: 12)),
                                value: 'CUSTOM',
                                groupValue: selectedChapterMode,
                                onChanged: (v) => setDialogState(() => selectedChapterMode = v!),
                              ),
                            ),
                          ],
                        ),
                        if (selectedChapterMode == 'SELECT')
                          DropdownButtonFormField<String>(
                            value: selectedChapter,
                            decoration: const InputDecoration(labelText: 'Chapter *', border: OutlineInputBorder()),
                            items: availableChapters.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setDialogState(() => selectedChapter = v),
                          )
                        else
                          TextFormField(
                            controller: chapterCtrl,
                            decoration: const InputDecoration(labelText: 'New Chapter Name *', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Chapter name is required' : null,
                          ),
                        const SizedBox(height: 10),
                      ] else ...[
                        TextFormField(
                          controller: chapterCtrl,
                          decoration: const InputDecoration(labelText: 'Chapter Name *', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Chapter name is required' : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    TextFormField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Topic Name *',
                        hintText: 'e.g. Fundamental Theorem of Arithmetic',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Topic name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: periodsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimated Periods *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return 'Must be >= 1';
                              return null;
                            },
                          ),
                        ),
                        if (availableSections.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: targetSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Scope *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Sections (Class-wide)'),
                                ),
                                ...availableSections.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text('Section ${s.name}'),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => targetSectionId = val),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Learning Objectives / Remarks (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save Topic'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final resolvedUnit = prefilledUnit ?? (selectedUnitMode == 'SELECT' ? selectedUnit! : unitCtrl.text.trim());
                final resolvedChapter = prefilledChapter ?? (selectedChapterMode == 'SELECT' ? selectedChapter! : chapterCtrl.text.trim());
                if (resolvedUnit.isEmpty || resolvedChapter.isEmpty) return;

                Navigator.pop(ctx);
                final controller = ref.read(academicPlanningControllerProvider.notifier);
                final res = await controller.createTopic(
                  schoolId: schoolId,
                  academicYearId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                  sectionId: targetSectionId,
                  unitName: resolvedUnit,
                  chapterName: resolvedChapter,
                  topicName: topicCtrl.text.trim(),
                  estimatedPeriods: int.tryParse(periodsCtrl.text) ?? 3,
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                );
                if (res != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Topic "${res.topicName}" created successfully!'),
                    ),
                  );
                  _invalidateSyllabusProviders(
                    schoolId: schoolId,
                    ayId: ayId,
                    classId: classId,
                    subjectId: subjectId,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTopic(
    BuildContext context, {
    required SyllabusItem item,
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Topic', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete topic "${item.topicName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await ref.read(academicPlanningControllerProvider.notifier).deleteSyllabusEntry(
                schoolId: schoolId,
                syllabusId: item.id,
              );
              if (ok && mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Topic deleted.')),
                );
                _invalidateSyllabusProviders(
                  schoolId: schoolId,
                  ayId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChapter(
    BuildContext context, {
    required String chapterName,
    required String unitName,
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Chapter', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete chapter "$chapterName" and all its topics? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await ref.read(academicPlanningControllerProvider.notifier).deleteChapter(
                schoolId: schoolId,
                academicYearId: ayId,
                classId: classId,
                subjectId: subjectId,
                chapterName: chapterName,
                unitName: unitName,
              );
              if (ok && mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Chapter "$chapterName" deleted.')),
                );
                _invalidateSyllabusProviders(
                  schoolId: schoolId,
                  ayId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUnit(
    BuildContext context, {
    required String unitName,
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Unit', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete unit "$unitName" and all its chapters & topics? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await ref.read(academicPlanningControllerProvider.notifier).deleteUnit(
                schoolId: schoolId,
                academicYearId: ayId,
                classId: classId,
                subjectId: subjectId,
                unitName: unitName,
              );
              if (ok && mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Unit "$unitName" deleted.')),
                );
                _invalidateSyllabusProviders(
                  schoolId: schoolId,
                  ayId: ayId,
                  classId: classId,
                  subjectId: subjectId,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLifecycleDialog(
    BuildContext context,
    SyllabusItem item, {
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    String selectedStatus = item.lifecycleStatus;
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Update Lifecycle: ${item.topicName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lifecycle State *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'PLANNED', child: Text('PLANNED - Scheduled in Curriculum')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN_PROGRESS - Currently Being Taught')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED - Covered & Assessed')),
                  DropdownMenuItem(value: 'DEFERRED', child: Text('DEFERRED - Postponed to next term')),
                  DropdownMenuItem(value: 'REOPENED', child: Text('REOPENED - Revision / Remedial Required')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                decoration: InputDecoration(
                  labelText: 'Remarks / Rationale',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final controller = ref.read(academicPlanningControllerProvider.notifier);
                final ok = await controller.updateLifecycleStatus(
                  syllabusId: item.id,
                  status: selectedStatus,
                  remarks: remarksCtrl.text.isNotEmpty ? remarksCtrl.text : null,
                );
                if (ok && mounted) {
                  _invalidateSyllabusProviders(
                    schoolId: schoolId,
                    ayId: ayId,
                    classId: classId,
                    subjectId: subjectId,
                  );
                }
              },
              child: const Text('Update Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoverageDialog(
    BuildContext context,
    SyllabusItem item, {
    required String schoolId,
    required String ayId,
    required String classId,
    required String subjectId,
  }) {
    String selectedCoverage = item.coverageStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Update Coverage: ${item.topicName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Teaching Coverage Status *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: ['PENDING', 'ONGOING', 'COMPLETED'].contains(selectedCoverage.toUpperCase())
                    ? selectedCoverage.toUpperCase()
                    : 'PENDING',
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING - Not Started')),
                  DropdownMenuItem(value: 'ONGOING', child: Text('ONGOING - In Progress')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED - Fully Covered')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedCoverage = val);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Updating topic coverage updates academic planning tracking across classes.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final controller = ref.read(academicPlanningControllerProvider.notifier);
                final ok = await controller.updateCoverageStatus(
                  schoolId: schoolId,
                  syllabusId: item.id,
                  coverageStatus: selectedCoverage,
                );
                if (ok && mounted) {
                  _invalidateSyllabusProviders(
                    schoolId: schoolId,
                    ayId: ayId,
                    classId: classId,
                    subjectId: subjectId,
                  );
                }
              },
              child: const Text('Save Coverage'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        body: const Center(
          child: Text('Please select a school campus from the header to manage syllabus.'),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));

    final String? effectiveAyId;
    if (_selectedAyId != null && ayState.years.any((y) => y.id == _selectedAyId)) {
      effectiveAyId = _selectedAyId;
    } else if (ayState.years.isNotEmpty) {
      effectiveAyId = ayState.years.where((y) => y.isCurrent).firstOrNull?.id ?? ayState.years.first.id;
    } else {
      effectiveAyId = null;
    }

    final String? effectiveClassId;
    if (_selectedClassId != null && classesState.classes.any((c) => c.id == _selectedClassId)) {
      effectiveClassId = _selectedClassId;
    } else if (classesState.classes.isNotEmpty) {
      effectiveClassId = classesState.classes.first.id;
    } else {
      effectiveClassId = null;
    }

    final classSections = effectiveClassId != null
        ? sectionsState.sections.where((s) => s.classId == effectiveClassId).toList()
        : <SectionDto>[];

    final AsyncValue<List<SubjectDto>>? assignedSubjectsAsync;
    if (effectiveAyId != null && effectiveClassId != null) {
      assignedSubjectsAsync = ref.watch(classAssignedSubjectsProvider((
        schoolId: schoolId,
        academicYearId: effectiveAyId,
        classId: effectiveClassId,
      )));
    } else {
      assignedSubjectsAsync = null;
    }

    final List<SubjectDto> assignedSubjects = assignedSubjectsAsync?.asData?.value ?? [];

    final String? effectiveSubjectId;
    if (assignedSubjects.isNotEmpty) {
      if (_selectedSubjectId != null && assignedSubjects.any((s) => s.id == _selectedSubjectId)) {
        effectiveSubjectId = _selectedSubjectId;
      } else {
        effectiveSubjectId = assignedSubjects.first.id;
      }
    } else {
      effectiveSubjectId = null;
    }

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      appBar: AppBar(
        title: const Text('Syllabus & Curriculum Intelligence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F766E),
              side: const BorderSide(color: Color(0xFF0F766E)),
            ),
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: const Text('Completion Analytics'),
            onPressed: () => context.push(AppRoutes.academicPlanning),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.auto_stories, size: 16),
            label: const Text('Populate from Board'),
            onPressed: effectiveAyId != null
                ? () => _showPopulateBoardDialog(
                      context,
                      schoolId,
                      effectiveAyId!,
                      classId: effectiveClassId,
                      subjectId: effectiveSubjectId,
                    )
                : null,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: const Text('+ Add Unit'),
            onPressed: (effectiveAyId != null && effectiveClassId != null && effectiveSubjectId != null)
                ? () => _showAddUnitDialog(
                      context,
                      schoolId: schoolId,
                      ayId: effectiveAyId!,
                      classId: effectiveClassId!,
                      subjectId: effectiveSubjectId!,
                      currentSectionId: _selectedSectionId,
                      availableSections: classSections,
                    )
                : null,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF020617),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_task, size: 16),
            label: const Text('+ Add Topic'),
            onPressed: (effectiveAyId != null && effectiveClassId != null && effectiveSubjectId != null)
                ? () => _showAddTopicDialog(
                      context,
                      schoolId: schoolId,
                      ayId: effectiveAyId!,
                      classId: effectiveClassId!,
                      subjectId: effectiveSubjectId!,
                      currentSectionId: _selectedSectionId,
                      availableSections: classSections,
                    )
                : null,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                // Academic Year
                Expanded(
                  child: SafeDropdownButtonFormField<String>(
                    value: effectiveAyId,
                    decoration: InputDecoration(
                      labelText: 'Academic Year',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ayState.years.map((y) => DropdownMenuItem(
                      value: y.id,
                      child: Text(y.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null && val != effectiveAyId) {
                        setState(() {
                          _selectedAyId = val;
                          _selectedClassId = null;
                          _selectedSubjectId = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Class
                Expanded(
                  child: SafeDropdownButtonFormField<String>(
                    value: effectiveClassId,
                    decoration: InputDecoration(
                      labelText: 'Class / Grade',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: classesState.classes.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null && val != effectiveClassId) {
                        setState(() {
                          _selectedClassId = val;
                          _selectedSectionId = null;
                          _selectedSubjectId = null;
                        });
                        ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Section (Optional)
                Expanded(
                  child: SafeDropdownButtonFormField<String?>(
                    value: _selectedSectionId,
                    decoration: InputDecoration(
                      labelText: 'Section (Optional)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Sections (Class-wide)', overflow: TextOverflow.ellipsis),
                      ),
                      ...classSections.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text('Section ${s.name}', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSectionId = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Subject
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (assignedSubjectsAsync == null || assignedSubjectsAsync.isLoading) {
                        return SafeDropdownButtonFormField<String>(
                          value: null,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            hintText: 'Loading subjects...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: const SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ),
                          items: const [],
                          onChanged: null,
                        );
                      }

                      if (assignedSubjectsAsync.hasError) {
                        return SafeDropdownButtonFormField<String>(
                          value: null,
                          decoration: InputDecoration(
                            labelText: 'Subject (Error loading)',
                            hintText: 'Failed to load subjects',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [],
                          onChanged: null,
                        );
                      }

                      final hasNoSubjects = assignedSubjects.isEmpty;
                      return SafeDropdownButtonFormField<String>(
                        value: effectiveSubjectId,
                        decoration: InputDecoration(
                          labelText: hasNoSubjects ? 'No subjects found' : 'Subject',
                          hintText: hasNoSubjects ? 'No subjects assigned' : 'Select Subject',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: assignedSubjects.map((s) {
                          final badge = s.isSchoolAdded ? ' [Custom]' : '';
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${s.subjectName}$badge',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: hasNoSubjects
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedSubjectId = val);
                                }
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Main Syllabus Tree View
          Expanded(
            child: (effectiveAyId == null || effectiveClassId == null)
                ? const Center(
                    child: Text(
                      'Select Academic Year and Class to view syllabus.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : (assignedSubjectsAsync != null && assignedSubjectsAsync.isLoading)
                    ? const Center(child: CircularProgressIndicator())
                    : (assignedSubjects.isEmpty)
                        ? Center(
                            child: Container(
                              width: 480,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_outlined, size: 48, color: Color(0xFF64748B)),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Subjects Configured for this Class',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'There are currently no subjects mapped to this class. Assign subjects in Class Subject Setup or School Setup to manage the syllabus.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : (effectiveSubjectId == null)
                            ? const Center(
                                child: Text(
                                  'Select a Subject to view syllabus.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              )
                            : Consumer(
                                builder: (context, ref, child) {
                                  final activeAyId = effectiveAyId!;
                                  final activeClassId = effectiveClassId!;
                                  final activeSubjectId = effectiveSubjectId!;
                                  final syllState = ref.watch(syllabusListProvider((
                                    schoolId: schoolId,
                                    academicYearId: activeAyId,
                                    classId: activeClassId,
                                    subjectId: activeSubjectId,
                                    sectionId: _selectedSectionId,
                                  )));

                                  return syllState.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 8),
                              Text('Failed to load syllabus: $err'),
                            ],
                          ),
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return Center(
                              child: Container(
                                width: 480,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xFF0F766E)),
                                    const SizedBox(height: 12),
                                    const Text('No Syllabus Configured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'There is currently no official or custom syllabus defined for this subject. '
                                      'You can populate canonical outlines directly from CBSE/ICSE or import a custom curriculum.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.download, size: 16),
                                          label: const Text('Populate from Board'),
                                          onPressed: () => _showPopulateBoardDialog(
                                            context,
                                            schoolId,
                                            activeAyId,
                                            classId: activeClassId,
                                            subjectId: activeSubjectId,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                                          label: const Text('+ Add Unit'),
                                          onPressed: () => _showAddUnitDialog(
                                            context,
                                            schoolId: schoolId,
                                            ayId: activeAyId,
                                            classId: activeClassId,
                                            subjectId: activeSubjectId,
                                            currentSectionId: _selectedSectionId,
                                            availableSections: classSections,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF020617),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.add_task, size: 16),
                                          label: const Text('+ Add Topic'),
                                          onPressed: () => _showAddTopicDialog(
                                            context,
                                            schoolId: schoolId,
                                            ayId: activeAyId,
                                            classId: activeClassId,
                                            subjectId: activeSubjectId,
                                            currentSectionId: _selectedSectionId,
                                            availableSections: classSections,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Group by Unit and Chapter
                          final Map<String, Map<String, List<SyllabusItem>>> grouped = {};
                          int totalPeriods = 0;
                          for (final it in items) {
                            totalPeriods += it.estimatedPeriods;
                            grouped.putIfAbsent(it.unitName, () => {});
                            grouped[it.unitName]!.putIfAbsent(it.chapterName, () => []);
                            grouped[it.unitName]![it.chapterName]!.add(it);
                          }

                          final existingUnits = grouped.keys.toList();
                          final Map<String, List<String>> existingChaptersByUnit = {};
                          for (final entry in grouped.entries) {
                            existingChaptersByUnit[entry.key] = entry.value.keys.toList();
                          }

                          final coverageSummaryAsync = ref.watch(coverageSummaryProvider((
                            schoolId: schoolId,
                            academicYearId: activeAyId,
                            classId: activeClassId,
                            subjectId: activeSubjectId,
                            sectionId: _selectedSectionId,
                          )));
                          final coverageSummary = coverageSummaryAsync.asData?.value;
                          final completedTopicsCount = coverageSummary?.completedTopics ?? items.where((t) => t.coverageStatus == 'COMPLETED').length;
                          final coveragePctText = coverageSummary != null
                              ? '${coverageSummary.coveragePercentage.toStringAsFixed(0)}%'
                              : (items.isNotEmpty
                                  ? '${((completedTopicsCount / items.length) * 100).toStringAsFixed(0)}%'
                                  : '0%');
                          final plannedPeriodsText = coverageSummary != null && coverageSummary.plannedPeriods > 0
                              ? '${coverageSummary.plannedPeriods} Periods'
                              : '$totalPeriods Periods';
                          final timetablePeriodsText = coverageSummary != null && coverageSummary.weeklyTimetablePeriods > 0
                              ? '${coverageSummary.weeklyTimetablePeriods} / wk'
                              : 'Unscheduled';

                          return ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              // Syllabus Summary Metric Header with Scope & Quick Actions
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cols = constraints.maxWidth >= 1000
                                            ? 6
                                            : (constraints.maxWidth >= 650 ? 3 : 2);
                                        final itemWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
                                        return Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            SizedBox(width: itemWidth, child: _buildMetric('Units', '${grouped.keys.length}', Icons.folder_open)),
                                            SizedBox(width: itemWidth, child: _buildMetric('Chapters', '${grouped.values.fold<int>(0, (sum, m) => sum + m.keys.length)}', Icons.menu_book)),
                                            SizedBox(width: itemWidth, child: _buildMetric('Total Topics', '${items.length}', Icons.checklist)),
                                            SizedBox(width: itemWidth, child: _buildMetric('Planned Workload', plannedPeriodsText, Icons.access_time)),
                                            SizedBox(width: itemWidth, child: _buildMetric('Coverage Pacing', coveragePctText, Icons.task_alt, color: const Color(0xFF10B981))),
                                            SizedBox(width: itemWidth, child: _buildMetric('Timetable Periods', timetablePeriodsText, Icons.calendar_today_outlined, color: const Color(0xFF0284C7))),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Text(
                                              _selectedSectionId != null
                                                  ? 'Scope: Section-specific + Class-wide catalog'
                                                  : 'Scope: Full Class-wide curriculum catalog',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F766E),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(Icons.create_new_folder_outlined, size: 14),
                                              label: const Text('+ Add Unit', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showAddUnitDialog(
                                                context,
                                                schoolId: schoolId,
                                                ayId: activeAyId,
                                                classId: activeClassId,
                                                subjectId: activeSubjectId,
                                                currentSectionId: _selectedSectionId,
                                                availableSections: classSections,
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F766E),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(Icons.note_add_outlined, size: 14),
                                              label: const Text('+ Add Chapter', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showAddChapterDialog(
                                                context,
                                                schoolId: schoolId,
                                                ayId: activeAyId,
                                                classId: activeClassId,
                                                subjectId: activeSubjectId,
                                                currentSectionId: _selectedSectionId,
                                                existingUnits: existingUnits,
                                                availableSections: classSections,
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF020617),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(Icons.add_task, size: 14),
                                              label: const Text('+ Add Topic', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showAddTopicDialog(
                                                context,
                                                schoolId: schoolId,
                                                ayId: activeAyId,
                                                classId: activeClassId,
                                                subjectId: activeSubjectId,
                                                currentSectionId: _selectedSectionId,
                                                existingUnits: existingUnits,
                                                existingChaptersByUnit: existingChaptersByUnit,
                                                availableSections: classSections,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Hierarchical Unit & Chapter Accordions
                              ...grouped.entries.map((unitEntry) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    leading: const Icon(Icons.folder, color: Color(0xFF0F766E)),
                                    title: Text(unitEntry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    subtitle: Text('${unitEntry.value.keys.length} Chapters • ${unitEntry.value.values.fold<int>(0, (sum, list) => sum + list.length)} Topics', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.note_add_outlined, size: 15, color: Color(0xFF0F766E)),
                                          label: const Text('+ Add Chapter', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                                          onPressed: () => _showAddChapterDialog(
                                            context,
                                            schoolId: schoolId,
                                            ayId: activeAyId,
                                            classId: activeClassId,
                                            subjectId: activeSubjectId,
                                            currentSectionId: _selectedSectionId,
                                            prefilledUnit: unitEntry.key,
                                            existingUnits: existingUnits,
                                            availableSections: classSections,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                                          tooltip: 'Delete Unit "${unitEntry.key}"',
                                          onPressed: () => _confirmDeleteUnit(
                                            context,
                                            unitName: unitEntry.key,
                                            schoolId: schoolId,
                                            ayId: activeAyId,
                                            classId: activeClassId,
                                            subjectId: activeSubjectId,
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: unitEntry.value.entries.map((chapEntry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: ExpansionTile(
                                            initiallyExpanded: true,
                                            leading: const Icon(Icons.article_outlined, size: 20, color: Color(0xFF334155)),
                                            title: Text(chapEntry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            subtitle: Text('${chapEntry.value.length} Topics • ${chapEntry.value.fold<int>(0, (sum, t) => sum + t.estimatedPeriods)} Planned Periods', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton.icon(
                                                  icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F766E)),
                                                  label: const Text('+ Add Topic', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                                                  onPressed: () => _showAddTopicDialog(
                                                    context,
                                                    schoolId: schoolId,
                                                    ayId: activeAyId,
                                                    classId: activeClassId,
                                                    subjectId: activeSubjectId,
                                                    currentSectionId: _selectedSectionId,
                                                    prefilledUnit: unitEntry.key,
                                                    prefilledChapter: chapEntry.key,
                                                    existingUnits: existingUnits,
                                                    existingChaptersByUnit: existingChaptersByUnit,
                                                    availableSections: classSections,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                                                  tooltip: 'Delete Chapter "${chapEntry.key}"',
                                                  onPressed: () => _confirmDeleteChapter(
                                                    context,
                                                    chapterName: chapEntry.key,
                                                    unitName: unitEntry.key,
                                                    schoolId: schoolId,
                                                    ayId: activeAyId,
                                                    classId: activeClassId,
                                                    subjectId: activeSubjectId,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            children: chapEntry.value.map((topic) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                decoration: const BoxDecoration(
                                                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE2E8F0),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text('${topic.sequenceOrder}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Flexible(
                                                                child: Text(topic.topicName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                                              ),
                                                              if (topic.sectionId != null) ...[
                                                                const SizedBox(width: 6),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.amber.shade50,
                                                                    borderRadius: BorderRadius.circular(4),
                                                                    border: Border.all(color: Colors.amber.shade300),
                                                                  ),
                                                                  child: Text('Section Custom', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          if (topic.description != null && topic.description!.isNotEmpty)
                                                            Text(topic.description!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                        ],
                                                      ),
                                                    ),
                                                    // Periods Badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEEF2F6),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text('${topic.estimatedPeriods} Periods', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Lifecycle Status Pill
                                                    InkWell(
                                                      onTap: () => _showLifecycleDialog(
                                                        context,
                                                        topic,
                                                        schoolId: schoolId,
                                                        ayId: activeAyId,
                                                        classId: activeClassId,
                                                        subjectId: activeSubjectId,
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: topic.lifecycleColor.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: topic.lifecycleColor.withOpacity(0.4)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(topic.lifecycleStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: topic.lifecycleColor)),
                                                            const SizedBox(width: 4),
                                                            Icon(Icons.edit, size: 10, color: topic.lifecycleColor),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Interactive Coverage Status Pill
                                                    InkWell(
                                                      onTap: () => _showCoverageDialog(
                                                        context,
                                                        topic,
                                                        schoolId: schoolId,
                                                        ayId: activeAyId,
                                                        classId: activeClassId,
                                                        subjectId: activeSubjectId,
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: topic.statusColor.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: topic.statusColor.withOpacity(0.4)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(topic.coverageStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: topic.statusColor)),
                                                            const SizedBox(width: 4),
                                                            Icon(Icons.tune, size: 10, color: topic.statusColor),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    // Delete Topic Action
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                                                      tooltip: 'Delete Topic',
                                                      onPressed: () => _confirmDeleteTopic(
                                                        context,
                                                        item: topic,
                                                        schoolId: schoolId,
                                                        ayId: activeAyId,
                                                        classId: activeClassId,
                                                        subjectId: activeSubjectId,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, {Color? color}) {
    final effectiveColor = color ?? const Color(0xFF0F766E);
    return Row(
      children: [
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: effectiveColor)),
          ],
        ),
      ],
    );
  }
}
