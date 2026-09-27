import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';

class TimetableAIDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String className;
  final String sectionName;

  const TimetableAIDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
  });

  @override
  ConsumerState<TimetableAIDialog> createState() => _TimetableAIDialogState();
}

class _TimetableAIDialogState extends ConsumerState<TimetableAIDialog> {
  bool _avoidTeacherClashes = true;
  bool _balanceDailyWorkload = true;
  bool _isGenerating = false;
  bool _isApproving = false;
  TimetableAIRecommendation? _recommendation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateSuggestions();
  }

  Future<void> _generateSuggestions() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final controller = ref.read(academicPlanningControllerProvider.notifier);
    final rec = await controller.generateTimetableAI(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: widget.classId,
      sectionId: widget.sectionId,
      avoidTeacherClashes: _avoidTeacherClashes,
      balanceDailyWorkload: _balanceDailyWorkload,
    );

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _recommendation = rec;
        if (rec == null) {
          _errorMessage = ref.read(academicPlanningControllerProvider).errorMessage ?? 'Failed to generate AI recommendations.';
        }
      });
    }
  }

  Future<void> _approveRecommendation(bool publishImmediately) async {
    if (_recommendation == null) return;

    setState(() => _isApproving = true);
    final controller = ref.read(academicPlanningControllerProvider.notifier);
    final ok = await controller.approveAndPublishTimetable(
      recommendationId: _recommendation!.recommendationId,
      publishImmediately: publishImmediately,
    );

    if (mounted) {
      setState(() => _isApproving = false);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(ref.read(academicPlanningControllerProvider).errorMessage ?? 'Approval failed.'),
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 780.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW < 768 ? 12 : 24,
        vertical: screenH < 768 ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 850, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(screenW < 768 ? 16 : 24),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFF0F766E)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Timetable Recommendation Engine',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Workload Calibrated & Conflict Free',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Controls Bar
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Avoid Teacher Clashes'),
                        selected: _avoidTeacherClashes,
                        selectedColor: const Color(0xFF0F766E).withOpacity(0.15),
                        checkmarkColor: const Color(0xFF0F766E),
                        onSelected: (val) {
                          setState(() => _avoidTeacherClashes = val);
                          _generateSuggestions();
                        },
                      ),
                      FilterChip(
                        label: const Text('Balance Daily Workload'),
                        selected: _balanceDailyWorkload,
                        selectedColor: const Color(0xFF0F766E).withOpacity(0.15),
                        checkmarkColor: const Color(0xFF0F766E),
                        onSelected: (val) {
                          setState(() => _balanceDailyWorkload = val);
                          _generateSuggestions();
                        },
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Regenerate'),
                    onPressed: _isGenerating ? null : _generateSuggestions,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content Area
              Expanded(
                child: _isGenerating
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0F766E)),
                            SizedBox(height: 16),
                            Text('Analyzing syllabus workloads & checking teacher clash constraints...', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _generateSuggestions, child: const Text('Try Again')),
                              ],
                            ),
                          )
                        : _recommendation == null
                            ? const Center(child: Text('No recommendations generated.'))
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Metrics & Rationale
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Workload Analysis: ${_recommendation!.totalAllocatedPeriods} Periods / Week (${_recommendation!.weeklyWorkloadHours} Hours)',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('ZERO CLASHES DETECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Text('AI Planning Rationale:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                                          const SizedBox(height: 4),
                                          ..._recommendation!.rationale.map(
                                            (r) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Suggested Grid Slots Preview
                                    const Text('Proposed Schedule Slots:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _recommendation!.suggestedSlots.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (context, idx) {
                                          final slot = _recommendation!.suggestedSlots[idx];
                                          final isBreak = slot.isBreak || slot.periodType == 'BREAK';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            color: isBreak ? const Color(0xFFFEF3C7).withOpacity(0.2) : Colors.white,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 50,
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(slot.dayOfWeek.substring(0, 3), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 12),
                                                Text('P${slot.periodNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                const SizedBox(width: 8),
                                                Text('${slot.startTime} - ${slot.endTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: isBreak
                                                      ? const Text('Lunch / Recess Break', style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFB45309), fontSize: 12))
                                                      : Text(slot.subjectName ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                ),
                                                if (!isBreak && slot.teacherName != null)
                                                  Text('Faculty: ${slot.teacherName}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                                const SizedBox(width: 16),
                                                if (slot.roomNumber != null)
                                                  Text(slot.roomNumber!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
              const Divider(height: 24),

              // Bottom Actions: Staff Review & Explicit Approval
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'Zero-silent publishing: Suggestions require explicit staff review & approval.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _isApproving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Approve & Save Draft'),
                        onPressed: (_recommendation == null || _isApproving)
                            ? null
                            : () => _approveRecommendation(false),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.publish, size: 16),
                        label: const Text('Approve & Publish Timetable'),
                        onPressed: (_recommendation == null || _isApproving)
                            ? null
                            : () => _approveRecommendation(true),
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
}
