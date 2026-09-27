import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/academic_planning_models.dart';
import '../providers/academic_planning_providers.dart';

class AcademicHeatmapWidget extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;

  const AcademicHeatmapWidget({
    super.key,
    required this.schoolId,
    required this.academicYearId,
  });

  @override
  ConsumerState<AcademicHeatmapWidget> createState() => _AcademicHeatmapWidgetState();
}

class _AcademicHeatmapWidgetState extends ConsumerState<AcademicHeatmapWidget> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(academicHeatmapProvider((
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
    )));

    return heatmapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text('Failed to load academic heatmap: $err'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(academicHeatmapProvider((
                schoolId: widget.schoolId,
                academicYearId: widget.academicYearId,
              ))),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (heatmap) {
        final summary = heatmap.summary;
        final totalSubjects = (summary['total_subjects'] as num?)?.toInt() ?? heatmap.cells.length;
        final onTrackCount = (summary['on_track'] as num?)?.toInt() ?? 0;
        final atRiskCount = (summary['at_risk'] as num?)?.toInt() ?? 0;
        final delayedCount = (summary['delayed'] as num?)?.toInt() ?? 0;
        final avgCompletion = (summary['average_completion'] as num?)?.toDouble() ?? 0.0;

        final filteredCells = heatmap.cells.where((c) {
          if (_selectedFilter == 'ON_TRACK') return c.status == 'ON_TRACK';
          if (_selectedFilter == 'AT_RISK') return c.status == 'AT_RISK';
          if (_selectedFilter == 'DELAYED') return c.status == 'DELAYED';
          if (_selectedFilter == 'RECOVERY') return c.recoveryPlanActive;
          return true;
        }).toList();

        final Map<String, List<AcademicHeatmapCellModel>> groupedByClass = {};
        for (final cell in filteredCells) {
          final key = cell.className.isNotEmpty ? cell.className : 'Class';
          groupedByClass.putIfAbsent(key, () => []).add(cell);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.grid_on_rounded, color: Color(0xFF0F766E), size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Institutional Academic Progress Matrix (Class × Subject)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Text(
                            '${avgCompletion.toStringAsFixed(1)}% Institutional Completion',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (avgCompletion / 100.0).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildKpiPill('$totalSubjects Subjects Tracked', const Color(0xFF0F766E)),
                        _buildKpiPill('$onTrackCount On Track', const Color(0xFF10B981)),
                        _buildKpiPill('$atRiskCount At Risk', const Color(0xFFF59E0B)),
                        _buildKpiPill('$delayedCount Delayed', const Color(0xFFEF4444)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Filter Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Subjects'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ON_TRACK', 'On Track'),
                    const SizedBox(width: 8),
                    _buildFilterChip('AT_RISK', 'At Risk'),
                    const SizedBox(width: 8),
                    _buildFilterChip('DELAYED', 'Delayed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('RECOVERY', 'Recovery Plan Active'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Grid of Classes
              if (filteredCells.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Text('No subjects match filter: $_selectedFilter', style: const TextStyle(color: Colors.grey)),
                )
              else
                ...groupedByClass.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('${entry.value.length} subjects', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = constraints.maxWidth > 900 ? (constraints.maxWidth - 32) / 3 : (constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: entry.value.map((cell) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: _buildHeatmapCard(cell),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
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
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildHeatmapCard(AcademicHeatmapCellModel cell) {
    Color statusColor;
    String statusText;
    switch (cell.status.toUpperCase()) {
      case 'ON_TRACK':
        statusColor = const Color(0xFF10B981);
        statusText = 'On Track';
        break;
      case 'AT_RISK':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'At Risk (+${cell.delayDays}d)';
        break;
      case 'DELAYED':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Delayed (+${cell.delayDays}d)';
        break;
      case 'AHEAD':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'Ahead';
        break;
      default:
        statusColor = Colors.grey;
        statusText = cell.status;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCellDrilldownDialog(context, cell),
        borderRadius: BorderRadius.circular(8),
        hoverColor: statusColor.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cell.recoveryPlanActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
              width: cell.recoveryPlanActive ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cell.subjectName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Faculty: ${cell.teacherName ?? "Assigned Teacher"}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${cell.completionPercentage.toStringAsFixed(1)}% completed', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  if (cell.forecastDate != null)
                    Text('Exp: ${cell.forecastDate}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (cell.completionPercentage / 100.0).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5,
                ),
              ),
              if (cell.recoveryPlanActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 11, color: Color(0xFF0F766E)),
                      SizedBox(width: 4),
                      Text('Recovery Plan Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCellDrilldownDialog(BuildContext context, AcademicHeatmapCellModel cell) {
    Color statusColor;
    String statusText;
    switch (cell.status.toUpperCase()) {
      case 'ON_TRACK':
        statusColor = const Color(0xFF10B981);
        statusText = 'On Track';
        break;
      case 'AT_RISK':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'At Risk (+${cell.delayDays}d delay)';
        break;
      case 'DELAYED':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Delayed (+${cell.delayDays}d delay)';
        break;
      case 'AHEAD':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'Ahead of Schedule';
        break;
      default:
        statusColor = Colors.grey;
        statusText = cell.status;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.analytics_outlined, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cell.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Pacing & Coverage Details',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDrilldownRow('Status', statusText, statusColor, isBadge: true),
              const SizedBox(height: 10),
              _buildDrilldownRow('Assigned Faculty', cell.teacherName ?? 'Assigned Teacher', null),
              const SizedBox(height: 10),
              _buildDrilldownRow('Completion', '${cell.completionPercentage.toStringAsFixed(1)}%', null),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (cell.completionPercentage / 100.0).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              _buildDrilldownRow('Projected Completion', cell.forecastDate ?? 'On Schedule', null),
              const SizedBox(height: 10),
              _buildDrilldownRow('Delay Offset', '${cell.delayDays} day(s)', cell.delayDays > 0 ? Colors.red.shade700 : Colors.green.shade700),
              const SizedBox(height: 10),
              _buildDrilldownRow('Recovery Status', cell.recoveryPlanActive ? 'Active Automated Plan' : 'No Intervention Required', cell.recoveryPlanActive ? const Color(0xFF0F766E) : null),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrilldownRow(String label, String value, Color? color, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        if (isBadge && color != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
      ],
    );
  }
}
