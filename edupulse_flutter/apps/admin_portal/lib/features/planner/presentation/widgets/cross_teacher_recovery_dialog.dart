import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';

class CrossTeacherRecoveryDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String className;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final double currentCompletion;

  const CrossTeacherRecoveryDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    required this.currentCompletion,
  });

  @override
  ConsumerState<CrossTeacherRecoveryDialog> createState() => _CrossTeacherRecoveryDialogState();
}

class _CrossTeacherRecoveryDialogState extends ConsumerState<CrossTeacherRecoveryDialog> {
  bool _isLoading = false;
  bool _isProcessing = false;
  CrossTeacherRecoveryRecommendationModel? _recommendation;
  String? _selectedTeacherId;
  String _parentNotes = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecommendation();
  }

  Future<void> _fetchRecommendation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final rec = await ref.read(academicPlanningControllerProvider.notifier).generateCrossTeacherRecommendation(
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: widget.classId,
      sectionId: widget.sectionId,
      subjectId: widget.subjectId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (rec != null) {
          _recommendation = rec;
          _selectedTeacherId = rec.recommendedSupportTeacherId;
          _parentNotes = rec.parentNotes;
        } else {
          final state = ref.read(academicPlanningControllerProvider);
          _errorMessage = state.errorMessage ?? 'Unable to generate cross-teacher recovery recommendation.';
        }
      });
    }
  }

  Future<void> _approve() async {
    if (_recommendation == null) return;
    setState(() => _isProcessing = true);

    final success = await ref.read(academicPlanningControllerProvider.notifier).approveRecoveryPlan(
      schoolId: widget.schoolId,
      planId: _recommendation!.planId,
      selectedTeacherId: _selectedTeacherId,
      parentNotes: _parentNotes.isNotEmpty ? _parentNotes : null,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovery class approved. Primary teacher remains class owner; timetable updated.'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      } else {
        final state = ref.read(academicPlanningControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage ?? 'Failed to approve recovery plan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reject() async {
    if (_recommendation == null) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Recovery Recommendation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a rationale for rejecting this AI recovery recommendation (e.g. planned remedial period by primary teacher, syllabus scope reduced, etc.):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Principal chose alternative academic recovery.';

      final success = await ref.read(academicPlanningControllerProvider.notifier).rejectRecoveryPlan(
        schoolId: widget.schoolId,
        planId: _recommendation!.planId,
        rejectionReason: reason,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          Navigator.of(context).pop(false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recovery recommendation rejected.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        constraints: BoxConstraints(maxWidth: 860, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(screenW < 768 ? 16 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_alt, color: Color(0xFF0F766E), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cross-Teacher Syllabus Recovery Intelligence',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${widget.className} - ${widget.sectionName} • ${widget.subjectName} (${widget.currentCompletion.toStringAsFixed(1)}% Completed)',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Advisory Notice Banner (Strict human-in-the-loop)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gavel, color: Color(0xFFB45309), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI RECOMMENDATION ONLY — Human review and principal approval is required. Published timetables are never modified automatically without administrative authorization.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Evaluating 15 schedule, qualification, and workload constraints...', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_outline, size: 48, color: Color(0xFF64748B)),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchRecommendation,
                                  child: const Text('Retry Analysis'),
                                ),
                              ],
                            ),
                          )
                        : _buildRecommendationContent(),
              ),

              const Divider(),
              const SizedBox(height: 8),

              // Footer Actions
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject Recommendation'),
                    onPressed: _recommendation != null && !_isProcessing ? _reject : null,
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Dismiss'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.verified, size: 18),
                        label: const Text('Approve Recovery Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _recommendation != null && !_isProcessing ? _approve : null,
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

  Widget _buildRecommendationContent() {
    final rec = _recommendation!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recommendation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 8),
                    const Text('Proposed Recovery Strategy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Projected Gain: +${rec.projectedImprovementDays} Days Earlier (Estimate)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rec.aiRecommendationText,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMetricChip('Duration', '${rec.durationWeeks} Weeks'),
                    const SizedBox(width: 8),
                    _buildMetricChip('Frequency', '${rec.recommendedPeriodsPerWeek} Period/Wk'),
                    const SizedBox(width: 8),
                    _buildMetricChip('Total Sessions', '${rec.totalRecoveryPeriods} Periods'),
                    const SizedBox(width: 8),
                    _buildMetricChip('Primary Faculty', rec.primaryTeacherName ?? 'Owner Preserved', isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Factual Multi-Candidate Comparison Table
          const Text(
            'Candidate Faculty Evaluation (Factual Comparison)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'EduPulse evaluates qualified subject teachers, parallel section progress, verified capacity, and conflict-free schedule matching. Principal may select any qualified teacher.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          ...rec.candidateEvaluations.map((cand) {
            final isSelected = _selectedTeacherId == cand.teacherId;
            final isEligible = cand.eligibilityStatus == 'ELIGIBLE';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: cand.teacherId,
                    groupValue: _selectedTeacherId,
                    onChanged: isEligible
                        ? (val) {
                            if (val != null) setState(() => _selectedTeacherId = val);
                          }
                        : null,
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(cand.teacherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            _buildEligibilityBadge(cand.eligibilityStatus),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cand.qualification ?? "Faculty"} • ${cand.sourceClassName ?? "Parallel Class"} (${cand.currentSyllabusCompletionPct.toStringAsFixed(0)}% Completed)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Teaching Load', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '${cand.currentWeeklyPeriods} / ${cand.maxWeeklyCapacity} Periods (${cand.availableCapacity} Free)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cand.availableCapacity > 0 ? const Color(0xFF0F766E) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Schedule Match', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          cand.compatibleSlots.isNotEmpty
                              ? '${cand.compatibleSlots.length} Compatible Free Periods'
                              : 'No Mutual Free Slots',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cand.compatibleSlots.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Parent Notification Preview (Neutral, academic only)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.family_restroom, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 8),
                    Text('Parent & Student App Communication Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Message: "Additional learning/recovery class: ${widget.subjectName} Recovery Session. Focus: Key syllabus concepts and arithmetic mastery."',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Strict Privacy: Internal faculty coverage, completion percentages, and teacher workload are never exposed to parents or students.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isHighlight ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF0369A1) : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildEligibilityBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'ELIGIBLE':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'ELIGIBLE';
        break;
      case 'NO_AVAILABLE_CAPACITY':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'MAX WORKLOAD REACHED';
        break;
      case 'INSUFFICIENT_PROGRESS':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'SYLLABUS NOT COMPLETED';
        break;
      case 'NO_COMPATIBLE_FREE_PERIODS':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'NO COMMON PERIOD';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
