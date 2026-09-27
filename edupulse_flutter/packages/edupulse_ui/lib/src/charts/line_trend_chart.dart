import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

enum TrendDirection {
  improving,
  stable,
  declining,
}

class TrendDataPoint {
  final String label;
  final double value;
  final String? subtext;
  final String? tooltipDetail;

  const TrendDataPoint({
    required this.label,
    required this.value,
    this.subtext,
    this.tooltipDetail,
  });
}

/// Time-series Line Trend Chart matching the approved Google AI Studio design.
/// Features target threshold line, gradient area under curve, trend badge, and tap callout.
class LineTrendChart extends StatefulWidget {
  final String? title;
  final String? timeframe;
  final List<TrendDataPoint> data;
  final double? threshold;
  final String thresholdLabel;
  final String unit;
  final double height;
  final TrendDirection? trend;
  final String? trendNote;
  final Color? color;

  const LineTrendChart({
    super.key,
    this.title,
    this.timeframe,
    required this.data,
    this.threshold,
    this.thresholdLabel = '75% Target',
    this.unit = '%',
    this.height = 180,
    this.trend,
    this.trendNote,
    this.color,
  });

  @override
  State<LineTrendChart> createState() => _LineTrendChartState();
}

class _LineTrendChartState extends State<LineTrendChart> {
  TrendDataPoint? _selectedPoint;

  TrendDirection _computeTrend() {
    if (widget.trend != null) return widget.trend!;
    if (widget.data.length < 2) return TrendDirection.stable;
    final first = widget.data.first.value;
    final last = widget.data.last.value;
    if (last > first) return TrendDirection.improving;
    if (last < first) return TrendDirection.declining;
    return TrendDirection.stable;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = widget.color ?? EduPulseTheme.primaryTeal;

    if (widget.data.isEmpty) {
      return Container(
        height: widget.height,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No trend records available for this period.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    final computedTrend = _computeTrend();
    Color trendBadgeBg;
    Color trendBadgeFg;
    IconData trendIcon;
    String trendText;

    switch (computedTrend) {
      case TrendDirection.improving:
        trendBadgeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        trendBadgeFg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
        trendIcon = Icons.trending_up_rounded;
        trendText = 'Improving';
        break;
      case TrendDirection.declining:
        trendBadgeBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFF1F2);
        trendBadgeFg = isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239);
        trendIcon = Icons.trending_down_rounded;
        trendText = 'Declining';
        break;
      case TrendDirection.stable:
        trendBadgeBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        trendBadgeFg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
        trendIcon = Icons.remove_rounded;
        trendText = 'Stable';
        break;
    }

    final values = widget.data.map((d) => d.value).toList();
    if (widget.threshold != null) values.add(widget.threshold!);
    final minVal = (values.reduce((a, b) => a < b ? a : b) - 10).clamp(0.0, 100.0);
    final maxVal = (values.reduce((a, b) => a > b ? a : b) + 10).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title != null)
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: trendBadgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(trendIcon, size: 14, color: trendBadgeFg),
                  const SizedBox(width: 4),
                  Text(
                    trendText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trendBadgeFg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Chart Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final width = constraints.maxWidth;
                        const padLeft = 32.0;
                        const padRight = 20.0;
                        final chartW = width - padLeft - padRight;
                        final dx = details.localPosition.dx;

                        if (widget.data.length > 1) {
                          final step = chartW / (widget.data.length - 1);
                          final index = ((dx - padLeft + step / 2) / step).floor();
                          if (index >= 0 && index < widget.data.length) {
                            setState(() {
                              _selectedPoint = _selectedPoint == widget.data[index]
                                  ? null
                                  : widget.data[index];
                            });
                          }
                        }
                      },
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, widget.height),
                        painter: _LineTrendChartPainter(
                          data: widget.data,
                          threshold: widget.threshold,
                          thresholdLabel: widget.thresholdLabel,
                          minVal: minVal,
                          maxVal: maxVal,
                          unit: widget.unit,
                          lineColor: lineColor,
                          selectedPoint: _selectedPoint,
                          isDark: isDark,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Tooltip / Callout Detail
              if (_selectedPoint != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: EduPulseTheme.primaryTeal),
                          const SizedBox(width: 6),
                          Text(
                            '${_selectedPoint!.label}: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : EduPulseTheme.slate900,
                            ),
                          ),
                          Text(
                            _selectedPoint!.tooltipDetail ??
                                '${_selectedPoint!.value.toInt()}${widget.unit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPoint!.subtext != null)
                        Text(
                          _selectedPoint!.subtext!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        if (widget.trendNote != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.trendNote!,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LineTrendChartPainter extends CustomPainter {
  final List<TrendDataPoint> data;
  final double? threshold;
  final String thresholdLabel;
  final double minVal;
  final double maxVal;
  final String unit;
  final Color lineColor;
  final TrendDataPoint? selectedPoint;
  final bool isDark;

  const _LineTrendChartPainter({
    required this.data,
    required this.threshold,
    required this.thresholdLabel,
    required this.minVal,
    required this.maxVal,
    required this.unit,
    required this.lineColor,
    required this.selectedPoint,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 32.0;
    const padRight = 20.0;
    const padTop = 20.0;
    const padBottom = 26.0;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final valRange = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    double getX(int index) {
      if (data.length <= 1) return padLeft + chartW / 2;
      return padLeft + (index / (data.length - 1)) * chartW;
    }

    double getY(double val) {
      final norm = (val - minVal) / valRange;
      return padTop + chartH - (norm * chartH);
    }

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
      ..strokeWidth = 1;

    final gridRatios = [0.0, 0.5, 1.0];
    for (final ratio in gridRatios) {
      final y = padTop + chartH * ratio;
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);

      final gridVal = (maxVal - ratio * valRange).round();
      final textSpan = TextSpan(
        text: '$gridVal$unit',
        style: TextStyle(
          fontSize: 9,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          fontFamily: 'monospace',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(padLeft - textPainter.width - 4, y - 6));
    }

    // Draw threshold line if present
    if (threshold != null && threshold! >= minVal && threshold! <= maxVal) {
      final threshY = getY(threshold!);
      final threshPaint = Paint()
        ..color = EduPulseTheme.roseDanger
        ..strokeWidth = 1.5;

      // Draw dashed line
      double startX = padLeft;
      while (startX < size.width - padRight) {
        canvas.drawLine(
          Offset(startX, threshY),
          Offset(startX + 4, threshY),
          threshPaint,
        );
        startX += 8;
      }

      final labelSpan = TextSpan(
        text: thresholdLabel,
        style: const TextStyle(
          fontSize: 9,
          color: EduPulseTheme.roseDanger,
          fontWeight: FontWeight.bold,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(size.width - padRight - labelPainter.width, threshY - 14),
      );
    }

    // Build path
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      points.add(Offset(getX(i), getY(data[i].value)));
    }

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Gradient fill under path
    final areaPath = Path.from(path)
      ..lineTo(points.last.dx, padTop + chartH)
      ..lineTo(points.first.dx, padTop + chartH)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withAlpha(isDark ? 60 : 40),
          lineColor.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(padLeft, padTop, chartW, chartH));
    canvas.drawPath(areaPath, areaPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw dots and x-axis labels
    for (int i = 0; i < data.length; i++) {
      final pt = points[i];
      final isSelected = selectedPoint?.label == data[i].label;

      // Circle node
      final circlePaint = Paint()
        ..color = isDark ? EduPulseTheme.slate900 : Colors.white
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 2.0;

      canvas.drawCircle(pt, isSelected ? 6.0 : 4.0, circlePaint);
      canvas.drawCircle(pt, isSelected ? 6.0 : 4.0, borderPaint);

      // Score text above node
      final valSpan = TextSpan(
        text: '${data[i].value.toInt()}$unit',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isSelected
              ? EduPulseTheme.primaryTeal
              : (isDark ? const Color(0xFFCBD5E1) : EduPulseTheme.slate700),
          fontFamily: 'monospace',
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - 16));

      // Label below chart
      final lblSpan = TextSpan(
        text: data[i].label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.white : EduPulseTheme.slate900)
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      );
      final lblPainter = TextPainter(
        text: lblSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      lblPainter.paint(
        canvas,
        Offset(pt.dx - lblPainter.width / 2, padTop + chartH + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineTrendChartPainter oldDelegate) {
    return oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isDark != isDark;
  }
}
