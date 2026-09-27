import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LocationPreviewDialog extends StatelessWidget {
  final String schoolName;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isEnabled;

  const LocationPreviewDialog({
    super.key,
    required this.schoolName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 750.0);
    final insetPadding = EdgeInsets.symmetric(
      horizontal: screenW < 600 ? 12 : 24,
      vertical: screenH < 600 ? 12 : 24,
    );

    return Dialog(
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenW < 600 ? 16.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Geofence Preview',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          schoolName,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 20),

              // Radar schematic visualizer
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _GeofenceRadarPainter(
                          color: isEnabled ? theme.colorScheme.primary : Colors.grey,
                          isDark: isDark,
                        ),
                      ),
                      // Center Pin
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school,
                            color: isEnabled ? theme.colorScheme.primary : Colors.grey,
                            size: 28,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black87 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Text(
                              '${radiusMeters}m Geofence',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? theme.colorScheme.primary : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isEnabled ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled ? Colors.green.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEnabled ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 18,
                      color: isEnabled ? Colors.green[700] : Colors.amber[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEnabled
                            ? 'Geofence Active: Staff attendance is restricted to this radius.'
                            : 'Geofence Disabled: Attendance is recorded without perimeter restriction.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isEnabled ? Colors.green[800] : Colors.amber[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Coordinates Grid
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinateTile(
                      context,
                      label: 'Latitude',
                      value: latitude.toStringAsFixed(6),
                      icon: Icons.explore_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCoordinateTile(
                      context,
                      label: 'Longitude',
                      value: longitude.toStringAsFixed(6),
                      icon: Icons.explore_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCoordinateTile(
                      context,
                      label: 'Radius',
                      value: '$radiusMeters m',
                      icon: Icons.radar,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Coordinates'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$latitude, $longitude'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coordinates copied to clipboard')),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GeofenceRadarPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  _GeofenceRadarPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width / 2, size.height / 2) * 0.85;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Crosshairs
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), gridPaint);

    // Concentric rings
    for (int i = 1; i <= 3; i++) {
      final r = maxRadius * (i / 3);
      canvas.drawCircle(center, r, gridPaint);
    }

    // Geofence fill area
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, fillPaint);

    // Geofence perimeter ring
    final perimeterPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, maxRadius, perimeterPaint);
  }

  @override
  bool shouldRepaint(covariant _GeofenceRadarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}
