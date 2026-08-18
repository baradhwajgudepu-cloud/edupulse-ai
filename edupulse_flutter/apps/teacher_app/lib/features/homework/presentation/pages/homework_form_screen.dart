import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_localization/edupulse_localization.dart';

import '../../../../core/router/routes.dart';
import '../../domain/entities/homework_entity.dart';
import '../providers/homework_provider.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/teacher_class_group.dart';

class HomeworkFormScreen extends ConsumerStatefulWidget {
  final String? homeworkId;
  final String? timetableId;
  final String? teacherSubjectAssignmentId;
  final String? subjectId;
  final String? classId;
  final String? sectionId;

  const HomeworkFormScreen({
    super.key,
    this.homeworkId,
    this.timetableId,
    this.teacherSubjectAssignmentId,
    this.subjectId,
    this.classId,
    this.sectionId,
  });

  @override
  ConsumerState<HomeworkFormScreen> createState() => _HomeworkFormScreenState();
}

class _HomeworkFormScreenState extends ConsumerState<HomeworkFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _estimatedMinutesController;
  late final TextEditingController _attachmentUrlController;

  DateTime? _selectedDueDate;
  HomeworkPriority _selectedPriority = HomeworkPriority.NORMAL;
  HomeworkStatus _selectedStatus = HomeworkStatus.DRAFT;

  String? _selectedClassSectionKey; // format: 'classId:sectionId'
  String? _selectedSubjectId;
  String? _selectedTsaId;

  bool _isEditMode = false;
  bool _isLoadingEditData = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _estimatedMinutesController = TextEditingController();
    _attachmentUrlController = TextEditingController();

    _isEditMode = widget.homeworkId != null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure my classes list is loaded
      await ref.read(myClassesStateProvider.notifier).fetchClasses();

      if (_isEditMode) {
        _loadExistingHomeworkDetails();
      } else {
        _prefillNewFormDetails();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedMinutesController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  void _prefillNewFormDetails() {
    if (widget.classId != null && widget.sectionId != null) {
      setState(() {
        _selectedClassSectionKey = '${widget.classId}:${widget.sectionId}';
        _selectedSubjectId = widget.subjectId;
        _selectedTsaId = widget.teacherSubjectAssignmentId;
      });
    }
  }

  Future<void> _loadExistingHomeworkDetails() async {
    setState(() {
      _isLoadingEditData = true;
    });

    final detailsNotifier = ref.read(homeworkDetailProvider(widget.homeworkId!).notifier);
    await detailsNotifier.fetchDetails();

    final detailsState = ref.read(homeworkDetailProvider(widget.homeworkId!));
    if (detailsState is HomeworkDetailSuccess) {
      final hw = detailsState.homework;
      setState(() {
        _titleController.text = hw.title;
        _descriptionController.text = hw.description;
        _estimatedMinutesController.text = hw.estimatedMinutes?.toString() ?? '';
        _attachmentUrlController.text = hw.attachmentUrl ?? '';
        _selectedDueDate = hw.dueDate;
        _selectedPriority = hw.priority;
        _selectedStatus = hw.status;
        _selectedClassSectionKey = '${hw.classId}:${hw.sectionId}';
        _selectedSubjectId = hw.subjectId;
        _selectedTsaId = hw.teacherSubjectAssignmentId;
        _isLoadingEditData = false;
      });
    } else {
      setState(() {
        _isLoadingEditData = false;
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _selectedDueDate != null && _selectedDueDate!.isAfter(now)
        ? _selectedDueDate!
        : now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now, // Must not be in past
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _submit(HomeworkStatus statusToSave) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date.')),
      );
      return;
    }

    final formNotifier = ref.read(homeworkFormNotifierProvider.notifier);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final estimatedMinutes = int.tryParse(_estimatedMinutesController.text.trim());
    final attachmentUrl = _attachmentUrlController.text.trim();

    bool success = false;

    if (_isEditMode) {
      success = await formNotifier.updateHomework(
        id: widget.homeworkId!,
        title: title,
        description: description,
        dueDate: _selectedDueDate,
        priority: _selectedPriority,
        status: statusToSave,
        estimatedMinutes: estimatedMinutes,
        attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
      );
    } else {
      if (widget.timetableId != null) {
        success = await formNotifier.createFromTimetable(
          timetableId: widget.timetableId!,
          title: title,
          description: description,
          dueDate: _selectedDueDate!,
          priority: _selectedPriority,
          status: statusToSave,
          estimatedMinutes: estimatedMinutes,
          attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
        );
      } else {
        if (_selectedTsaId == null || _selectedSubjectId == null || _selectedClassSectionKey == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a class and subject.')),
          );
          return;
        }

        final classParts = _selectedClassSectionKey!.split(':');
        success = await formNotifier.createHomework(
          title: title,
          description: description,
          dueDate: _selectedDueDate!,
          priority: _selectedPriority,
          status: statusToSave,
          teacherSubjectAssignmentId: _selectedTsaId!,
          subjectId: _selectedSubjectId!,
          classId: classParts[0],
          sectionId: classParts[1],
          estimatedMinutes: estimatedMinutes,
          attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
        );
      }
    }

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Homework updated!' : 'Homework created!')),
      );
      context.pop(true); // Return true to refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final local = EduLocalization.of(context);

    final formState = ref.watch(homeworkFormNotifierProvider);
    final classesState = ref.watch(myClassesStateProvider);

    // Watch templates if subject is selected
    final templatesAsync = ref.watch(homeworkTemplatesProvider(_selectedSubjectId));

    final isFormLocked = formState is HomeworkFormSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Homework' : 'Create Homework'),
        elevation: 0,
      ),
      body: _isLoadingEditData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(spacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formState is HomeworkFormError) ...[
                      Container(
                        padding: EdgeInsets.all(spacing.md),
                        margin: EdgeInsets.only(bottom: spacing.md),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(radius.sm),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          formState.message,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    // Class Dropdown
                    Text('Select Class & Section', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    _buildClassDropdown(classesState, isFormLocked || _isEditMode || widget.timetableId != null),
                    SizedBox(height: spacing.lg),

                    // Subject Dropdown
                    Text('Select Subject', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    _buildSubjectDropdown(classesState, isFormLocked || _isEditMode || widget.timetableId != null),
                    SizedBox(height: spacing.lg),

                    // Title
                    Text('Homework Title', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _titleController,
                      enabled: !isFormLocked,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        hintText: 'Enter title (e.g. Algebra Chapter 2 Worksheet)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        if (value.length > 200) {
                          return 'Title must be less than 200 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.md),

                    // Description
                    Text('Description / Instructions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !isFormLocked,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Provide task instructions here...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.sm),

                    // Template Chips
                    if (_selectedSubjectId != null) ...[
                      _buildTemplatesSection(templatesAsync, spacing, radius, theme),
                      SizedBox(height: spacing.lg),
                    ],

                    // Due Date
                    Text('Due Date', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    InkWell(
                      onTap: isFormLocked ? null : () => _selectDueDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(radius.xs),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDueDate == null
                                  ? 'Select due date'
                                  : DateFormat('EEEE, dd MMMM yyyy').format(_selectedDueDate!),
                              style: TextStyle(
                                color: _selectedDueDate == null ? theme.colorScheme.onSurfaceVariant : null,
                              ),
                            ),
                            Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Priority
                    Text('Priority', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: HomeworkPriority.values.map((p) {
                        return Padding(
                          padding: EdgeInsets.only(right: spacing.md),
                          child: ChoiceChip(
                            label: Text(p.name),
                            selected: _selectedPriority == p,
                            onSelected: isFormLocked
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedPriority = p;
                                      });
                                    }
                                  },
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: spacing.lg),

                    // Estimated Minutes
                    Text('Estimated effort minutes (Optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _estimatedMinutesController,
                      enabled: !isFormLocked,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 45',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed < 0) {
                            return 'Must be a valid positive number';
                          }
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.lg),

                    // Attachment Url
                    Text('Attachment URL (Optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _attachmentUrlController,
                      enabled: !isFormLocked,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'e.g. https://drive.google.com/your-worksheet-link',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: spacing.xl),

                    // Form Action Buttons
                    if (isFormLocked)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _submit(HomeworkStatus.DRAFT),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: spacing.md),
                              ),
                              child: const Text('Save as Draft'),
                            ),
                          ),
                          SizedBox(width: spacing.md),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _submit(HomeworkStatus.PUBLISHED),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: spacing.md),
                              ),
                              child: const Text('Publish'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildClassDropdown(MyClassesState state, bool isDisabled) {
    List<TeacherClassGroupEntity> groups = [];
    if (state is MyClassesSuccess) {
      groups = state.classes;
    } else if (state is MyClassesRefreshing) {
      groups = state.classes;
    }

    return DropdownButtonFormField<String>(
      value: _selectedClassSectionKey,
      disabledHint: _selectedClassSectionKey != null
          ? Text(
              groups
                  .firstWhere(
                    (g) => '${g.classId}:${g.sectionId}' == _selectedClassSectionKey,
                    orElse: () => TeacherClassGroupEntity(
                      classId: '',
                      className: 'Loading Class...',
                      sectionId: '',
                      sectionName: '',
                      assignments: const [],
                    ),
                  )
                  .className,
            )
          : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Choose Class & Section',
      ),
      items: isDisabled
          ? null
          : groups.map((g) {
              return DropdownMenuItem<String>(
                value: '${g.classId}:${g.sectionId}',
                child: Text('${g.className} - ${g.sectionName}'),
              );
            }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedClassSectionKey = val;
          _selectedSubjectId = null;
          _selectedTsaId = null;
        });
      },
      validator: (value) => value == null ? 'Class selection is required' : null,
    );
  }

  Widget _buildSubjectDropdown(MyClassesState state, bool isDisabled) {
    List<TeacherClassGroupEntity> groups = [];
    if (state is MyClassesSuccess) {
      groups = state.classes;
    } else if (state is MyClassesRefreshing) {
      groups = state.classes;
    }

    // Filter assignments by selected class key
    List<TeacherSubjectAssignmentEntity> asgs = [];
    if (_selectedClassSectionKey != null) {
      final match = groups.firstWhere(
        (g) => '${g.classId}:${g.sectionId}' == _selectedClassSectionKey,
        orElse: () => TeacherClassGroupEntity(
          classId: '',
          className: '',
          sectionId: '',
          sectionName: '',
          assignments: const [],
        ),
      );
      asgs = match.assignments;
    }

    return DropdownButtonFormField<String>(
      value: _selectedSubjectId,
      disabledHint: _selectedSubjectId != null
          ? Text(
              asgs
                  .firstWhere(
                    (a) => a.subjectId == _selectedSubjectId,
                    orElse: () => TeacherSubjectAssignmentEntity(
                      id: '',
                      subjectId: '',
                      subjectName: 'Loading Subject...',
                      subjectCode: '',
                      displayColor: null,
                      isClassTeacher: false,
                    ),
                  )
                  .subjectName,
            )
          : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Choose Subject',
      ),
      items: isDisabled || _selectedClassSectionKey == null
          ? null
          : asgs.map((a) {
              return DropdownMenuItem<String>(
                value: a.subjectId,
                child: Text(a.subjectName),
              );
            }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedSubjectId = val;
          if (val != null) {
            final match = asgs.firstWhere((a) => a.subjectId == val);
            _selectedTsaId = match.id;
          } else {
            _selectedTsaId = null;
          }
        });
      },
      validator: (value) => value == null ? 'Subject selection is required' : null,
    );
  }

  Widget _buildTemplatesSection(
    AsyncValue<List<String>> asyncTemplates,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    return asyncTemplates.when(
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggestions',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.xs),
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: templates.map((t) {
                return ActionChip(
                  label: Text(t),
                  onPressed: () {
                    final curr = _descriptionController.text;
                    if (curr.isEmpty) {
                      _descriptionController.text = '$t: ';
                    } else {
                      _descriptionController.text = '$curr\n$t: ';
                    }
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
