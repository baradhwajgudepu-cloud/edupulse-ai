import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../data/models/planner_models.dart';
import '../../data/models/timetable_models.dart';
import '../providers/planner_providers.dart';
import '../providers/academic_planning_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

enum CalendarViewMode { month, week, day }

class PlannerCalendarScreen extends ConsumerStatefulWidget {
  const PlannerCalendarScreen({super.key});

  @override
  ConsumerState<PlannerCalendarScreen> createState() => _PlannerCalendarScreenState();
}

class _PlannerCalendarScreenState extends ConsumerState<PlannerCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  String _selectedCategoryFilter = 'ALL';
  StateHolidayVerificationStatus? _stateHolidayStatus;
  bool _isLoadingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFeedForMonth();
      _fetchStateVerificationStatus();
    });
  }

  void _fetchFeedForMonth() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    ref.read(calendarFeedProvider.notifier).fetchFeed(
          startDate: DateFormat('yyyy-MM-dd').format(start),
          endDate: DateFormat('yyyy-MM-dd').format(end),
        );
  }

  Future<void> _fetchStateVerificationStatus() async {
    setState(() => _isLoadingStatus = true);
    final status = await ref
        .read(academicPlanningControllerProvider.notifier)
        .fetchStateHolidayStatus(stateName: 'TELANGANA', academicYearCode: '2026-2027');
    if (mounted) {
      setState(() {
        _stateHolidayStatus = status;
        _isLoadingStatus = false;
      });
    }
  }

  Color _getCategoryColor(String type) {
    switch (type.toUpperCase()) {
      case 'PUBLIC_HOLIDAY':
        return const Color(0xFFDC2626); // Red 600
      case 'SCHOOL_HOLIDAY':
        return const Color(0xFFD97706); // Amber 600
      case 'PRINCIPAL_DECLARED_HOLIDAY':
        return const Color(0xFF7C3AED); // Purple 600
      case 'EXAMINATION':
        return const Color(0xFF2563EB); // Blue 600
      case 'SCHOOL_EVENT':
      case 'EVENT':
        return const Color(0xFF0F766E); // Teal 700
      case 'TIMETABLE_CHANGE':
        return const Color(0xFF4F46E5); // Indigo 600
      case 'SPECIAL_WORKING_DAY':
        return const Color(0xFF0284C7); // Sky 600
      default:
        return const Color(0xFF64748B); // Slate 500
    }
  }

  String _formatCategoryLabel(String type) {
    switch (type.toUpperCase()) {
      case 'PUBLIC_HOLIDAY':
        return 'Public Holiday';
      case 'SCHOOL_HOLIDAY':
        return 'School Holiday';
      case 'PRINCIPAL_DECLARED_HOLIDAY':
        return 'Principal Declared';
      case 'EXAMINATION':
        return 'Examination';
      case 'SCHOOL_EVENT':
      case 'EVENT':
        return 'School Event';
      case 'TIMETABLE_CHANGE':
        return 'Timetable Change';
      case 'SPECIAL_WORKING_DAY':
        return 'Special Working Day';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  void _showDeclareHolidayDialog(BuildContext context, String schoolId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime chosenDate = _selectedCalendarDay;
    bool isNonWorking = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign, color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Declare Principal Holiday',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Declared holidays will trigger syllabus risk evaluation and generate minimum-disruption timetable rebalancing options.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      // Date Selector
                      const Text('Holiday Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2028),
                          );
                          if (picked != null) {
                            setDialogState(() => chosenDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy').format(chosenDate),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const Icon(Icons.calendar_month, size: 20, color: Color(0xFF0F766E)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Title
                      const Text('Holiday Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Cyclone Red Alert / Local Holiday',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Description / Reason
                      const Text('Reason / Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Administrative justification for declaration',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Non-working day toggle
                      SwitchListTile(
                        value: isNonWorking,
                        onChanged: (val) => setDialogState(() => isNonWorking = val),
                        title: const Text('Designate as Non-Working Day', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Suspends regular timetable classes and triggers AI rebalancing', style: TextStyle(fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Declare Holiday'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a holiday title')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    final ayState = ref.read(academicYearsProvider(schoolId));
                    final activeAy = ayState.years.where((y) => y.isCurrent).firstOrNull ??
                        (ayState.years.isNotEmpty ? ayState.years.first : null);
                    if (activeAy == null) return;

                    final dateStr = DateFormat('yyyy-MM-dd').format(chosenDate);
                    final success = await ref
                        .read(academicPlanningControllerProvider.notifier)
                        .declarePrincipalHoliday(
                          schoolId: schoolId,
                          academicYearId: activeAy.id,
                          eventDate: dateStr,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          isNonWorkingDay: isNonWorking,
                        );

                    if (success && mounted) {
                      _fetchFeedForMonth();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Holiday "${titleController.text.trim()}" declared successfully.'),
                          backgroundColor: const Color(0xFF0F766E),
                          action: SnackBarAction(
                            label: 'Review Impact',
                            textColor: Colors.white,
                            onPressed: () {
                              _showHolidayImpactAndRecoveryDialog(context, schoolId, activeAy.id, dateStr, titleController.text.trim());
                            },
                          ),
                        ),
                      );
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

  void _showHolidayImpactAndRecoveryDialog(
    BuildContext context,
    String schoolId,
    String academicYearId,
    String holidayDate,
    String holidayTitle,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _HolidayImpactRecoveryModal(
          schoolId: schoolId,
          academicYearId: academicYearId,
          holidayDate: holidayDate,
          holidayTitle: holidayTitle,
          onApplied: () {
            _fetchFeedForMonth();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        body: const Center(
          child: Text(
            'Please select a school campus from the header to view the Academic Calendar.',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final state = ref.watch(calendarFeedProvider);
    final ayState = ref.watch(academicYearsProvider(schoolId));
    final activeAy = ayState.years.where((y) => y.isCurrent).firstOrNull ??
        (ayState.years.isNotEmpty ? ayState.years.first : null);

    // Filter feed items by category
    final filteredFeedItems = state.feedItems.where((item) {
      if (_selectedCategoryFilter == 'ALL') return true;
      final type = (item['type'] as String? ?? '').toUpperCase();
      return type == _selectedCategoryFilter;
    }).toList();

    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1; // Mon=0, Sun=6

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            _buildHeader(context, schoolId, activeAy?.name ?? '2026-2027'),
            const SizedBox(height: 16),

            // 2. State Holiday Gazette Verification Banner
            _buildGazetteVerificationBanner(context, schoolId, activeAy?.id),
            const SizedBox(height: 16),

            // 3. View Switcher & Category Filter Chips
            _buildFilterAndControls(context),
            const SizedBox(height: 20),

            // 4. Main Calendar + Agenda Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final calendarWidget = _buildCalendarGrid(context, state, daysInMonth, firstDayOffset);
                final agendaWidget = _buildAgendaSection(context, filteredFeedItems, schoolId, activeAy?.id);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: calendarWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: agendaWidget),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      calendarWidget,
                      const SizedBox(height: 24),
                      agendaWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String schoolId, String ayLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  const Text(
                    'Academic Calendar & Holiday Operations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'AY $ayLabel',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Unified academic calendar integrating gazette public holidays, exam schedules, and intelligent timetable impact analysis.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              onPressed: () {
                _fetchFeedForMonth();
                _fetchStateVerificationStatus();
              },
              tooltip: 'Refresh Calendar',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Declare Holiday'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showDeclareHolidayDialog(context, schoolId),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGazetteVerificationBanner(BuildContext context, String schoolId, String? activeAyId) {
    final status = _stateHolidayStatus;
    if (_isLoadingStatus) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Verifying state gazette public holiday calendar...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (status != null && status.isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4), // Green 50
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF16A34A), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Verified State Gazette Master: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                      ),
                      Text(
                        '${status.state} (${status.sourceVersion ?? "Official G.O."})',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${status.holidaysCount} Public Holidays',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.source ?? 'Official Government Gazette',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 16, color: Color(0xFF16A34A)),
              label: const Text('Sync State Holidays', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF86EFAC)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () async {
                final ayId = activeAyId ?? 'ay-current';
                final ok = await ref
                    .read(academicPlanningControllerProvider.notifier)
                    .populateStateHolidays(
                      schoolId: schoolId,
                      academicYearId: ayId,
                      stateName: status.state,
                      academicYearCode: status.academicYearCode,
                    );
                if (ok && mounted) {
                  _fetchFeedForMonth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verified state public holidays populated successfully.'),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Public holiday calendar could not be verified. Gazette master required before state holidays can be imported.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF59E0B)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manual holiday import interface ready.')),
              );
            },
            child: const Text('Import Manual', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndControls(BuildContext context) {
    final categories = [
      {'key': 'ALL', 'label': 'All Events'},
      {'key': 'PUBLIC_HOLIDAY', 'label': 'Public Holiday', 'color': const Color(0xFFDC2626)},
      {'key': 'SCHOOL_HOLIDAY', 'label': 'School Holiday', 'color': const Color(0xFFD97706)},
      {'key': 'PRINCIPAL_DECLARED_HOLIDAY', 'label': 'Principal Declared', 'color': const Color(0xFF7C3AED)},
      {'key': 'EXAMINATION', 'label': 'Examination', 'color': const Color(0xFF2563EB)},
      {'key': 'SCHOOL_EVENT', 'label': 'School Event', 'color': const Color(0xFF0F766E)},
      {'key': 'TIMETABLE_CHANGE', 'label': 'Timetable Change', 'color': const Color(0xFF4F46E5)},
    ];

    return Row(
      children: [
        // Category Chips
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final key = cat['key'] as String;
                final isSelected = _selectedCategoryFilter == key;
                final color = (cat['color'] as Color?) ?? const Color(0xFF0F766E);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? color : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategoryFilter = val ? key : 'ALL';
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // View Mode Switcher
        SegmentedButton<CalendarViewMode>(
          segments: const [
            ButtonSegment(value: CalendarViewMode.month, label: Text('Month', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: CalendarViewMode.week, label: Text('Week', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: CalendarViewMode.day, label: Text('Day', style: TextStyle(fontSize: 12))),
          ],
          selected: {_viewMode},
          onSelectionChanged: (modes) {
            setState(() => _viewMode = modes.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    CalendarFeedState state,
    int daysInMonth,
    int firstDayOffset,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF475569)),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                    });
                    _fetchFeedForMonth();
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                    });
                    _fetchFeedForMonth();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Expanded(child: Center(child: Text('Mon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Tue', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Wed', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Thu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Fri', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Sat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)))),
                Expanded(child: Center(child: Text('Sun', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 12)))),
              ],
            ),
            const SizedBox(height: 12),

            // Days Grid
            if (state.isLoading)
              const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.15,
                ),
                itemCount: daysInMonth + firstDayOffset,
                itemBuilder: (context, index) {
                  if (index < firstDayOffset) {
                    return const SizedBox();
                  }

                  final day = index - firstDayOffset + 1;
                  final dateObj = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                  final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);

                  final matches = state.feedItems.where((item) => item['date'] == dateStr).toList();
                  final isSelected = DateUtils.isSameDay(dateObj, _selectedCalendarDay);
                  final isToday = DateUtils.isSameDay(dateObj, DateTime.now());
                  final isSunday = dateObj.weekday == DateTime.sunday;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCalendarDay = dateObj;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isSelected
                            ? const Color(0xFF0F766E)
                            : (isToday ? const Color(0xFF0F766E).withValues(alpha: 0.1) : null),
                        border: isToday && !isSelected
                            ? Border.all(color: const Color(0xFF0F766E), width: 1.5)
                            : Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isSunday ? const Color(0xFFDC2626) : const Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Event indicators
                          if (matches.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: matches.take(3).map((item) {
                                final type = (item['type'] as String? ?? '').toUpperCase();
                                final color = _getCategoryColor(type);
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(color: isSelected ? Colors.white : color, shape: BoxShape.circle),
                                );
                              }).toList(),
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaSection(
    BuildContext context,
    List<Map<String, dynamic>> filteredItems,
    String schoolId,
    String? activeAyId,
  ) {
    final dayStr = DateFormat('yyyy-MM-dd').format(_selectedCalendarDay);
    final dayEvents = filteredItems.where((item) => item['date'] == dayStr).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operational Agenda',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(_selectedCalendarDay),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${dayEvents.length} Items',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (dayEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.event_available, size: 40, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'Regular Academic Working Day',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Standard timetable schedule operates normally.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayEvents.length,
                separatorBuilder: (context, index) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final item = dayEvents[index];
                  final type = (item['type'] as String? ?? 'EVENT').toUpperCase();
                  final color = _getCategoryColor(type);
                  final isHoliday = type.contains('HOLIDAY');
                  final title = item['title'] as String? ?? 'Event';
                  final desc = item['description'] as String? ?? '';
                  final extra = item['extra_data'] as Map<String, dynamic>? ?? {};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatCategoryLabel(type),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (extra['source_reference'] != null)
                            Text(
                              extra['source_reference'].toString(),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ],
                      if (isHoliday) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF0F766E)),
                          label: const Text('Analyze Timetable Impact & AI Rebalance', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0F766E)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () {
                            _showHolidayImpactAndRecoveryDialog(
                              context,
                              schoolId,
                              activeAyId ?? 'ay-current',
                              dayStr,
                              title,
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HolidayImpactRecoveryModal extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String holidayDate;
  final String holidayTitle;
  final VoidCallback onApplied;

  const _HolidayImpactRecoveryModal({
    required this.schoolId,
    required this.academicYearId,
    required this.holidayDate,
    required this.holidayTitle,
    required this.onApplied,
  });

  @override
  ConsumerState<_HolidayImpactRecoveryModal> createState() => _HolidayImpactRecoveryModalState();
}

class _HolidayImpactRecoveryModalState extends ConsumerState<_HolidayImpactRecoveryModal> {
  bool _isLoading = true;
  HolidayImpactData? _impactData;
  AIRecoveryPreview? _recoveryPreview;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadImpactAndRecovery());
  }

  Future<void> _loadImpactAndRecovery() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ctrl = ref.read(academicPlanningControllerProvider.notifier);
    final impact = await ctrl.fetchHolidayImpact(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      holidayDate: widget.holidayDate,
    );

    AIRecoveryPreview? recovery;
    if (impact != null && impact.affectedPeriodsCount > 0) {
      recovery = await ctrl.generateHolidayRecovery(
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        holidayDate: widget.holidayDate,
      );
    }

    if (mounted) {
      setState(() {
        _impactData = impact;
        _recoveryPreview = recovery;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_mode, color: Color(0xFF0F766E), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Timetable Impact & Recovery Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '${widget.holidayTitle} (${widget.holidayDate})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: _isLoading
            ? const SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0F766E)),
                      SizedBox(height: 16),
                      Text('Running Minimum-Disruption AI Recovery Engine...', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Impact metrics cards
                    if (_impactData != null) ...[
                      Row(
                        children: [
                          _buildMetricPill(
                            label: 'Periods Affected',
                            value: '${_impactData!.affectedPeriodsCount}',
                            color: const Color(0xFFDC2626),
                            icon: Icons.event_busy,
                          ),
                          const SizedBox(width: 12),
                          _buildMetricPill(
                            label: 'Sections Affected',
                            value: '${_impactData!.affectedSectionsCount}',
                            color: const Color(0xFFD97706),
                            icon: Icons.groups,
                          ),
                          const SizedBox(width: 12),
                          _buildMetricPill(
                            label: 'Teachers Impacted',
                            value: '${_impactData!.affectedTeachersCount}',
                            color: const Color(0xFF7C3AED),
                            icon: Icons.person_pin,
                          ),
                          const SizedBox(width: 12),
                          _buildMetricPill(
                            label: 'Syllabus Risks',
                            value: '${_impactData!.syllabusRisksCount}',
                            color: const Color(0xFF0F766E),
                            icon: Icons.menu_book,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Syllabus Risk Alert
                    if (_impactData != null && _impactData!.syllabusRiskDetails.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning, size: 16, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text('Syllabus Completion Risks Identified:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._impactData!.syllabusRiskDetails.map(
                              (r) => Text('• $r', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // AI Recovery Recommendations (Minimum-Disruption Engine)
                    if (_recoveryPreview != null && _recoveryPreview!.changes.isNotEmpty) ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Proposed Rebalancing Schedule (Minimum Disruption):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_recoveryPreview!.totalSlotsRecovered} / ${_recoveryPreview!.totalSlotsAffected} Slots Recovered',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F766E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recoveryPreview!.changes.length,
                          separatorBuilder: (context, idx) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final change = _recoveryPreview!.changes[idx];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF0F766E)),
                              ),
                              title: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${change.className} (${change.sectionName}) - ${change.subjectName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Teacher: ${change.teacherName}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${change.originalDay} Period ${change.originalPeriodNumber}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF64748B)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${change.targetDay} Period ${change.targetPeriodNumber} (${change.targetDate})',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      change.reason,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (_impactData != null && _impactData!.affectedPeriodsCount == 0) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'No published timetable periods fall on this holiday date.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_recoveryPreview != null && _recoveryPreview!.changes.isNotEmpty) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            onPressed: () async {
              final ok = await ref
                  .read(academicPlanningControllerProvider.notifier)
                  .rejectHolidayRecovery(
                    recoveryId: _recoveryPreview!.recoveryId,
                    schoolId: widget.schoolId,
                    reason: 'Principal rejected recovery proposal.',
                  );
              if (ok && mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recovery plan rejected.')),
                );
              }
            },
            child: const Text('Reject'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply Changes & Dispatch Notifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final rawChanges = _recoveryPreview!.changes.map((c) => c.toJson()).toList();
              final ok = await ref
                  .read(academicPlanningControllerProvider.notifier)
                  .applyHolidayRecovery(
                    recoveryId: _recoveryPreview!.recoveryId,
                    schoolId: widget.schoolId,
                    academicYearId: widget.academicYearId,
                    changes: rawChanges,
                    remarks: 'Approved by Principal for ${widget.holidayTitle}',
                  );

              if (ok && mounted) {
                widget.onApplied();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Timetable updated and notifications dispatched to affected teachers.'),
                    backgroundColor: Color(0xFF0F766E),
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
