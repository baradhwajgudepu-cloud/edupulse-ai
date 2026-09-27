import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/timetable_models.dart';
import '../providers/working_hours_providers.dart';

class WorkingHoursDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;

  const WorkingHoursDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
  });

  @override
  ConsumerState<WorkingHoursDialog> createState() => _WorkingHoursDialogState();
}

class _WorkingHoursDialogState extends ConsumerState<WorkingHoursDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _normalStartCtrl;
  late TextEditingController _normalEndCtrl;
  late TextEditingController _extendedStartCtrl;
  late TextEditingController _extendedEndCtrl;

  int _periodsPerDay = 8;
  int _lunchPeriod = 4;
  List<String> _workingDays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  bool _isExtendedHoursEnabled = false;
  List<String> _applicableDays = ['MONDAY', 'WEDNESDAY', 'FRIDAY'];
  int _additionalPeriods = 1;
  bool _initialized = false;

  List<BreakTimingDto> _breaks = [];
  int _periodDuration = 45;
  TimetableRecalculationPreviewDto? _preview;
  bool _approvedExtension = false;

  final List<String> _allDays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY'
  ];

  @override
  void initState() {
    super.initState();
    _normalStartCtrl = TextEditingController(text: '08:30');
    _normalEndCtrl = TextEditingController(text: '15:30');
    _extendedStartCtrl = TextEditingController(text: '15:30');
    _extendedEndCtrl = TextEditingController(text: '16:15');
  }

  @override
  void dispose() {
    _normalStartCtrl.dispose();
    _normalEndCtrl.dispose();
    _extendedStartCtrl.dispose();
    _extendedEndCtrl.dispose();
    super.dispose();
  }

  void _populateFromDto(ExtendedWorkingHourDto dto) {
    if (_initialized) return;
    _initialized = true;
    _normalStartCtrl.text = dto.normalStartTime;
    _normalEndCtrl.text = dto.normalEndTime;
    _periodsPerDay = dto.periodsPerDay;
    _lunchPeriod = dto.lunchPeriodNumber;
    _workingDays = List.from(dto.workingDays);
    _isExtendedHoursEnabled = dto.isExtendedHoursEnabled;
    if (dto.extendedStartTime != null) _extendedStartCtrl.text = dto.extendedStartTime!;
    if (dto.extendedEndTime != null) _extendedEndCtrl.text = dto.extendedEndTime!;
    _applicableDays = List.from(dto.applicableDays);
    _additionalPeriods = dto.additionalPeriods;
    _periodDuration = dto.periodDurationMinutes;

    if (dto.breaks.isNotEmpty) {
      _breaks = List.from(dto.breaks);
    } else {
      _breaks = [
        BreakTimingDto(
          id: 'lunch_default',
          name: 'Lunch Break',
          breakType: 'LUNCH_BREAK',
          afterPeriod: dto.lunchPeriodNumber,
          durationMinutes: 45,
        )
      ];
    }

    _recalculatePreview();
  }

  void _addBreak(String breakType) {
    final count = _breaks.where((b) => b.breakType == breakType).length + 1;
    final isLunch = breakType == 'LUNCH_BREAK';
    final afterPeriod = isLunch ? 4 : (count == 1 ? 2 : 5);
    final duration = isLunch ? 45 : 15;
    final name = isLunch ? 'Lunch Break' : 'Short Break $count';

    setState(() {
      _breaks.add(BreakTimingDto(
        id: 'break_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        breakType: breakType,
        afterPeriod: afterPeriod.clamp(1, _periodsPerDay - 1),
        durationMinutes: duration,
      ));
    });
    _recalculatePreview();
  }

  void _removeBreak(int index) {
    setState(() {
      _breaks.removeAt(index);
    });
    _recalculatePreview();
  }

  void _updateBreak(int index, BreakTimingDto updated) {
    setState(() {
      _breaks[index] = updated;
    });
    _recalculatePreview();
  }

  Future<void> _recalculatePreview() async {
    final preview = await ref.read(workingHoursActionProvider.notifier).previewRecalculation(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      breaks: _breaks,
      periodDurationMinutes: _periodDuration,
    );
    if (mounted && preview != null) {
      setState(() {
        _preview = preview;
        if (_approvedExtension && preview.calculatedEndTime.isNotEmpty) {
          _normalEndCtrl.text = preview.calculatedEndTime;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final hoursAsync = ref.watch(extendedWorkingHoursProvider(
      (schoolId: widget.schoolId, academicYearId: widget.academicYearId),
    ));
    final actionState = ref.watch(workingHoursActionProvider);

    return hoursAsync.when(
      loading: () => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: (screenW * 0.05).clamp(16.0, 40.0),
          vertical: (screenH * 0.04).clamp(16.0, 32.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading school working hours...'),
            ],
          ),
        ),
      ),
      error: (err, stack) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: (screenW * 0.05).clamp(16.0, 40.0),
          vertical: (screenH * 0.04).clamp(16.0, 32.0),
        ),
        title: const Text('Error loading hours', overflow: TextOverflow.ellipsis),
        content: Text(err.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
      data: (dto) {
        _populateFromDto(dto);

        final normalWeeklyPeriods = _workingDays.length * _periodsPerDay;
        final extendedWeeklyPeriods = _isExtendedHoursEnabled ? (_applicableDays.length * _additionalPeriods) : 0;
        final totalCapacity = normalWeeklyPeriods + extendedWeeklyPeriods;

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: (screenW * 0.05).clamp(16.0, 40.0),
            vertical: (screenH * 0.04).clamp(16.0, 32.0),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.schedule, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School Working Hours & Teaching Capacity', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Configure daily periods and extended teaching hours', 
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: (screenH * 0.85).clamp(360.0, 750.0),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Capacity Summary Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: Column(
                              children: [
                                const Text('Working Days', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${_workingDays.length} days/wk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              children: [
                                const Text('Regular Periods', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('$normalWeeklyPeriods periods', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          if (_isExtendedHoursEnabled)
                            Flexible(
                              child: Column(
                                children: [
                                  const Text('Extended Periods', style: TextStyle(fontSize: 11, color: Colors.teal)),
                                  Text('+$extendedWeeklyPeriods periods', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                                ],
                              ),
                            ),
                          Flexible(
                            child: Column(
                              children: [
                                const Text('Total Capacity', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('$totalCapacity periods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Normal Working Hours
                    const Text('Regular School Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _normalStartCtrl,
                            decoration: const InputDecoration(
                              labelText: 'School Starts (HH:MM)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.wb_sunny_outlined, size: 20),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _normalEndCtrl,
                            decoration: const InputDecoration(
                              labelText: 'School Closes (HH:MM)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.wb_twilight_outlined, size: 20),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _periodsPerDay,
                            decoration: const InputDecoration(
                              labelText: 'Periods Per Day',
                              border: OutlineInputBorder(),
                            ),
                            items: [5, 6, 7, 8, 9, 10].map((pCount) {
                              return DropdownMenuItem(value: pCount, child: Text('$pCount Periods'));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _periodsPerDay = v);
                                _recalculatePreview();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _periodDuration,
                            decoration: const InputDecoration(
                              labelText: 'Period Duration',
                              border: OutlineInputBorder(),
                            ),
                            items: [30, 35, 40, 45, 50, 55, 60].map((dur) {
                              return DropdownMenuItem(value: dur, child: Text('$dur Minutes'));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _periodDuration = v);
                                _recalculatePreview();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Active School Working Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allDays.map((d) {
                        final isSelected = _workingDays.contains(d);
                        final label = d.substring(0, 3);
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _workingDays.add(d);
                              } else {
                                if (_workingDays.length > 1) {
                                  _workingDays.remove(d);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section 2: Break & Lunch Timings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Break & Lunch Timings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('Subsequent period start & end times will automatically shift.',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.coffee_outlined, size: 16),
                              label: const Text('Add Short Break', style: TextStyle(fontSize: 12)),
                              onPressed: () => _addBreak('SHORT_BREAK'),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.restaurant_outlined, size: 16),
                              label: const Text('Add Lunch Break', style: TextStyle(fontSize: 12)),
                              onPressed: () => _addBreak('LUNCH_BREAK'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_breaks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'No breaks configured. Click above to add a Short Break or Lunch Break.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: List.generate(_breaks.length, (idx) {
                          final b = _breaks[idx];
                          final isLunch = b.breakType == 'LUNCH_BREAK';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isLunch ? Colors.amber.shade50.withOpacity(0.4) : Colors.blue.shade50.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isLunch ? Colors.amber.shade300 : Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLunch ? Icons.restaurant : Icons.coffee,
                                  size: 18,
                                  color: isLunch ? Colors.amber.shade800 : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: b.name,
                                    decoration: const InputDecoration(
                                      labelText: 'Break Label',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      _updateBreak(
                                        idx,
                                        BreakTimingDto(
                                          id: b.id,
                                          name: val.trim().isEmpty ? b.name : val.trim(),
                                          breakType: b.breakType,
                                          afterPeriod: b.afterPeriod,
                                          durationMinutes: b.durationMinutes,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    value: b.afterPeriod.clamp(1, _periodsPerDay),
                                    decoration: const InputDecoration(
                                      labelText: 'After',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: List.generate(_periodsPerDay, (i) => i + 1).map((pNum) {
                                      return DropdownMenuItem(value: pNum, child: Text('Period $pNum'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateBreak(
                                          idx,
                                          BreakTimingDto(
                                            id: b.id,
                                            name: b.name,
                                            breakType: b.breakType,
                                            afterPeriod: val,
                                            durationMinutes: b.durationMinutes,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    value: [10, 15, 20, 25, 30, 40, 45, 50, 60].contains(b.durationMinutes)
                                        ? b.durationMinutes
                                        : 15,
                                    decoration: const InputDecoration(
                                      labelText: 'Duration',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [10, 15, 20, 25, 30, 40, 45, 50, 60].map((dur) {
                                      return DropdownMenuItem(value: dur, child: Text('$dur min'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateBreak(
                                          idx,
                                          BreakTimingDto(
                                            id: b.id,
                                            name: b.name,
                                            breakType: b.breakType,
                                            afterPeriod: b.afterPeriod,
                                            durationMinutes: val,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'Delete Break',
                                  onPressed: () => _removeBreak(idx),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                    // Sequential Timeline Visualizer
                    if (_preview != null && _preview!.periodTimings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timeline, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                const Text(
                                  'Sequential Period & Break Schedule',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '${_preview!.normalStartTime} → ${_preview!.calculatedEndTime}',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _preview!.periodTimings.map((item) {
                                  final isBreak = item['type'] == 'BREAK';
                                  final isLunch = item['break_type'] == 'LUNCH_BREAK';
                                  final label = isBreak
                                      ? (isLunch ? '🍱 ${item["name"] ?? "Lunch"}' : '☕ ${item["name"] ?? "Break"}')
                                      : 'P${item["period_number"]}';
                                  final timeStr = '${item["start_time_str"]} - ${item["end_time_str"]}';

                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isBreak
                                          ? (isLunch ? Colors.amber.shade100 : Colors.blue.shade100)
                                          : theme.colorScheme.primaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isBreak
                                            ? (isLunch ? Colors.amber.shade400 : Colors.blue.shade300)
                                            : theme.colorScheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: isBreak
                                                ? (isLunch ? Colors.amber.shade900 : Colors.blue.shade900)
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // School Hours Extension Banner
                    if (_preview != null && (_preview!.requiresExtension || _preview!.extensionMinutes > 0)) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'School Hours Extension Required',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF78350F)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${_preview!.extensionMinutes} min extension',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Original End Time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(_preview!.originalEndTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                  Column(
                                    children: [
                                      const Text('Break Extension', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text('+${_preview!.extensionMinutes} mins', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                  Column(
                                    children: [
                                      const Text('New Required End Time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _preview!.calculatedEndTime,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Configured break durations extend the timetable past current school hours. Administrator approval ensures no periods are dropped or truncated.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: _approvedExtension,
                              activeColor: Colors.amber.shade800,
                              title: Text(
                                'Approve School Closing Extension to ${_preview!.calculatedEndTime}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF78350F)),
                              ),
                              subtitle: const Text(
                                'Updates school closing time and syncs all period slots across classes & teachers',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _approvedExtension = val ?? false;
                                  if (_approvedExtension && _preview != null) {
                                    _normalEndCtrl.text = _preview!.calculatedEndTime;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section 2: Extended Teaching Hours
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.more_time, size: 20, color: Colors.teal),
                                  SizedBox(width: 8),
                                  Text('Extended Teaching Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Text(
                                'Enable extra slot after school for additional subjects, robotics, or labs',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isExtendedHoursEnabled,
                          activeColor: Colors.teal,
                          onChanged: (val) {
                            setState(() => _isExtendedHoursEnabled = val);
                          },
                        ),
                      ],
                    ),

                    if (_isExtendedHoursEnabled) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _extendedStartCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Extended Start Time',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.alarm, size: 20),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _extendedEndCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Extended End Time',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.alarm_off, size: 20),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Days Extended Hours Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _workingDays.map((d) {
                                final isSelected = _applicableDays.contains(d);
                                final label = d.substring(0, 3);
                                return FilterChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  selectedColor: Colors.teal.shade100,
                                  checkmarkColor: Colors.teal.shade900,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _applicableDays.add(d);
                                      } else {
                                        _applicableDays.remove(d);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '💡 The AI engine will recommend slots during these extended hours only if normal timetable capacity is exceeded, subject to administrator approval.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.teal.shade800),
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
          actionsOverflowButtonSpacing: 8,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          actions: [
            TextButton(
              onPressed: actionState.isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: actionState.isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save Working Hours'),
              onPressed: actionState.isLoading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final updatedDto = ExtendedWorkingHourDto(
                        id: dto.id,
                        schoolId: widget.schoolId,
                        academicYearId: widget.academicYearId,
                        normalStartTime: _normalStartCtrl.text.trim(),
                        normalEndTime: _normalEndCtrl.text.trim(),
                        periodsPerDay: _periodsPerDay,
                        lunchPeriodNumber: _lunchPeriod,
                        workingDays: _workingDays,
                        isExtendedHoursEnabled: _isExtendedHoursEnabled,
                        extendedStartTime: _isExtendedHoursEnabled ? _extendedStartCtrl.text.trim() : null,
                        extendedEndTime: _isExtendedHoursEnabled ? _extendedEndCtrl.text.trim() : null,
                        applicableDays: _isExtendedHoursEnabled ? _applicableDays : [],
                        additionalPeriods: _additionalPeriods,
                        activityType: 'ADDITIONAL_SUBJECT',
                        weeklyNormalPeriods: normalWeeklyPeriods,
                        weeklyExtendedPeriods: extendedWeeklyPeriods,
                        totalWeeklyCapacity: totalCapacity,
                        periodDurationMinutes: _periodDuration,
                        breaks: _breaks,
                      );

                      final ok = await ref
                          .read(workingHoursActionProvider.notifier)
                          .updateWorkingHours(updatedDto);

                      if (ok) {
                        await ref
                            .read(workingHoursActionProvider.notifier)
                            .applyRecalculatedTimings(
                              schoolId: widget.schoolId,
                              academicYearId: widget.academicYearId,
                              approveExtension: _approvedExtension,
                              newEndTime: _approvedExtension && _preview != null
                                  ? _preview!.calculatedEndTime
                                  : null,
                              breaks: _breaks,
                              periodDurationMinutes: _periodDuration,
                            );
                      }

                      if (ok && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
            ),
          ],
        );
      },
    );
  }
}
