import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class DonutSegment {
  final String id;
  final String label;
  final double value;
  final Color color;
  final String? sublabel;

  const DonutSegment({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });
}

/// Donut chart matching the approved Google AI Studio design.
/// Supports center metric summary, interactive slice highlighting, and bottom legend grid.
class DonutChart extends StatefulWidget {
  final String? title;
  final String? timeframe;
  final List<DonutSegment> data;
  final String? centerLabel;
  final String? centerSublabel;
  final double size;
  final double thickness;
  final String unit;
  final bool showLegend;

  const DonutChart({
    super.key,
    this.title,
    this.timeframe,
    required this.data,
    this.centerLabel,
    this.centerSublabel,
    this.size = 180,
    this.thickness = 22,
    this.unit = '',
    this.showLegend = true,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  DonutSegment? _selectedSegment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = widget.data.fold<double>(0, (sum, item) => sum + item.value);

    if (total == 0 || widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No data available to display chart.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    final activeSegment = _selectedSegment;
    final displayCenterValue = activeSegment != null
        ? '${activeSegment.value.toInt()}${widget.unit}'
        : widget.centerLabel ?? '${((widget.data.first.value / total) * 100).round()}%';
    final displayCenterSublabel = activeSegment != null
        ? activeSegment.label
        : widget.centerSublabel ?? widget.data.first.label;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate900,
                        ),
                      ),
                      if (widget.timeframe != null)
                        Text(
                          widget.timeframe!,
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
                if (activeSegment != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${activeSegment.label}: ${activeSegment.value.toInt()}${widget.unit} (${((activeSegment.value / total) * 100).round()}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : EduPulseTheme.slate800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
        ],

        // Visual Donut with Center Text
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutChartPainter(
                  data: widget.data,
                  total: total,
                  thickness: widget.thickness,
                  selectedId: activeSegment?.id,
                  trackColor: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCenterValue,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      displayCenterSublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Accessible Legend Grid Below
        if (widget.showLegend) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.data.map((seg) {
              final pct = ((seg.value / total) * 100).round();
              final isSelected = activeSegment?.id == seg.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSegment = isSelected ? null : seg;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100)
                        : (isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8))
                          : (isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: seg.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              seg.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : EduPulseTheme.slate800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${seg.value.toInt()}${widget.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : EduPulseTheme.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSegment> data;
  final double total;
  final double thickness;
  final String? selectedId;
  final Color trackColor;

  const _DonutChartPainter({
    required this.data,
    required this.total,
    required this.thickness,
    required this.selectedId,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - thickness) / 2;

    // Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw segments starting from -90 deg (12 o'clock)
    double startAngle = -math.pi / 2;

    for (final seg in data) {
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      final isSelected = selectedId == seg.id;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? thickness + 4 : thickness
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.total != total ||
        oldDelegate.data != data;
  }
}

