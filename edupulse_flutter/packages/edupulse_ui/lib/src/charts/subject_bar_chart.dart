import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class SubjectScore {
  final String subject;
  final double score; // percentage, e.g. 86.0
  final double? maxMarks;
  final double? scoredMarks;
  final String? grade;
  final bool strong;
  final bool needsSupport;

  const SubjectScore({
    required this.subject,
    required this.score,
    this.maxMarks,
    this.scoredMarks,
    this.grade,
    this.strong = false,
    this.needsSupport = false,
  });
}

/// Subject Bar Chart matching the approved Google AI Studio design.
/// Displays ranked subject scores, benchmark indicator, distinction chips, and color alerts.
class SubjectBarChart extends StatelessWidget {
  final String title;
  final String? timeframe;
  final List<SubjectScore> data;
  final double benchmark;

  const SubjectBarChart({
    super.key,
    this.title = 'Subject Performance Comparison',
    this.timeframe,
    required this.data,
    this.benchmark = 75.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No subject marks available.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    // Sort descending by score
    final sorted = List<SubjectScore>.from(data)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate900,
                      ),
                    ),
                    if (timeframe != null)
                      Text(
                        timeframe!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Benchmark: ${benchmark.toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bars
          ...sorted.map((item) {
            final isWeak = item.score < 60 || item.needsSupport;
            final isAboveBenchmark = item.score >= benchmark;

            Color barColor;
            if (isWeak) {
              barColor = EduPulseTheme.roseDanger;
            } else if (isAboveBenchmark) {
              barColor = EduPulseTheme.primaryTeal;
            } else {
              barColor = EduPulseTheme.amberWarning;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.subject,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : EduPulseTheme.slate800,
                            ),
                          ),
                          if (item.strong) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium_rounded,
                                      size: 11,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Top',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (item.needsSupport) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 11,
                                      color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239)),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Support',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.grade != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.grade!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: isDark ? Colors.white : EduPulseTheme.slate700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${item.score.toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white : EduPulseTheme.slate900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Progress Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (item.score / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Legend
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                ),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildLegendItem('≥${benchmark.toInt()}% Strong', EduPulseTheme.primaryTeal, isDark),
                _buildLegendItem('60-${benchmark.toInt() - 1}% Average', EduPulseTheme.amberWarning, isDark),
                _buildLegendItem('<60% Support', EduPulseTheme.roseDanger, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
