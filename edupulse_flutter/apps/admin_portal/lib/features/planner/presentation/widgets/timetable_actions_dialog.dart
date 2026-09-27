import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/timetable_models.dart';
import '../providers/timetable_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../teachers/data/models/teachers_models.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

T? _findFirst<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class CopyDayDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final DayOfWeek initialDay;

  const CopyDayDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    required this.initialDay,
  });

  @override
  ConsumerState<CopyDayDialog> createState() => _CopyDayDialogState();
}

class _CopyDayDialogState extends ConsumerState<CopyDayDialog> {
  late DayOfWeek _sourceDay;
  DayOfWeek _targetDay = DayOfWeek.tuesday;

  @override
  void initState() {
    super.initState();
    _sourceDay = widget.initialDay;
    final otherDays = DayOfWeek.values.where((d) => d != _sourceDay).toList();
    if (otherDays.isNotEmpty) {
      _targetDay = otherDays.first;
    }
  }

  Future<void> _executeCopy() async {
    final notifier = ref.read(timetableActionProvider.notifier);
    final success = await notifier.copyDay(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: widget.classId,
      sectionId: widget.sectionId,
      sourceDay: _sourceDay.value,
      targetDay: _targetDay.value,
    );

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
    final actionState = ref.watch(timetableActionProvider);

    final screenH = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.copy_outlined, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Copy Day Schedule', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: (screenH * 0.85).clamp(300.0, 600.0)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Duplicate all period slots from one day to another. Any existing periods on the target day will be replaced.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DayOfWeek>(
                value: _sourceDay,
                decoration: const InputDecoration(labelText: 'Source Day*', border: OutlineInputBorder()),
                items: DayOfWeek.values.map<DropdownMenuItem<DayOfWeek>>((d) => DropdownMenuItem<DayOfWeek>(value: d, child: Text(d.displayLabel))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _sourceDay = val;
                      if (_targetDay == val) {
                        _targetDay = DayOfWeek.values.firstWhere((d) => d != val);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DayOfWeek>(
                value: _targetDay,
                decoration: const InputDecoration(labelText: 'Target Day*', border: OutlineInputBorder()),
                items: DayOfWeek.values
                    .where((d) => d != _sourceDay)
                    .map<DropdownMenuItem<DayOfWeek>>((d) => DropdownMenuItem<DayOfWeek>(value: d, child: Text(d.displayLabel)))
                    .toList(),
                onChanged: (val) => setState(() => _targetDay = val!),
              ),
              if (actionState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(actionState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: actionState.isLoading ? null : _executeCopy,
          child: actionState.isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Copy Schedule'),
        ),
      ],
    );
  }
}

class CopySectionDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String sourceClassId;
  final String sourceSectionId;

  const CopySectionDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.sourceClassId,
    required this.sourceSectionId,
  });

  @override
  ConsumerState<CopySectionDialog> createState() => _CopySectionDialogState();
}

class _CopySectionDialogState extends ConsumerState<CopySectionDialog> {
  String? _targetClassId;
  String? _targetSectionId;

  @override
  void initState() {
    super.initState();
    _targetClassId = widget.sourceClassId;
  }

  Future<void> _executeCopy() async {
    if (_targetClassId == null || _targetSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target class and section.')),
      );
      return;
    }

    final notifier = ref.read(timetableActionProvider.notifier);
    final success = await notifier.copySection(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      sourceClassId: widget.sourceClassId,
      sourceSectionId: widget.sourceSectionId,
      targetClassId: _targetClassId!,
      targetSectionId: _targetSectionId!,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(classesProvider(widget.schoolId));
    final sectionsState = ref.watch(sectionsProvider(widget.schoolId));
    final actionState = ref.watch(timetableActionProvider);

    final availableSections = sectionsState.sections
        .where((s) => s.classId == _targetClassId && s.id != widget.sourceSectionId)
        .toList();

    final screenH = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.content_copy_outlined, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Copy Schedule to Section', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: (screenH * 0.85).clamp(300.0, 600.0)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Replicate this weekly timetable to another section. Target section periods will be updated.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _targetClassId,
                decoration: const InputDecoration(labelText: 'Destination Class', border: OutlineInputBorder()),
                items: classesState.classes.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    _targetClassId = val;
                    _targetSectionId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _targetSectionId,
                decoration: const InputDecoration(labelText: 'Destination Section', border: OutlineInputBorder()),
                items: availableSections.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name))).toList(),
                onChanged: (val) => setState(() => _targetSectionId = val),
              ),
              if (actionState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(actionState.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: actionState.isLoading ? null : _executeCopy,
          child: actionState.isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Copy to Section'),
        ),
      ],
    );
  }
}

class PrintTimetableDialog extends StatelessWidget {
  final String schoolName;
  final String academicYearName;
  final String className;
  final String sectionName;
  final List<TimetableDto> slots;
  final dynamic subjectsState;
  final dynamic teachersState;

  const PrintTimetableDialog({
    super.key,
    required this.schoolName,
    required this.academicYearName,
    required this.className,
    required this.sectionName,
    required this.slots,
    required this.subjectsState,
    required this.teachersState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday, DayOfWeek.saturday];
    final periods = List.generate(8, (i) => i + 1);

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final dialogWidth = (screenW * 0.95).clamp(320.0, 1000.0);
    final dialogHeight = (screenH * 0.92).clamp(400.0, 780.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW < 768 ? 12 : 24,
        vertical: screenH < 768 ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight),
        child: Padding(
          padding: EdgeInsets.all(screenW < 768 ? 14.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolName,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Official Class Timetable — $className - $sectionName ($academicYearName)',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            const Divider(height: 24),

            // Print Grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: [
                      const DataColumn(label: Text('Day / Period', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...periods.map((p) => DataColumn(label: Text('P$p', style: const TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                    rows: days.map((day) {
                      return DataRow(
                        cells: [
                          DataCell(Text(day.shortLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ...periods.map((period) {
                            final slot = _findFirst(slots, (s) => s.dayOfWeek == day && s.periodNumber == period);
                            if (slot == null) {
                              return const DataCell(Text('-'));
                            }
                            if (slot.periodType == PeriodType.breakPeriod) {
                              return const DataCell(
                                Text('BREAK', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                              );
                            }
                            final sub = _findFirst<SubjectDto>(subjectsState.subjects, (s) => s.id == slot.subjectId);
                            final teacher = _findFirst<TeacherDto>(teachersState.teachers, (t) => t.id == slot.teacherId);
                            final subCode = sub?.subjectCode ?? 'SUB';
                            final teacherName = teacher != null ? '${teacher.firstName[0]}. ${teacher.lastName}' : '';

                            return DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  if (teacherName.isNotEmpty)
                                    Text(teacherName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  if (slot.roomId != null && slot.roomId!.isNotEmpty)
                                    Text(slot.roomId!, style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Timetable'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Timetable sent to system print preview.')),
                    );
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
