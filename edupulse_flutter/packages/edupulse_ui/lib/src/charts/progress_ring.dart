import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

/// Progress Ring matching the approved Google AI Studio design.
/// Used for compact circular score, fee collection, and attendance percentage displays.
class ProgressRing extends StatelessWidget {
  final double value; // 0 to 100
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? bgColor;
  final String? label;
  final String? sublabel;
  final Widget? icon;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 110,
    this.strokeWidth = 9,
    this.color,
    this.bgColor,
    this.label,
    this.sublabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = value.clamp(0.0, 100.0);
    final activeColor = color ?? EduPulseTheme.primaryTeal;
    final trackColor = bgColor ?? (isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _ProgressRingPainter(
                  value: clamped,
                  strokeWidth: strokeWidth,
                  color: activeColor,
                  bgColor: trackColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${clamped.toInt()}%',
                    style: TextStyle(
                      fontSize: size > 90 ? 18 : 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                      height: 1.0,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        sublabel!,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color color;
  final Color bgColor;

  const _ProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (-90 degrees is top)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / 100.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
