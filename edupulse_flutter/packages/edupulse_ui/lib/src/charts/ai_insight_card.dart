import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../common/status_badge.dart';
import 'line_trend_chart.dart';

/// AI Insight Card matching the approved Google AI Studio design.
/// Structures data analysis into: Data -> Analysis -> Insight -> Action.
class AIInsightCard extends StatelessWidget {
  final TrendDirection trend;
  final String headline;
  final String insight;
  final String timeframe;
  final List<String> strongHighlights;
  final List<String> supportHighlights;
  final String? actionRecommendation;

  const AIInsightCard({
    super.key,
    required this.trend,
    required this.headline,
    required this.insight,
    this.timeframe = 'Based on the last 90 days',
    this.strongHighlights = const [],
    this.supportHighlights = const [],
    this.actionRecommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF134E4A).withAlpha(60) : const Color(0xFFF0FDFA);
    final borderColor = isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4);

    StatusBadgeVariant badgeVariant;
    String trendLabel;
    IconData trendIcon;

    switch (trend) {
      case TrendDirection.improving:
        badgeVariant = StatusBadgeVariant.success;
        trendLabel = 'Improving';
        trendIcon = Icons.trending_up_rounded;
        break;
      case TrendDirection.declining:
        badgeVariant = StatusBadgeVariant.error;
        trendLabel = 'Declining';
        trendIcon = Icons.trending_down_rounded;
        break;
      case TrendDirection.stable:
        badgeVariant = StatusBadgeVariant.info;
        trendLabel = 'Stable';
        trendIcon = Icons.remove_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: EduPulseTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI DATA ANALYSIS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF115E59),
                            ),
                          ),
                          Text(
                            timeframe,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF99F6E4) : const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: trendLabel,
                variant: badgeVariant,
                size: StatusBadgeSize.sm,
                icon: Icon(trendIcon, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Core insight
          Text(
            headline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : EduPulseTheme.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
            ),
          ),

          // Highlights
          if (strongHighlights.isNotEmpty || supportHighlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF0F766E).withAlpha(100) : const Color(0xFFCCFBF1),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (strongHighlights.isNotEmpty) ...[
                    Text(
                      'STRONG AREAS:',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: strongHighlights.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withAlpha(150) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (supportHighlights.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'NEEDS SUPPORT:',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: supportHighlights.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF7F1D1D).withAlpha(150) : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3),
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Recommendation
          if (actionRecommendation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF0F766E) : const Color(0xFFCCFBF1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendation: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF5EEAD4) : EduPulseTheme.primaryTealDark,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      actionRecommendation!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
