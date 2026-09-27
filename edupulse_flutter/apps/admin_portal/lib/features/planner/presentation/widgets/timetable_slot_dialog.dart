import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/timetable_models.dart';
import '../providers/timetable_providers.dart';
import '../../../teachers/data/models/teachers_models.dart';
import '../../../teachers/presentation/providers/teachers_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

T? _findFirst<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class TimetableSlotDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final TimetableDto? slot; // Null for create, non-null for edit
  final DayOfWeek? defaultDay;
  final int? defaultPeriodNumber;

  const TimetableSlotDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    this.slot,
    this.defaultDay,
    this.defaultPeriodNumber,
  });

  @override
  ConsumerState<TimetableSlotDialog> createState() => _TimetableSlotDialogState();
}

class _TimetableSlotDialogState extends ConsumerState<TimetableSlotDialog> {
  final _formKey = GlobalKey<FormState>();

  late DayOfWeek _selectedDay;
  late int _periodNumber;
  late PeriodType _selectedPeriodType;
  
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 15);
  
  String? _selectedAssignmentId;
  final _roomController = TextEditingController();

  String? _conflictWarning;
  bool _isCheckingConflict = false;

  bool get _isEdit => widget.slot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.slot;
    _selectedDay = s?.dayOfWeek ?? widget.defaultDay ?? DayOfWeek.monday;
    _periodNumber = s?.periodNumber ?? widget.defaultPeriodNumber ?? 1;
    _selectedPeriodType = s?.periodType ?? PeriodType.regular;
    _selectedAssignmentId = s?.teacherSubjectAssignmentId;
    _roomController.text = s?.roomId ?? '';

    if (s != null) {
      _startTime = _parseTimeOfDay(s.startTime);
      _endTime = _parseTimeOfDay(s.endTime);
    } else {
      // Default period time according to period number
      final startHour = 8 + (_periodNumber - 1);
      _startTime = TimeOfDay(hour: startHour, minute: 30);
      _endTime = TimeOfDay(hour: startHour + 1, minute: 15);
    }

    Future.microtask(() {
      ref.read(teachersListProvider.notifier).fetchTeachers();
      ref.read(subjectsProvider(widget.schoolId).notifier).fetchSubjects(academicYearId: widget.academicYearId);
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 30);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _validateConflict();
    }
  }

  Future<void> _validateConflict() async {
    final startTimeMin = _startTime.hour * 60 + _startTime.minute;
    final endTimeMin = _endTime.hour * 60 + _endTime.minute;
    if (startTimeMin >= endTimeMin) {
      setState(() => _conflictWarning = 'Start time must be strictly before end time.');
      return;
    }

    setState(() {
      _isCheckingConflict = true;
      _conflictWarning = null;
    });

    final actionNotifier = ref.read(timetableActionProvider.notifier);
    final conflict = await actionNotifier.checkConflict({
      'school_id': widget.schoolId,
      'academic_year_id': widget.academicYearId,
      'class_id': widget.classId,
      'section_id': widget.sectionId,
      'day_of_week': _selectedDay.value,
      'period_number': _periodNumber,
      'start_time': _formatTimeOfDay(_startTime),
      'end_time': _formatTimeOfDay(_endTime),
      'exclude_timetable_id': widget.slot?.id,
    });

    if (mounted) {
      setState(() {
        _isCheckingConflict = false;
        if (conflict.hasConflict) {
          _conflictWarning = conflict.conflictMessage ?? 'A schedule conflict exists for this time slot.';
        }
      });
    }
  }

  Future<void> _submit(List<TeacherSubjectAssignmentDto> assignments) async {
    if (!_formKey.currentState!.validate()) return;

    final startTimeMin = _startTime.hour * 60 + _startTime.minute;
    final endTimeMin = _endTime.hour * 60 + _endTime.minute;
    if (startTimeMin >= endTimeMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be earlier than end time.')),
      );
      return;
    }

    if (_selectedPeriodType != PeriodType.breakPeriod && _selectedAssignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Teacher-Subject assignment for regular periods.')),
      );
      return;
    }

    final data = <String, dynamic>{
      'school_id': widget.schoolId,
      'academic_year_id': widget.academicYearId,
      'class_id': widget.classId,
      'section_id': widget.sectionId,
      'day_of_week': _selectedDay.value,
      'period_number': _periodNumber,
      'start_time': _formatTimeOfDay(_startTime),
      'end_time': _formatTimeOfDay(_endTime),
      'period_type': _selectedPeriodType.value,
      'room_id': _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
      'teacher_subject_assignment_id': _selectedPeriodType == PeriodType.breakPeriod ? null : _selectedAssignmentId,
      'is_available': true,
      'status': 'ACTIVE',
    };

    final notifier = ref.read(timetableActionProvider.notifier);
    bool success;
    if (_isEdit) {
      success = await notifier.updateSlot(widget.slot!.id, widget.schoolId, data);
    } else {
      success = await notifier.createSlot(data);
    }

    if (success && mounted) {
      ref.invalidate(sectionTimetableProvider((
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        classId: widget.classId,
        sectionId: widget.sectionId,
      )));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final actionState = ref.watch(timetableActionProvider);
    final subjectsState = ref.watch(subjectsProvider(widget.schoolId));
    final teachersState = ref.watch(teachersListProvider);

    // Watch all assignments matching this class and section
    final assignmentsAsync = ref.watch(allTeacherAssignmentsProvider((
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: widget.classId,
      sectionId: widget.sectionId,
      teacherId: null,
      subjectId: null,
      status: 'ACTIVE',
      search: null,
    )));

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: (screenW * 0.05).clamp(16.0, 40.0),
        vertical: (screenH * 0.04).clamp(16.0, 32.0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: (screenH * 0.92).clamp(420.0, 780.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Timetable Period' : 'Schedule Timetable Slot',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      // Day and Period Slot
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DayOfWeek>(
                              value: _selectedDay,
                              decoration: const InputDecoration(
                                labelText: 'Day of Week*',
                                border: OutlineInputBorder(),
                              ),
                              items: DayOfWeek.values.map((d) {
                                return DropdownMenuItem(value: d, child: Text(d.displayLabel));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDay = val);
                                  _validateConflict();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _periodNumber,
                              decoration: const InputDecoration(
                                labelText: 'Period Number*',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(8, (i) => i + 1).map((p) {
                                return DropdownMenuItem(value: p, child: Text('Period $p'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _periodNumber = val);
                                  _validateConflict();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Period Type
                      DropdownButtonFormField<PeriodType>(
                        value: _selectedPeriodType,
                        decoration: const InputDecoration(
                          labelText: 'Period Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: PeriodType.values.map((pt) {
                          return DropdownMenuItem(
                            value: pt,
                            child: Row(
                              children: [
                                Icon(pt.icon, size: 18, color: pt.color),
                                const SizedBox(width: 8),
                                Text(pt.displayLabel),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPeriodType = val;
                              if (val == PeriodType.breakPeriod) {
                                _selectedAssignmentId = null;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Subject & Teacher Assignment (if not BREAK)
                      if (_selectedPeriodType != PeriodType.breakPeriod) ...[
                        assignmentsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading assignments: $e', style: const TextStyle(color: Colors.red)),
                          data: (assignments) {
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedAssignmentId,
                              decoration: const InputDecoration(
                                labelText: 'Subject & Assigned Teacher *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final a in assignments) ...[
                                  () {
                                    final sub = _findFirst(subjectsState.subjects, (s) => s.id == a.subjectId);
                                    final teacher = _findFirst(teachersState.teachers, (t) => t.id == a.teacherId);
                                    final schoolBadge = (sub?.isSchoolAdded ?? false) ? ' [School Added]' : '';
                                    final label = '${sub?.subjectName ?? "Subject"}$schoolBadge — ${teacher != null ? "${teacher.firstName} ${teacher.lastName}" : "Teacher"} (${a.weeklyPeriods} periods/wk)';
                                    return DropdownMenuItem<String>(value: a.id, child: Text(label));
                                  }(),
                                ],
                              ],
                              onChanged: (val) => setState(() => _selectedAssignmentId = val),
                              validator: (v) => _selectedPeriodType != PeriodType.breakPeriod && v == null ? 'Required' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Time *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(_startTime.format(context)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Time *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(_endTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Room / Classroom
                      TextFormField(
                        controller: _roomController,
                        decoration: const InputDecoration(
                          labelText: 'Classroom / Lab / Venue',
                          hintText: 'e.g. Room 102, Physics Lab',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Conflict Alert
                      if (_isCheckingConflict)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Validating schedule conflicts...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      else if (_conflictWarning != null)
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _conflictWarning!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (actionState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            actionState.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _submit(assignmentsAsync.valueOrNull ?? []),
                    child: actionState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save Changes' : 'Add Period'),
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
}
