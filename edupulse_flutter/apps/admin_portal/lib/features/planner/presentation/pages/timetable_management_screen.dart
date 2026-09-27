import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/timetable_models.dart';
import '../providers/timetable_providers.dart';
import '../widgets/timetable_slot_dialog.dart';
import '../widgets/timetable_actions_dialog.dart';
import '../widgets/timetable_ai_dialog.dart';
import '../widgets/timetable_capacity_card.dart';
import '../widgets/working_hours_dialog.dart';
import '../providers/working_hours_providers.dart';
import '../../../teachers/presentation/providers/teachers_providers.dart';
import '../../../teachers/data/models/teachers_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

enum TimetableViewMode { section, teacher, room }
enum TimetableLayoutMode { weeklyGrid, dailyTimeline }

T? _findFirst<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class TimetableManagementScreen extends ConsumerStatefulWidget {
  final String? initialTeacherId;
  final String? initialClassId;
  final String? initialSectionId;

  const TimetableManagementScreen({
    super.key,
    this.initialTeacherId,
    this.initialClassId,
    this.initialSectionId,
  });

  @override
  ConsumerState<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends ConsumerState<TimetableManagementScreen> {
  TimetableViewMode _viewMode = TimetableViewMode.section;
  TimetableLayoutMode _layoutMode = TimetableLayoutMode.weeklyGrid;

  String? _selectedAyId;
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedTeacherId;
  DayOfWeek _selectedDailyDay = DayOfWeek.monday;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    _selectedSectionId = widget.initialSectionId;
    _selectedTeacherId = widget.initialTeacherId;

    if (_selectedTeacherId != null) {
      _viewMode = TimetableViewMode.teacher;
    }

    _loadData();
  }

  void _loadData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
        ref.read(teachersListProvider.notifier).fetchTeachers();
      }
    });
  }

  Future<void> _openSlotDialog({
    TimetableDto? slot,
    DayOfWeek? defaultDay,
    int? defaultPeriodNumber,
  }) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedAyId == null || _selectedClassId == null || _selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Academic Year, Class, and Section first.')),
      );
      return;
    }

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TimetableSlotDialog(
        schoolId: schoolId,
        academicYearId: _selectedAyId!,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId!,
        slot: slot,
        defaultDay: defaultDay,
        defaultPeriodNumber: defaultPeriodNumber,
      ),
    );

    if (res == true && mounted) {
      _refreshSchedule();
    }
  }

  Future<void> _deleteSlot(TimetableDto slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Timetable Slot?'),
        content: Text('Are you sure you want to remove Period ${slot.periodNumber} on ${slot.dayOfWeek.displayLabel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId == null) return;

      final success = await ref.read(timetableActionProvider.notifier).deleteSlot(slot.id, schoolId);
      if (success && mounted) {
        _refreshSchedule();
      }
    }
  }

  Future<void> _clearDaySchedule() async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedAyId == null || _selectedClassId == null || _selectedSectionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep, color: Colors.red),
            const SizedBox(width: 8),
            Text('Clear ${_selectedDailyDay.displayLabel} Schedule?'),
          ],
        ),
        content: Text('This will archive all periods scheduled for ${_selectedDailyDay.displayLabel}. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Day'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(timetableActionProvider.notifier).clearDay(
        schoolId: schoolId,
        academicYearId: _selectedAyId!,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId!,
        dayOfWeek: _selectedDailyDay.value,
      );

      if (success && mounted) {
        _refreshSchedule();
      }
    }
  }

  Future<void> _togglePublishStatus(bool currentlyPublished) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedAyId == null || _selectedClassId == null || _selectedSectionId == null) return;

    final nextStatus = currentlyPublished ? 'INACTIVE' : 'ACTIVE';
    final success = await ref.read(timetableActionProvider.notifier).bulkUpdateStatus(
      schoolId: schoolId,
      academicYearId: _selectedAyId!,
      classId: _selectedClassId!,
      sectionId: _selectedSectionId!,
      status: nextStatus,
    );

    if (success && mounted) {
      _refreshSchedule();
    }
  }

  Future<void> _handleSlotDrop({
    required TimetableDto sourceSlot,
    required DayOfWeek targetDay,
    required int targetPeriod,
  }) async {
    if (sourceSlot.dayOfWeek == targetDay && sourceSlot.periodNumber == targetPeriod) {
      return;
    }

    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedAyId == null) return;

    final success = await ref.read(timetableActionProvider.notifier).moveSlot(
      sourceId: sourceSlot.id,
      targetDayOfWeek: targetDay,
      targetPeriodNumber: targetPeriod,
      schoolId: schoolId,
      academicYearId: _selectedAyId!,
    );

    if (!mounted) return;

    final actionState = ref.read(timetableActionProvider);
    if (!success) {
      final conflictMsg = actionState.errorMessage ?? 'Cannot move period due to a scheduling conflict.';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Scheduling Conflict'),
            ],
          ),
          content: Text(conflictMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      if (actionState.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(actionState.successMessage!),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _refreshSchedule();
    }
  }

  void _refreshSchedule() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedAyId == null) return;

    if (_viewMode == TimetableViewMode.section && _selectedClassId != null && _selectedSectionId != null) {
      ref.invalidate(sectionTimetableProvider((
        schoolId: schoolId,
        academicYearId: _selectedAyId!,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId!,
      )));
      ref.invalidate(timetableCapacityProvider((
        schoolId: schoolId,
        academicYearId: _selectedAyId!,
        classId: _selectedClassId,
        sectionId: _selectedSectionId,
      )));
    } else if (_viewMode == TimetableViewMode.teacher && _selectedTeacherId != null) {
      ref.invalidate(teacherTimetableProvider((
        schoolId: schoolId,
        academicYearId: _selectedAyId!,
        teacherId: _selectedTeacherId!,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
      if (next != null) {
        setState(() {
          _selectedAyId = null;
          _selectedClassId = null;
          _selectedSectionId = null;
          _selectedTeacherId = null;
        });
        _loadData();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timetable Management')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top bar selector to manage timetables.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));
    final subjectsState = ref.watch(subjectsProvider(schoolId));
    final teachersState = ref.watch(teachersListProvider);

    // Default to current academic year
    if (ayState.years.isNotEmpty && _selectedAyId == null) {
      final current = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      _selectedAyId = current.id;
    }

    // Default class and section if available
    if (classesState.classes.isNotEmpty && _selectedClassId == null) {
      _selectedClassId = classesState.classes.first.id;
    }
    final availableSections = _selectedClassId == null
        ? sectionsState.sections
        : sectionsState.sections.where((s) => s.classId == _selectedClassId).toList();
    if (availableSections.isNotEmpty && _selectedSectionId == null) {
      _selectedSectionId = availableSections.first.id;
    }

    // Load slots based on view mode
    AsyncValue<List<TimetableDto>> slotsAsync = const AsyncValue.data([]);
    if (_selectedAyId != null) {
      if (_viewMode == TimetableViewMode.section && _selectedClassId != null && _selectedSectionId != null) {
        slotsAsync = ref.watch(sectionTimetableProvider((
          schoolId: schoolId,
          academicYearId: _selectedAyId!,
          classId: _selectedClassId!,
          sectionId: _selectedSectionId!,
        )));
      } else if (_viewMode == TimetableViewMode.teacher && _selectedTeacherId != null) {
        slotsAsync = ref.watch(teacherTimetableProvider((
          schoolId: schoolId,
          academicYearId: _selectedAyId!,
          teacherId: _selectedTeacherId!,
        )));
      }
    }

    final slots = slotsAsync.valueOrNull ?? [];
    final hasSlots = slots.isNotEmpty;
    final isPublished = hasSlots && slots.any((s) => s.status == 'ACTIVE');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Timetable Management'),
            Text('Schedule and conflict detection for classes, teachers, and rooms', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshSchedule,
          ),
          if (_viewMode == TimetableViewMode.section && _selectedClassId != null && _selectedSectionId != null) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Copy Day'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => CopyDayDialog(
                    schoolId: schoolId,
                    academicYearId: _selectedAyId!,
                    classId: _selectedClassId!,
                    sectionId: _selectedSectionId!,
                    initialDay: _selectedDailyDay,
                  ),
                ).then((_) => _refreshSchedule());
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Copy Section'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => CopySectionDialog(
                    schoolId: schoolId,
                    academicYearId: _selectedAyId!,
                    sourceClassId: _selectedClassId!,
                    sourceSectionId: _selectedSectionId!,
                  ),
                ).then((_) => _refreshSchedule());
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Clear Day Schedule',
              onPressed: _clearDaySchedule,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPublished ? Colors.orange.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              icon: Icon(isPublished ? Icons.unpublished_outlined : Icons.publish_outlined, size: 18),
              label: Text(isPublished ? 'Unpublish' : 'Publish'),
              onPressed: hasSlots ? () => _togglePublishStatus(isPublished) : null,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              key: const Key('add_period_slot_button'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Slot'),
              onPressed: () => _openSlotDialog(),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('ai_timetable_assistant_button'),
              tooltip: 'AI Timetable Assistant',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF0F766E),
              ),
              icon: const Icon(Icons.auto_awesome, size: 20),
              onPressed: () {
                final cls = _findFirst(classesState.classes, (c) => c.id == _selectedClassId);
                final sec = _findFirst(sectionsState.sections, (s) => s.id == _selectedSectionId);
                if (cls == null || sec == null || _selectedAyId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select Class and Section first.')),
                  );
                  return;
                }
                showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => TimetableAIDialog(
                    schoolId: schoolId,
                    academicYearId: _selectedAyId!,
                    classId: _selectedClassId!,
                    sectionId: _selectedSectionId!,
                    className: cls.name,
                    sectionName: sec.name,
                  ),
                ).then((published) {
                  if (published == true) {
                    _refreshSchedule();
                  }
                });
              },
            ),
          ],
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print / Export'),
            onPressed: () {
              final ay = _findFirst(ayState.years, (y) => y.id == _selectedAyId)?.name ?? '';
              final cls = _findFirst(classesState.classes, (c) => c.id == _selectedClassId)?.name ?? '';
              final sec = _findFirst(sectionsState.sections, (s) => s.id == _selectedSectionId)?.name ?? '';

              showDialog(
                context: context,
                builder: (ctx) => PrintTimetableDialog(
                  schoolName: 'EduPulse Academy',
                  academicYearName: ay,
                  className: cls,
                  sectionName: sec,
                  slots: slots,
                  subjectsState: subjectsState,
                  teachersState: teachersState,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter & View Mode Bar
          _buildFilterBar(
            theme,
            ayState,
            classesState,
            availableSections,
            teachersState,
            slots,
          ),

          if (_viewMode == TimetableViewMode.section && _selectedClassId != null && _selectedAyId != null)
            TimetableCapacityCard(
              schoolId: schoolId,
              academicYearId: _selectedAyId!,
              classId: _selectedClassId,
              sectionId: _selectedSectionId,
              onConfigureWorkingHours: () {
                showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => WorkingHoursDialog(
                    schoolId: schoolId,
                    academicYearId: _selectedAyId!,
                  ),
                ).then((_) => _refreshSchedule());
              },
              onOptimizeTimetable: () {
                final cls = _findFirst(classesState.classes, (c) => c.id == _selectedClassId);
                final sec = _selectedSectionId != null
                    ? _findFirst(sectionsState.sections, (s) => s.id == _selectedSectionId)
                    : null;
                if (cls == null || _selectedAyId == null) return;
                if (sec == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a specific section to generate an AI timetable.')),
                  );
                  return;
                }
                showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => TimetableAIDialog(
                    schoolId: schoolId,
                    academicYearId: _selectedAyId!,
                    classId: _selectedClassId!,
                    sectionId: sec.id,
                    className: cls.name,
                    sectionName: sec.name,
                  ),
                ).then((published) {
                  if (published == true) {
                    _refreshSchedule();
                  }
                });
              },
              onReviewSubjects: () {
                context.push(AppRoutes.subjects);
              },
            ),

          // Content
          Expanded(
            child: slotsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Failed to load timetable: $err', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refreshSchedule, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
              data: (slotsList) {
                if (classesState.classes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No classes configured yet.', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Configure classes and grade sections to begin timetable scheduling.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Configure Classes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.go(AppRoutes.classes),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (teachersState.teachers.isEmpty && _viewMode == TimetableViewMode.teacher) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No faculty members added yet.', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Add teachers and faculty members to view teacher-specific schedules.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add Teachers'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.go(AppRoutes.teachers),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (slotsList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No Periods Scheduled', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Click "Add Period" to schedule the first period slot for this timetable.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          if (_viewMode == TimetableViewMode.section)
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  key: const Key('empty_state_ai_generate_button'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('Generate with AI'),
                                  onPressed: () {
                                    final cls = _findFirst(classesState.classes, (c) => c.id == _selectedClassId);
                                    final sec = _findFirst(sectionsState.sections, (s) => s.id == _selectedSectionId);
                                    if (cls == null || sec == null || _selectedAyId == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please select Class and Section first.')),
                                      );
                                      return;
                                    }
                                    showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => TimetableAIDialog(
                                        schoolId: schoolId,
                                        academicYearId: _selectedAyId!,
                                        classId: _selectedClassId!,
                                        sectionId: _selectedSectionId!,
                                        className: cls.name,
                                        sectionName: sec.name,
                                      ),
                                    ).then((published) {
                                      if (published == true) {
                                        _refreshSchedule();
                                      }
                                    });
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Period Slot'),
                                  onPressed: () => _openSlotDialog(),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }

                if (_layoutMode == TimetableLayoutMode.dailyTimeline) {
                  return _buildDailyTimelineView(theme, slotsList, subjectsState, teachersState);
                }

                return _buildWeeklyGridView(theme, slotsList, subjectsState, teachersState, isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    ThemeData theme,
    dynamic ayState,
    dynamic classesState,
    List<dynamic> availableSections,
    dynamic teachersState,
    List<TimetableDto> slots,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                // View Mode Tabs
                SegmentedButton<TimetableViewMode>(
                  segments: const [
                    ButtonSegment(value: TimetableViewMode.section, label: Text('Class & Section'), icon: Icon(Icons.class_outlined, size: 16)),
                    ButtonSegment(value: TimetableViewMode.teacher, label: Text('Teacher Schedule'), icon: Icon(Icons.person_outline, size: 16)),
                    ButtonSegment(value: TimetableViewMode.room, label: Text('Room Schedule'), icon: Icon(Icons.meeting_room_outlined, size: 16)),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (val) => setState(() => _viewMode = val.first),
                ),
                // Layout Toggle (Weekly Grid vs Daily Timeline)
                SegmentedButton<TimetableLayoutMode>(
                  segments: const [
                    ButtonSegment(value: TimetableLayoutMode.weeklyGrid, icon: Icon(Icons.grid_view_outlined, size: 16), label: Text('Weekly')),
                    ButtonSegment(value: TimetableLayoutMode.dailyTimeline, icon: Icon(Icons.view_day_outlined, size: 16), label: Text('Daily')),
                  ],
                  selected: {_layoutMode},
                  onSelectionChanged: (val) => setState(() => _layoutMode = val.first),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Academic Year
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedAyId,
                    decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [
                      for (final y in ayState.years)
                        DropdownMenuItem<String>(
                          value: y.id,
                          child: Text('${y.name}${y.isCurrent ? " *" : ""}'),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedAyId = val),
                  ),
                ),

                if (_viewMode == TimetableViewMode.section) ...[
                  // Class
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedClassId,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        for (final c in classesState.classes)
                          DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _selectedSectionId = null;
                        });
                      },
                    ),
                  ),
                  // Section
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedSectionId,
                      decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        for (final s in availableSections)
                          DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                      ],
                      onChanged: (val) => setState(() => _selectedSectionId = val),
                    ),
                  ),
                ] else if (_viewMode == TimetableViewMode.teacher) ...[
                  // Teacher Selector
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        for (final t in teachersState.teachers)
                          DropdownMenuItem<String>(
                            value: t.id,
                            child: Text('${t.firstName} ${t.lastName} (${t.employeeCode})'),
                          ),
                      ],
                      onChanged: (val) => setState(() => _selectedTeacherId = val),
                    ),
                  ),
                ],

                if (_layoutMode == TimetableLayoutMode.dailyTimeline)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<DayOfWeek>(
                      isExpanded: true,
                      value: _selectedDailyDay,
                      decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        for (final d in DayOfWeek.values)
                          DropdownMenuItem<DayOfWeek>(
                            value: d,
                            child: Text(d.displayLabel),
                          ),
                      ],
                      onChanged: (val) => setState(() => _selectedDailyDay = val!),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGridView(
    ThemeData theme,
    List<TimetableDto> slots,
    dynamic subjectsState,
    dynamic teachersState,
    bool isMobile,
  ) {
    final days = [DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday, DayOfWeek.saturday];
    final periods = List.generate(8, (i) => i + 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 56,
            dataRowMaxHeight: 100,
            dataRowMinHeight: 80,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)),
            columns: [
              const DataColumn(
                label: SizedBox(
                  width: 90,
                  child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              ...periods.map((p) => DataColumn(
                label: SizedBox(
                  width: 130,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Period $p', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              )),
            ],
            rows: days.map((day) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 90,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(day.shortLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(day.displayLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  ...periods.map((period) {
                    final slot = _findFirst(slots, (s) => s.dayOfWeek == day && s.periodNumber == period);
                    return DataCell(
                      SizedBox(
                        width: 130,
                        child: _viewMode == TimetableViewMode.section
                            ? DragTarget<TimetableDto>(
                                onWillAcceptWithDetails: (details) => details.data.id != slot?.id,
                                onAcceptWithDetails: (details) {
                                  _handleSlotDrop(
                                    sourceSlot: details.data,
                                    targetDay: day,
                                    targetPeriod: period,
                                  );
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovered = candidateData.isNotEmpty;
                                  return Container(
                                    decoration: isHovered
                                        ? BoxDecoration(
                                            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF0F766E), width: 2),
                                          )
                                        : null,
                                    child: slot == null
                                        ? InkWell(
                                            onTap: () => _openSlotDialog(defaultDay: day, defaultPeriodNumber: period),
                                            child: Container(
                                              height: 70,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isHovered ? const Color(0xFF0F766E) : Colors.grey.shade200,
                                                  style: BorderStyle.solid,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isHovered ? Icons.add_circle : Icons.add,
                                                  color: isHovered ? const Color(0xFF0F766E) : Colors.grey.shade300,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          )
                                        : _buildSlotCard(theme, slot, subjectsState, teachersState, isDraggable: true),
                                  );
                                },
                              )
                            : (slot == null
                                ? Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  )
                                : _buildSlotCard(theme, slot, subjectsState, teachersState, isDraggable: false)),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    ThemeData theme,
    TimetableDto slot,
    dynamic subjectsState,
    dynamic teachersState, {
    bool isDraggable = false,
  }) {
    final sub = _findFirst<SubjectDto>(subjectsState.subjects, (s) => s.id == slot.subjectId);
    final teacher = _findFirst<TeacherDto>(teachersState.teachers, (t) => t.id == slot.teacherId);
    final subjectName = sub?.subjectName ?? (slot.periodType == PeriodType.breakPeriod ? 'Recess / Break' : 'Subject');
    final teacherName = teacher != null ? '${teacher.firstName[0]}. ${teacher.lastName}' : '';

    Widget buildCardContent({bool isFeedback = false}) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: slot.periodType.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFeedback ? const Color(0xFF0F766E) : slot.periodType.color.withValues(alpha: 0.3),
            width: isFeedback ? 2 : 1,
          ),
          boxShadow: isFeedback
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (_viewMode == TimetableViewMode.section)
                  const Padding(
                    padding: EdgeInsets.only(right: 2.0),
                    child: Icon(Icons.drag_indicator, size: 12, color: Colors.grey),
                  ),
                Icon(slot.periodType.icon, size: 12, color: slot.periodType.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    subjectName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: slot.periodType.color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_viewMode == TimetableViewMode.section && !isFeedback) ...[
                  InkWell(
                    onTap: () => _openSlotDialog(slot: slot),
                    child: const Icon(Icons.edit, size: 13, color: Colors.grey),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _deleteSlot(slot),
                    child: const Icon(Icons.close, size: 13, color: Colors.red),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            if (teacherName.isNotEmpty)
              Text(teacherName, style: const TextStyle(fontSize: 10, color: Colors.black87), overflow: TextOverflow.ellipsis),
            Text(slot.formattedTimeRange, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            if (slot.roomId != null && slot.roomId!.isNotEmpty)
              Text(slot.roomId!, style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
          ],
        ),
      );
    }

    if (!isDraggable) {
      return buildCardContent();
    }

    return LongPressDraggable<TimetableDto>(
      data: slot,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: SizedBox(
          width: 130,
          height: 70,
          child: buildCardContent(isFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildCardContent(),
      ),
      child: buildCardContent(),
    );
  }

  Widget _buildDailyTimelineView(
    ThemeData theme,
    List<TimetableDto> slots,
    dynamic subjectsState,
    dynamic teachersState,
  ) {
    final dailySlots = slots.where((s) => s.dayOfWeek == _selectedDailyDay).toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    if (dailySlots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('No Periods on ${_selectedDailyDay.displayLabel}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              if (_viewMode == TimetableViewMode.section)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('Add Period on ${_selectedDailyDay.displayLabel}'),
                  onPressed: () => _openSlotDialog(defaultDay: _selectedDailyDay),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: dailySlots.length,
      itemBuilder: (context, index) {
        final slot = dailySlots[index];
        final sub = _findFirst<SubjectDto>(subjectsState.subjects, (s) => s.id == slot.subjectId);
        final teacher = _findFirst<TeacherDto>(teachersState.teachers, (t) => t.id == slot.teacherId);
        final subjectName = sub?.subjectName ?? (slot.periodType == PeriodType.breakPeriod ? 'Break' : 'Subject');

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: slot.periodType.color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          color: slot.periodType.backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: slot.periodType.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'P${slot.periodNumber}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: slot.periodType.color, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(subjectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(slot.periodType.displayLabel, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      if (teacher != null)
                        Text('Instructor: ${teacher.firstName} ${teacher.lastName} (${teacher.department})', style: const TextStyle(fontSize: 13)),
                      Text('Time: ${slot.formattedTimeRange} • Room: ${slot.roomId ?? "Main Classroom"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_viewMode == TimetableViewMode.section) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Slot',
                    onPressed: () => _openSlotDialog(slot: slot),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Slot',
                    onPressed: () => _deleteSlot(slot),
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
