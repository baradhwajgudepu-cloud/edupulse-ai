import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';
import 'recovery_plan_editor_dialog.dart';

class AdminRecoveryPlansWidget extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;

  const AdminRecoveryPlansWidget({
    super.key,
    required this.schoolId,
    required this.academicYearId,
  });

  @override
  ConsumerState<AdminRecoveryPlansWidget> createState() => _AdminRecoveryPlansWidgetState();
}

class _AdminRecoveryPlansWidgetState extends ConsumerState<AdminRecoveryPlansWidget> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminRecoveryPlansProvider((
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      status: _statusFilter,
    )));

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text('Failed to load syllabus recovery plans: $err'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminRecoveryPlansProvider((
                schoolId: widget.schoolId,
                academicYearId: widget.academicYearId,
                status: _statusFilter,
              ))),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (plans) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Filter Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Syllabus Recovery Plans & Operational Conflict Management',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Human-in-the-loop candidate recovery slots generated for missed teaching periods and pacing delays.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Plans'),
                    onPressed: () => ref.invalidate(adminRecoveryPlansProvider((
                      schoolId: widget.schoolId,
                      academicYearId: widget.academicYearId,
                      status: _statusFilter,
                    ))),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip(null, 'All Statuses (${plans.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SUGGESTED', 'Suggested'),
                  const SizedBox(width: 8),
                  _buildFilterChip('EDITED', 'Edited'),
                  const SizedBox(width: 8),
                  _buildFilterChip('APPROVED', 'Approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REJECTED', 'Rejected'),
                ],
              ),
              const SizedBox(height: 20),

              if (plans.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_outlined, size: 48, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Recovery Plans Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No syllabus recovery interventions are currently active or pending review.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return _buildPlanCard(plan);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String? status, String label) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selectedColor: const Color(0xFF0F766E),
      checkmarkColor: Colors.white,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _buildPlanCard(AdminSyllabusRecoveryPlanModel plan) {
    final hasConflict = plan.items.any((i) => i.conflictStatus == 'CONFLICT_DETECTED');
    final conflictCount = plan.items.where((i) => i.conflictStatus == 'CONFLICT_DETECTED').length;
    final isApproved = plan.status == 'APPROVED';

    Color statusColor;
    switch (plan.status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        break;
      case 'EDITED':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasConflict ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          width: hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    plan.subjectName ?? 'Subject',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      plan.status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (hasConflict)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(
                            '$conflictCount Timetable Clash(es)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            '0 Conflicts (Verified Available)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${plan.className ?? "Class"} ${plan.sectionName ?? ""} • Teacher: ${plan.teacherName ?? "Faculty"} • Reason: ${plan.reason}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),

          // Pacing Metrics Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('Current Completion', '${plan.currentCompletion.toStringAsFixed(0)}%'),
                _buildStatPill('Target Exam Date', plan.targetCompletionDate ?? 'N/A'),
                _buildStatPill('Shifted Forecast', plan.forecastCompletionDate ?? 'N/A'),
                _buildStatPill('Recovered Forecast', plan.newForecastDate ?? 'N/A', isHighlight: true),
                _buildStatPill('Recovery Slots', '${plan.items.length} proposed'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Phased Catch-up: ${plan.items.length} slot(s) scheduled across working calendar days.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(isApproved ? 'View Plan Details' : 'Open Recovery Editor & Validator'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => RecoveryPlanEditorDialog(
                      initialPlan: plan,
                      onPlanUpdated: () {
                        ref.invalidate(adminRecoveryPlansProvider((
                          schoolId: widget.schoolId,
                          academicYearId: widget.academicYearId,
                          status: _statusFilter,
                        )));
                        ref.invalidate(academicHeatmapProvider((
                          schoolId: widget.schoolId,
                          academicYearId: widget.academicYearId,
                        )));
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, String val, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
