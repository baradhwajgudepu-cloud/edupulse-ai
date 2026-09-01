import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../providers/academic_provider.dart';
import '../../data/models/academic_models.dart';

class ManageExamsScreen extends ConsumerStatefulWidget {
  const ManageExamsScreen({super.key});

  @override
  ConsumerState<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends ConsumerState<ManageExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicStateProvider.notifier).fetchExaminations();
      ref.read(academicStateProvider.notifier).fetchClassesAndSections();
    });
  }

  void _showCreateExamDialog(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'UNIT_TEST';

    // Retrieve active Academic Year bounds from academicStateProvider state
    final academicState = ref.read(academicStateProvider);
    final activeAy = academicState.academicYears.firstWhere(
      (ay) => ay['is_current'] == true || ay['status'] == 'ACTIVE',
      orElse: () => <String, dynamic>{},
    );

    final bool hasActiveAy = activeAy.isNotEmpty;
    final ayStart = hasActiveAy
        ? DateTime.parse(activeAy['start_date'].toString())
        : DateTime.now();
    final ayEnd = hasActiveAy
        ? DateTime.parse(activeAy['end_date'].toString())
        : DateTime.now();
    final ayId = hasActiveAy ? activeAy['id'] as String? : null;

    // Initial Date selection within academic year bounds
    DateTime startDate = DateTime.now();
    if (hasActiveAy) {
      if (startDate.isBefore(ayStart)) {
        startDate = ayStart;
      } else if (startDate.isAfter(ayEnd)) {
        startDate = ayStart;
      }
    }
    DateTime endDate = startDate.add(const Duration(days: 7));
    if (hasActiveAy && endDate.isAfter(ayEnd)) {
      endDate = ayEnd;
    }

    String targetingScope = 'ALL_CLASSES'; // 'ALL_CLASSES', 'SPECIFIC_CLASSES', 'SPECIFIC_SECTIONS'
    List<String> selectedClassIds = [];
    List<String> selectedSectionIds = [];
    List<Map<String, dynamic>> schedules = []; // suggested exam papers list
    bool isLoadingSchedules = false;
    String? dialogError = hasActiveAy
        ? null
        : 'No active academic year found for this school context. Please contact system administrator.';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogTheme = Theme.of(context);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                children: [
                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create New Examination',
                        style: dialogTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dialogError != null) ...[
                              Container(
                                padding: EdgeInsets.all(spacing.sm),
                                decoration: BoxDecoration(
                                  color: dialogTheme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(radius.sm),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error, color: dialogTheme.colorScheme.error),
                                    SizedBox(width: spacing.sm),
                                    Expanded(
                                      child: Text(
                                        dialogError!,
                                        style: TextStyle(color: dialogTheme.colorScheme.onErrorContainer),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacing.md),
                            ],
                            TextFormField(
                              controller: nameController,
                              enabled: hasActiveAy,
                              decoration: const InputDecoration(labelText: 'Exam Name *'),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            SizedBox(height: spacing.sm),
                            TextFormField(
                              controller: descController,
                              enabled: hasActiveAy,
                              decoration: const InputDecoration(labelText: 'Description'),
                            ),
                            SizedBox(height: spacing.sm),
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: const InputDecoration(labelText: 'Exam Type *'),
                              items: const [
                                DropdownMenuItem(value: 'UNIT_TEST', child: Text('Unit Test')),
                                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                                DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                                DropdownMenuItem(value: 'HALF_YEARLY', child: Text('Half Yearly')),
                                DropdownMenuItem(value: 'PRE_FINAL', child: Text('Pre-Final')),
                                DropdownMenuItem(value: 'ANNUAL', child: Text('Annual')),
                                DropdownMenuItem(value: 'SUPPLEMENTARY', child: Text('Supplementary')),
                              ],
                              onChanged: !hasActiveAy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() => selectedType = val);
                                      }
                                    },
                            ),
                            SizedBox(height: spacing.md),
                            // Academic Year label
                            if (hasActiveAy)
                              Text(
                                'Academic Year: ${activeAy['name'] ?? 'Default'} (${DateFormat('dd MMM yyyy').format(ayStart)} - ${DateFormat('dd MMM yyyy').format(ayEnd)})',
                                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                  color: dialogTheme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            SizedBox(height: spacing.md),
                            // Date Range Picker row
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: !hasActiveAy
                                        ? null
                                        : () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: startDate,
                                              firstDate: ayStart,
                                              lastDate: ayEnd,
                                            );
                                            if (picked != null) {
                                              setDialogState(() {
                                                startDate = picked;
                                                if (endDate.isBefore(startDate)) {
                                                  endDate = startDate.add(const Duration(days: 7));
                                                  if (endDate.isAfter(ayEnd)) {
                                                    endDate = ayEnd;
                                                  }
                                                }
                                                schedules.clear();
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Start Date *'),
                                      child: Text(hasActiveAy ? DateFormat('dd MMM yyyy').format(startDate) : '--'),
                                    ),
                                  ),
                                ),
                                SizedBox(width: spacing.sm),
                                Expanded(
                                  child: InkWell(
                                    onTap: !hasActiveAy
                                        ? null
                                        : () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: endDate,
                                              firstDate: startDate,
                                              lastDate: ayEnd,
                                            );
                                            if (picked != null) {
                                              setDialogState(() {
                                                endDate = picked;
                                                schedules.clear();
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'End Date *'),
                                      child: Text(hasActiveAy ? DateFormat('dd MMM yyyy').format(endDate) : '--'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: spacing.lg),
                            // Targeting Option Radio Group
                            Text('Conduct Examination For', style: dialogTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            RadioListTile<String>(
                              title: const Text('All Classes'),
                              value: 'ALL_CLASSES',
                              groupValue: targetingScope,
                              onChanged: !hasActiveAy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          targetingScope = val;
                                          schedules.clear();
                                        });
                                      }
                                    },
                            ),
                            RadioListTile<String>(
                              title: const Text('Specific Classes'),
                              value: 'SPECIFIC_CLASSES',
                              groupValue: targetingScope,
                              onChanged: !hasActiveAy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          targetingScope = val;
                                          schedules.clear();
                                        });
                                      }
                                    },
                            ),
                            RadioListTile<String>(
                              title: const Text('Specific Sections'),
                              value: 'SPECIFIC_SECTIONS',
                              groupValue: targetingScope,
                              onChanged: !hasActiveAy
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          targetingScope = val;
                                          schedules.clear();
                                        });
                                      }
                                    },
                            ),
                            SizedBox(height: spacing.sm),
                            // Show class/section checkboxes if targeting scope is SPECIFIC_CLASSES or SPECIFIC_SECTIONS
                            if (targetingScope == 'SPECIFIC_CLASSES') ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: academicState.classes.map((c) {
                                    final cid = c['id'] as String;
                                    final name = c['name'] as String;
                                    return CheckboxListTile(
                                      title: Text(name),
                                      value: selectedClassIds.contains(cid),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedClassIds.add(cid);
                                          } else {
                                            selectedClassIds.remove(cid);
                                          }
                                          schedules.clear();
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            if (targetingScope == 'SPECIFIC_SECTIONS') ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: academicState.classes.map((cls) {
                                    final cid = cls['id'] as String;
                                    final cname = cls['name'] as String;
                                    final classSecs = academicState.sections.where((sec) => sec['class_id'] == cid).toList();
                                    if (classSecs.isEmpty) return const SizedBox.shrink();
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Text(cname, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        ...classSecs.map((sec) {
                                          final sid = sec['id'] as String;
                                          final sname = sec['name'] as String;
                                          return CheckboxListTile(
                                            title: Text(sname),
                                            value: selectedSectionIds.contains(sid),
                                            onChanged: (val) {
                                              setDialogState(() {
                                                if (val == true) {
                                                  selectedSectionIds.add(sid);
                                                  if (!selectedClassIds.contains(cid)) {
                                                    selectedClassIds.add(cid);
                                                  }
                                                } else {
                                                  selectedSectionIds.remove(sid);
                                                  final anyLeft = classSecs.any((s) => selectedSectionIds.contains(s['id'] as String));
                                                  if (!anyLeft) {
                                                    selectedClassIds.remove(cid);
                                                  }
                                                }
                                                schedules.clear();
                                              });
                                            },
                                          );
                                        }),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            SizedBox(height: spacing.md),
                            // Load suggestions action
                            Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: dialogTheme.colorScheme.primaryContainer,
                                  foregroundColor: dialogTheme.colorScheme.onPrimaryContainer,
                                ),
                                icon: isLoadingSchedules
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome),
                                label: const Text('Auto-Suggest Sequential Schedules'),
                                onPressed: (!hasActiveAy || isLoadingSchedules)
                                    ? null
                                    : () async {
                                        List<String> classesToQuery = [];
                                        if (targetingScope == 'ALL_CLASSES') {
                                          classesToQuery = academicState.classes.map((c) => c['id'] as String).toList();
                                        } else {
                                          classesToQuery = List<String>.from(selectedClassIds);
                                        }

                                        if (targetingScope == 'SPECIFIC_CLASSES' && selectedClassIds.isEmpty) {
                                          setDialogState(() => dialogError = 'Please select at least one class.');
                                          return;
                                        }
                                        if (targetingScope == 'SPECIFIC_SECTIONS' && selectedSectionIds.isEmpty) {
                                          setDialogState(() => dialogError = 'Please select at least one section.');
                                          return;
                                        }
                                        if (classesToQuery.isEmpty) {
                                          setDialogState(() => dialogError = 'No classes available to schedule.');
                                          return;
                                        }

                                        setDialogState(() {
                                          isLoadingSchedules = true;
                                          dialogError = null;
                                        });
                                        try {
                                          final sug = await ref.read(academicStateProvider.notifier).getSuggestedSchedules(
                                            classIds: classesToQuery,
                                            startDate: DateFormat('yyyy-MM-dd').format(startDate),
                                            endDate: DateFormat('yyyy-MM-dd').format(endDate),
                                          );
                                          
                                          // If Specific Sections scope, filter suggestions matching selectedSectionIds
                                          List<Map<String, dynamic>> finalSchedules = sug;
                                          if (targetingScope == 'SPECIFIC_SECTIONS') {
                                            finalSchedules = sug.where((s) => selectedSectionIds.contains(s['section_id'] as String)).toList();
                                          }
                                          
                                          setDialogState(() {
                                            schedules = finalSchedules.map((s) => Map<String, dynamic>.from(s)).toList();
                                            if (schedules.isEmpty) {
                                              dialogError = 'No subject teacher-assignments found for the selected targets.';
                                            }
                                          });
                                        } catch (e) {
                                          setDialogState(() => dialogError = 'Failed to suggest: $e');
                                        } finally {
                                          setDialogState(() => isLoadingSchedules = false);
                                        }
                                      },
                              ),
                            ),
                            SizedBox(height: spacing.md),
                            // Suggested Subject Schedules
                            if (schedules.isNotEmpty) ...[
                              Text('Scheduled Papers', style: dialogTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              SizedBox(height: spacing.xs),
                              ...schedules.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Padding(
                                    padding: EdgeInsets.all(spacing.sm),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item['subject_name'] ?? 'Subject'} (${item['class_name'] ?? 'Class'} - ${item['section_name'] ?? 'Sec'})',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () {
                                                setDialogState(() => schedules.removeAt(idx));
                                              },
                                            ),
                                          ],
                                        ),
                                        const Divider(),
                                        // Edit Form fields
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () async {
                                                  final currentVal = DateTime.parse(item['exam_date'].toString());
                                                  final picked = await showDatePicker(
                                                    context: context,
                                                    initialDate: currentVal,
                                                    firstDate: startDate,
                                                    lastDate: endDate,
                                                  );
                                                  if (picked != null) {
                                                    setDialogState(() {
                                                      item['exam_date'] = DateFormat('yyyy-MM-dd').format(picked);
                                                    });
                                                  }
                                                },
                                                child: InputDecorator(
                                                  decoration: const InputDecoration(labelText: 'Exam Date'),
                                                  child: Text(item['exam_date'] as String),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: spacing.xs),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: item['room_number'] as String? ?? '',
                                                decoration: const InputDecoration(labelText: 'Room No'),
                                                onChanged: (val) => item['room_number'] = val,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: spacing.xs),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () async {
                                                  final currentString = item['start_time'] as String;
                                                  final timeParts = currentString.split(':');
                                                  final picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: TimeOfDay(
                                                      hour: int.parse(timeParts[0]),
                                                      minute: int.parse(timeParts[1]),
                                                    ),
                                                  );
                                                  if (picked != null) {
                                                    setDialogState(() {
                                                      final h = picked.hour.toString().padLeft(2, '0');
                                                      final m = picked.minute.toString().padLeft(2, '0');
                                                      item['start_time'] = '$h:$m:00';
                                                    });
                                                  }
                                                },
                                                child: InputDecorator(
                                                  decoration: const InputDecoration(labelText: 'Start Time'),
                                                  child: Text(item['start_time'] as String),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: spacing.xs),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () async {
                                                  final currentString = item['end_time'] as String;
                                                  final timeParts = currentString.split(':');
                                                  final picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: TimeOfDay(
                                                      hour: int.parse(timeParts[0]),
                                                      minute: int.parse(timeParts[1]),
                                                    ),
                                                  );
                                                  if (picked != null) {
                                                    setDialogState(() {
                                                      final h = picked.hour.toString().padLeft(2, '0');
                                                      final m = picked.minute.toString().padLeft(2, '0');
                                                      item['end_time'] = '$h:$m:00';
                                                    });
                                                  }
                                                },
                                                child: InputDecorator(
                                                  decoration: const InputDecoration(labelText: 'End Time'),
                                                  child: Text(item['end_time'] as String),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: spacing.xs),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: item['max_marks']?.toString() ?? '100',
                                                decoration: const InputDecoration(labelText: 'Max Marks'),
                                                keyboardType: TextInputType.number,
                                                onChanged: (val) => item['max_marks'] = int.tryParse(val) ?? 100,
                                              ),
                                            ),
                                            SizedBox(width: spacing.xs),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: item['pass_marks']?.toString() ?? '35',
                                                decoration: const InputDecoration(labelText: 'Pass Marks'),
                                                keyboardType: TextInputType.number,
                                                onChanged: (val) => item['pass_marks'] = int.tryParse(val) ?? 35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  // Save Draft / Publish Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      SizedBox(width: spacing.xs),
                      ElevatedButton(
                        onPressed: (!hasActiveAy || isSaving)
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  if (endDate.isBefore(startDate)) {
                                    setDialogState(() => dialogError = 'End date cannot be before start date.');
                                    return;
                                  }

                                  if (targetingScope == 'SPECIFIC_CLASSES' && selectedClassIds.isEmpty) {
                                    setDialogState(() => dialogError = 'Please select at least one class.');
                                    return;
                                  }
                                  if (targetingScope == 'SPECIFIC_SECTIONS' && selectedSectionIds.isEmpty) {
                                    setDialogState(() => dialogError = 'Please select at least one section.');
                                    return;
                                  }
                                  
                                  setDialogState(() {
                                    isSaving = true;
                                    dialogError = null;
                                  });

                                  // Extract school ID
                                  final schoolId = await ref.read(sessionManagerProvider).getSchoolId();

                                  // Build payload matching backend ExaminationWizardCreate schema
                                  final payload = {
                                    "school_id": schoolId,
                                    "academic_year_id": ayId,
                                    "exam_name": nameController.text,
                                    "exam_type": selectedType,
                                    "start_date": DateFormat('yyyy-MM-dd').format(startDate),
                                    "end_date": DateFormat('yyyy-MM-dd').format(endDate),
                                    "description": descController.text,
                                    "target_scope": targetingScope,
                                    "class_ids": targetingScope == 'SPECIFIC_CLASSES' ? selectedClassIds : null,
                                    "section_ids": targetingScope == 'SPECIFIC_SECTIONS' ? selectedSectionIds : null,
                                    "schedules": schedules.map((item) => {
                                      "class_id": item['class_id'],
                                      "section_id": item['section_id'],
                                      "subject_id": item['subject_id'],
                                      "teacher_subject_assignment_id": item['teacher_subject_assignment_id'],
                                      "exam_date": item['exam_date'],
                                      "start_time": item['start_time'],
                                      "end_time": item['end_time'],
                                      "max_marks": item['max_marks'] ?? 100,
                                      "pass_marks": item['pass_marks'] ?? 35,
                                      "room_number": item['room_number'] ?? ""
                                    }).toList()
                                  };

                                  final success = await ref.read(academicStateProvider.notifier).createExaminationWizard(
                                    payload: payload,
                                  );

                                  if (success) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Examination and sequential papers scheduled successfully as Draft!')),
                                    );
                                  } else {
                                    setDialogState(() {
                                      isSaving = false;
                                      dialogError = ref.read(academicStateProvider).errorMessage ?? 'Failed to create examination wizard.';
                                    });
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Draft'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(academicStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/planner');
            }
          },
        ),
        title: const Text('Manage Exams'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(academicStateProvider.notifier).fetchExaminations(isRefresh: true),
        child: _buildBody(context, state, spacing, radius, theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExamDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Exam'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AcademicState state, AppSpacing spacing, AppRadius radius, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(spacing.lg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              SizedBox(height: spacing.sm),
              const Text('Failed to load examinations.'),
              Text(state.errorMessage!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              SizedBox(height: spacing.md),
              ElevatedButton(
                onPressed: () => ref.read(academicStateProvider.notifier).fetchExaminations(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.examinations.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 56, color: Colors.grey),
              SizedBox(height: spacing.sm),
              const Text('No examinations registered.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: state.examinations.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) {
        final exam = state.examinations[index];
        final isDraft = exam.status.toUpperCase() == 'DRAFT';
        final statusColor = exam.status.toUpperCase() == 'PUBLISHED'
            ? Colors.green
            : (exam.status.toUpperCase() == 'DRAFT' ? Colors.orange : Colors.grey);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.lg),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exam.examName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(radius.sm),
                      ),
                      child: Text(
                        exam.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text('Type: ${exam.examType}', style: theme.textTheme.bodyMedium),
                Text('Duration: ${exam.startDate} to ${exam.endDate}', style: theme.textTheme.bodyMedium),
                if (exam.description != null && exam.description!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    exam.description!,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (isDraft) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Publish'),
                              content: const Text('Are you sure you want to publish this examination? This will make the schedule visible to students and parents.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Publish'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final success = await ref
                                .read(academicStateProvider.notifier)
                                .publishExamination(exam.id);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Exam published successfully!')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to publish exam.')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.publish_rounded, size: 16),
                        label: const Text('Publish Exam'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
