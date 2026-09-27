import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

/// Insufficient Data State matching the approved Google AI Studio design.
/// Displayed when historical data points are too few to compute meaningful trends.
class InsufficientDataState extends StatelessWidget {
  final String title;
  final String message;
  final String? timeframe;
  final double height;

  const InsufficientDataState({
    super.key,
    this.title = 'Not enough data',
    this.message = 'More academic or attendance records are needed to generate a reliable trend.',
    this.timeframe,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800.withAlpha(120) : EduPulseTheme.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate300,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.analytics_outlined,
                size: 20,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: EduPulseTheme.amberWarning,
                ),
                const SizedBox(width: 4),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white : EduPulseTheme.slate800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (timeframe != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate700 : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                  ),
                ),
                child: Text(
                  'Period: $timeframe',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
