import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';

class RecoveryPlanEditorDialog extends ConsumerStatefulWidget {
  final AdminSyllabusRecoveryPlanModel initialPlan;
  final VoidCallback onPlanUpdated;

  const RecoveryPlanEditorDialog({
    super.key,
    required this.initialPlan,
    required this.onPlanUpdated,
  });

  @override
  ConsumerState<RecoveryPlanEditorDialog> createState() => _RecoveryPlanEditorDialogState();
}

class _RecoveryPlanEditorDialogState extends ConsumerState<RecoveryPlanEditorDialog> {
  late AdminSyllabusRecoveryPlanModel _plan;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
  }

  int get _conflictCount => _plan.items.where((i) => i.conflictStatus == 'CONFLICT_DETECTED').length;

  Future<void> _editSlot(RecoveryPlanItemModel item) async {
    final dateCtrl = TextEditingController(text: item.date);
    final topicCtrl = TextEditingController(text: item.topicName);
    int selectedPeriod = item.periodNumber;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Edit Candidate Slot (Phase: ${item.phase})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date (YYYY-MM-DD):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      DateTime initial = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: IgnorePointer(
                      child: TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Period Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: selectedPeriod,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: List.generate(8, (i) => i + 1).map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(value: p, child: Text('Period $p'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPeriod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Topic Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: topicCtrl,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitting will instantly execute conflict validation against teacher schedule, room clash, and holidays.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Validate & Save'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true) {
      setState(() => _isProcessing = true);
      final updates = {
        'date': dateCtrl.text.trim(),
        'period_number': selectedPeriod,
        'topic_name': topicCtrl.text.trim(),
      };

      final ok = await ref.read(academicPlanningControllerProvider.notifier).updateRecoveryItem(
        planId: _plan.id,
        itemId: item.id,
        data: updates,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          widget.onPlanUpdated();
          Navigator.pop(context); // Close dialog and refresh parent
        }
      }
    }
  }

  Future<void> _regenerate() async {
    setState(() => _isProcessing = true);
    final ok = await ref.read(academicPlanningControllerProvider.notifier).regenerateRecoveryPlan(
      planId: _plan.id,
      reason: 'Regenerated by Admin from Recovery Plan Editor',
    );
    if (mounted) {
      setState(() => _isProcessing = false);
      if (ok) {
        widget.onPlanUpdated();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    final ok = await ref.read(academicPlanningControllerProvider.notifier).approveSyllabusRecoveryPlan(
      planId: _plan.id,
      remarks: 'Approved by Administrator',
    );
    if (mounted) {
      setState(() => _isProcessing = false);
      if (ok) {
        widget.onPlanUpdated();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Recovery Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter remarks for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Reason...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Plan'),
          ),
        ],
      ),
    );

    if (shouldReject == true && reasonCtrl.text.isNotEmpty) {
      setState(() => _isProcessing = true);
      final ok = await ref.read(academicPlanningControllerProvider.notifier).rejectSyllabusRecoveryPlan(
        planId: _plan.id,
        remarks: reasonCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          widget.onPlanUpdated();
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflictCount = _conflictCount;
    final isApproved = _plan.status == 'APPROVED';
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 780.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW < 768 ? 12 : 24,
        vertical: screenH < 768 ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(screenW < 768 ? 16 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.rule_folder_rounded, color: Color(0xFF0F766E), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Syllabus Recovery Plan Editor: ${_plan.subjectName ?? "Subject"}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_plan.className ?? "Class"} ${_plan.sectionName ?? ""} • Teacher: ${_plan.teacherName ?? "Faculty"} • Status: ${_plan.status}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),

              // KPI & Pacing Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    _buildMetaPill('Current Completion', '${_plan.currentCompletion.toStringAsFixed(0)}%'),
                    _buildMetaPill('Target Exam Date', _plan.targetCompletionDate ?? 'N/A'),
                    _buildMetaPill('Original Forecast', _plan.forecastCompletionDate ?? 'N/A'),
                    _buildMetaPill('Recovered Forecast', _plan.newForecastDate ?? 'N/A', isHighlighted: true),
                    _buildMetaPill('Recovery Periods', '${_plan.expectedRecoveryPeriods.toStringAsFixed(0)} slots'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Conflict Status Banner
              if (conflictCount > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$conflictCount candidate slot conflict(s) detected. Please edit slots or regenerate before approving.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Text(
                        '0 Timetable Conflicts. All candidate slots are verified available for allocation.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Slots List
              const Text(
                'Candidate Timetable Recovery Slots (Phased)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _plan.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _plan.items[index];
                    final hasConflict = item.conflictStatus == 'CONFLICT_DETECTED';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasConflict ? const Color(0xFFFFF1F2) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasConflict ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.phase.replaceAll('PHASE_', 'P'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${item.date} • Period ${item.periodNumber} (${item.durationMinutes} min)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    if (hasConflict)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('CONFLICT', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('VERIFIED OK', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('Topic: ${item.topicName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                if (hasConflict && item.conflictMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      item.conflictMessage!,
                                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isApproved)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: _isProcessing ? null : () => _editSlot(item),
                              icon: const Icon(Icons.edit_calendar, size: 14),
                              label: const Text('Edit Slot', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions Bar
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    onPressed: _isProcessing || isApproved ? null : _reject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject Plan'),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isProcessing || isApproved ? null : _regenerate,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate Slots'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: conflictCount > 0 ? Colors.grey : const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: (_isProcessing || isApproved || conflictCount > 0) ? null : _approve,
                        icon: _isProcessing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(isApproved ? 'Plan Already Approved' : 'Approve & Publish to Timetable'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill(String title, String value, {bool isHighlighted = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
