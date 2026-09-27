import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../providers/school_setup_providers.dart';
import '../../data/models/school_setup_models.dart';
import '../widgets/ai_draft_syllabus_dialog.dart';
import '../../../../core/routing/routes.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  String? _selectedAyId;
  String _sourceFilter = 'ALL'; // 'ALL', 'BOARD_OFFICIAL', 'SCHOOL_ADDED'
  String _categoryFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'CORE',
    'LANGUAGE',
    'ELECTIVE',
    'ADDITIONAL',
    'VOCATIONAL',
    'SKILL',
    'REMEDIAL',
    'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: _selectedAyId);
        ref.read(classesProvider(schoolId).notifier).fetchClasses(academicYearId: _selectedAyId);
      }
    });
  }

  Future<void> _openAddSchoolSubjectDialog(String schoolId, String academicYearId) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final shortNameCtrl = TextEditingController();
    final weeklyPeriodsCtrl = TextEditingController(text: '4');
    final maxMarksCtrl = TextEditingController(text: '100');
    final theoryMarksCtrl = TextEditingController(text: '80');
    final practicalMarksCtrl = TextEditingController(text: '0');
    final passMarksCtrl = TextEditingController(text: '35');

    String selectedCategory = 'ADDITIONAL';
    String selectedType = 'THEORY';
    bool isExamApplicable = true;
    bool isMarksApplicable = true;
    bool appearsInReportCard = true;
    bool includedInConsolidated = true;
    bool includedInRank = true;

    final classesState = ref.read(classesProvider(schoolId));
    final schoolClasses = classesState.classes;
    final selectedClassIds = <String>{};
    bool isSubmitting = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: Colors.amber.shade900, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Add School-Specific Subject'),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'School-added subjects (e.g. Robotics, Coding, Value Education) are strictly tenant-isolated and automatically accounted for in the AI timetable capacity engine.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name*',
                          hintText: 'e.g. Robotics & Coding',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Subject Code*',
                                hintText: 'e.g. ROBO-101',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: shortNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Short Name',
                                hintText: 'e.g. ROBO',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: const InputDecoration(labelText: 'Category*', border: OutlineInputBorder()),
                              items: ['ADDITIONAL', 'VOCATIONAL', 'SKILL', 'REMEDIAL', 'ELECTIVE', 'CORE', 'OTHER']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: const InputDecoration(labelText: 'Type*', border: OutlineInputBorder()),
                              items: ['THEORY', 'PRACTICAL', 'THEORY_PRACTICAL']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => selectedType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: weeklyPeriodsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Weekly Periods Count*',
                                hintText: 'e.g. 4',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1) return 'Must be >= 1';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: maxMarksCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Marks*',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: theoryMarksCtrl,
                              decoration: const InputDecoration(labelText: 'Theory Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              enabled: selectedType != 'PRACTICAL',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: practicalMarksCtrl,
                              decoration: const InputDecoration(labelText: 'Practical Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              enabled: selectedType != 'THEORY',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: passMarksCtrl,
                              decoration: const InputDecoration(labelText: 'Pass Marks*', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Assessment & Report Card Rules', style: theme.textTheme.labelLarge),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Examination Applicable'),
                        value: isExamApplicable,
                        onChanged: (v) => setDialogState(() => isExamApplicable = v),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Marks Applicable'),
                        value: isMarksApplicable,
                        onChanged: (v) => setDialogState(() => isMarksApplicable = v),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Appears in Report Card'),
                        value: appearsInReportCard,
                        onChanged: (v) => setDialogState(() => appearsInReportCard = v),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Included in Rank Calculation'),
                        value: includedInRank,
                        onChanged: (v) => setDialogState(() => includedInRank = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Target Classes (Timetable Allocation)', style: theme.textTheme.labelLarge),
                          const Spacer(),
                          if (schoolClasses.isNotEmpty) ...[
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedClassIds.addAll(schoolClasses.map((c) => c.id));
                                      });
                                    },
                              child: const Text('Select All', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedClassIds.clear();
                                      });
                                    },
                              child: const Text('Clear', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mapped classes will have this subject allocated with the specified weekly periods in the AI Timetable Engine.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      if (schoolClasses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('No classes found for this academic year.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: schoolClasses.map((cls) {
                            final isSelected = selectedClassIds.contains(cls.id);
                            return FilterChip(
                              label: Text(cls.name),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFF0F766E),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: isSubmitting
                                  ? null
                                  : (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedClassIds.add(cls.id);
                                        } else {
                                          selectedClassIds.remove(cls.id);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(errorMessage!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        final periods = int.tryParse(weeklyPeriodsCtrl.text) ?? 4;
                        final maxM = int.tryParse(maxMarksCtrl.text) ?? 100;
                        final theoryM = int.tryParse(theoryMarksCtrl.text) ?? 0;
                        final pracM = int.tryParse(practicalMarksCtrl.text) ?? 0;
                        final passM = int.tryParse(passMarksCtrl.text) ?? 35;

                        final payload = {
                          'school_id': schoolId,
                          'academic_year_id': academicYearId,
                          'subject_code': codeCtrl.text.trim(),
                          'subject_name': nameCtrl.text.trim(),
                          'short_name': shortNameCtrl.text.trim().isEmpty ? null : shortNameCtrl.text.trim(),
                          'category': selectedCategory,
                          'subject_type': selectedType,
                          'weekly_periods': periods,
                          'max_marks': maxM,
                          'theory_marks': theoryM,
                          'practical_marks': practicalMarksCtrl.text.trim().isEmpty ? 0 : pracM,
                          'pass_marks': passM,
                          'source_type': 'SCHOOL_ADDED',
                          'is_examination_applicable': isExamApplicable,
                          'is_marks_applicable': isMarksApplicable,
                          'appears_in_report_card': appearsInReportCard,
                          'included_in_consolidated_result': includedInConsolidated,
                          'included_in_rank_calculation': includedInRank,
                          'status': 'ACTIVE',
                        };

                        try {
                          final apiClient = ref.read(apiClientProvider);
                          final createRes = await apiClient.post(
                            '/subjects',
                            data: payload,
                            mapper: (json) {
                              final body = json as Map<String, dynamic>;
                              return body['data'] as Map<String, dynamic>?;
                            },
                          );

                          String? createdId;
                          String? errStr;
                          createRes.when(
                            onSuccess: (data) => createdId = data?['id'] as String?,
                            onFailure: (f) => errStr = f.message,
                          );

                          if (errStr != null || createdId == null) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = errStr ?? 'Failed to create subject.';
                            });
                            return;
                          }

                          if (selectedClassIds.isNotEmpty) {
                            final batchPayload = {
                              'school_id': schoolId,
                              'academic_year_id': academicYearId,
                              'subject_id': createdId,
                              'class_ids': selectedClassIds.toList(),
                              'weekly_periods': periods,
                              'period_duration_minutes': 45,
                              'preferred_days': <String>[],
                            };
                            final batchRes = await apiClient.post(
                              '/class-subject-assignments/batch',
                              data: batchPayload,
                              mapper: (json) => json,
                            );
                            batchRes.when(
                              onSuccess: (_) {},
                              onFailure: (f) {
                                debugPrint('Batch class assignment warning: ${f.message}');
                              },
                            );
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'School subject "${nameCtrl.text.trim()}" created'
                                  '${selectedClassIds.isNotEmpty ? " & mapped to ${selectedClassIds.length} class(es)" : ""} successfully!',
                                ),
                                backgroundColor: const Color(0xFF0F766E),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = e.toString();
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Subject'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      _refreshData();
    }
  }

  Future<void> _openAIDraftDialog(SubjectDto sub, String schoolId, String academicYearId) async {
    final classesState = ref.read(classesProvider(schoolId));
    if (classesState.classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure classes first before generating draft syllabus.')),
      );
      return;
    }

    await AIDraftSyllabusDialog.show(
      context,
      schoolId: schoolId,
      academicYearId: academicYearId,
      subjectId: sub.id,
      subjectName: sub.subjectName,
      classes: classesState.classes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() => _selectedAyId = null);
        ref.read(academicYearsProvider(next).notifier).fetchYears();
        ref.read(subjectsProvider(next).notifier).fetchSubjects(academicYearId: null);
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Curriculum & Subjects Directory')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to configure its subjects.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final subjectState = ref.watch(subjectsProvider(schoolId));

    if (ayState.years.isNotEmpty && _selectedAyId == null) {
      final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      _selectedAyId = current.id;
      Future.microtask(() {
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: _selectedAyId);
        ref.read(classesProvider(schoolId).notifier).fetchClasses(academicYearId: _selectedAyId);
      });
    }

    // Filter logic
    final allSubjects = subjectState.subjects;
    final filtered = allSubjects.where((s) {
      if (_sourceFilter == 'BOARD_OFFICIAL' && !s.isBoardOfficial) return false;
      if (_sourceFilter == 'SCHOOL_ADDED' && !s.isSchoolAdded) return false;
      if (_categoryFilter != 'ALL' && s.category != _categoryFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.subjectName.toLowerCase().contains(q);
        final matchCode = s.subjectCode.toLowerCase().contains(q);
        final matchShort = (s.shortName ?? '').toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchShort) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Curriculum & Subjects Directory'),
            Text(
              'Official Board curriculum & School-specific additional subjects',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
          if (_selectedAyId != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+ Add School Subject'),
              onPressed: () => _openAddSchoolSubjectDialog(schoolId, _selectedAyId!),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Register Board Subject'),
            onPressed: () async {
              await context.push('${AppRoutes.subjects}/new?school_id=$schoolId');
              _refreshData();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Header Card
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Academic Year Selector + Search Bar
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Text('Academic Year: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ayState.isLoading
                          ? const SizedBox(width: 120, child: LinearProgressIndicator())
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAyId,
                                items: ayState.years.map((y) {
                                  return DropdownMenuItem(value: y.id, child: Text(y.name));
                                }).toList(),
                                onChanged: (v) {
                                  setState(() => _selectedAyId = v);
                                  ref.read(subjectsProvider(schoolId).notifier).fetchSubjects(academicYearId: v);
                                },
                              ),
                            ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search subject or code...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Row 2: Source Filter Chips + Category Chips
                  Row(
                    children: [
                      const Text('Source:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All Sources'),
                        selected: _sourceFilter == 'ALL',
                        onSelected: (_) => setState(() => _sourceFilter = 'ALL'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        avatar: Icon(Icons.verified, size: 14, color: _sourceFilter == 'BOARD_OFFICIAL' ? Colors.white : Colors.teal),
                        label: const Text('Official Board'),
                        selected: _sourceFilter == 'BOARD_OFFICIAL',
                        selectedColor: const Color(0xFF0F766E),
                        onSelected: (_) => setState(() => _sourceFilter = 'BOARD_OFFICIAL'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        avatar: Icon(Icons.stars, size: 14, color: _sourceFilter == 'SCHOOL_ADDED' ? Colors.white : Colors.amber.shade900),
                        label: const Text('School Added'),
                        selected: _sourceFilter == 'SCHOOL_ADDED',
                        selectedColor: Colors.amber.shade800,
                        onSelected: (_) => setState(() => _sourceFilter = 'SCHOOL_ADDED'),
                      ),
                      const SizedBox(width: 16),
                      const Text('|  Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: FilterChip(
                                  label: Text(cat),
                                  selected: _categoryFilter == cat,
                                  onSelected: (_) => setState(() => _categoryFilter = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subjects List / Table
          Expanded(
            child: subjectState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : subjectState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${subjectState.error}', style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No subjects found matching current filters.',
                                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 12),
                                if (_selectedAyId != null)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add School-Specific Subject'),
                                    onPressed: () => _openAddSchoolSubjectDialog(schoolId, _selectedAyId!),
                                  ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: isMobile
                                ? _buildMobileList(filtered, schoolId, theme)
                                : _buildDesktopTable(filtered, schoolId, theme),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(SubjectDto sub) {
    if (sub.isSchoolAdded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade600),
        ),
        child: Text(
          'SCHOOL ADDED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.teal.shade400),
      ),
      child: Text(
        'OFFICIAL BOARD',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
      ),
    );
  }

  Widget _buildMobileList(List<SubjectDto> subjects, String schoolId, ThemeData theme) {
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final sub = subjects[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              sub.subjectName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSourceBadge(sub),
                        ],
                      ),
                    ),
                    _buildStatusChip(sub.status, theme),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Code: ${sub.subjectCode} • Short Name: ${sub.shortName ?? "-"}', style: theme.textTheme.bodyMedium),
                Text('Category: ${sub.category} • Type: ${sub.subjectType} • Periods: ${sub.weeklyPeriods ?? 4}/wk', style: theme.textTheme.bodyMedium),
                Text('Max: ${sub.maxMarks} • Theory: ${sub.theoryMarks} • Practical: ${sub.practicalMarks} • Pass: ${sub.passMarks}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (sub.isSchoolAdded && _selectedAyId != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF0F766E),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('AI Draft Syllabus'),
                        onPressed: () => _openAIDraftDialog(sub, schoolId, _selectedAyId!),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () async {
                        await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
                        _refreshData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<SubjectDto> subjects, String schoolId, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Subject Name & Source')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Periods/Wk')),
            DataColumn(label: Text('Exam & Marks')),
            DataColumn(label: Text('Report Card')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: subjects.map((sub) {
            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () async {
                      await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
                      _refreshData();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sub.subjectName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSourceBadge(sub),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(sub.subjectCode)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(sub.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                DataCell(Text(sub.subjectType)),
                DataCell(
                  Text(
                    '${sub.weeklyPeriods ?? 4} / wk',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Max: ${sub.maxMarks} • Pass: ${sub.passMarks}', style: const TextStyle(fontSize: 12)),
                      Text(
                        sub.isExaminationApplicable ? 'Exam: Yes' : 'Exam: No (Graded)',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Icon(
                    sub.appearsInReportCard ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: sub.appearsInReportCard ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                ),
                DataCell(_buildStatusChip(sub.status, theme)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub.isSchoolAdded && _selectedAyId != null)
                        IconButton(
                          tooltip: 'Generate AI Draft Syllabus',
                          icon: const Icon(Icons.auto_awesome, color: Color(0xFF0F766E), size: 20),
                          onPressed: () => _openAIDraftDialog(sub, schoolId, _selectedAyId!),
                        ),
                      IconButton(
                        tooltip: 'Edit details',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () async {
                          await context.push('${AppRoutes.subjects}/${sub.id}?school_id=$schoolId');
                          _refreshData();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.orange;
        break;
      case 'ARCHIVED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
