// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../providers/settings_provider.dart';
import 'location_preview_dialog.dart';

class SchoolGeofenceCard extends ConsumerStatefulWidget {
  final SchoolDto school;

  const SchoolGeofenceCard({
    super.key,
    required this.school,
  });

  @override
  ConsumerState<SchoolGeofenceCard> createState() => _SchoolGeofenceCardState();
}

class _SchoolGeofenceCardState extends ConsumerState<SchoolGeofenceCard> {
  final _formKey = GlobalKey<FormState>();

  late bool _geofencingEnabled;
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late TextEditingController _radiusController;

  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.school.latitude?.toString() ?? '');
    _lonController = TextEditingController(text: widget.school.longitude?.toString() ?? '');
    _radiusController = TextEditingController(
      text: (widget.school.geofenceRadiusMeters ?? 100).toString(),
    );
    _geofencingEnabled = widget.school.isGeofencingEnabled;
  }

  @override
  void didUpdateWidget(covariant SchoolGeofenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.school.id != widget.school.id ||
        oldWidget.school.latitude != widget.school.latitude ||
        oldWidget.school.longitude != widget.school.longitude ||
        oldWidget.school.geofenceRadiusMeters != widget.school.geofenceRadiusMeters) {
      _latController.text = widget.school.latitude?.toString() ?? '';
      _lonController.text = widget.school.longitude?.toString() ?? '';
      _radiusController.text = (widget.school.geofenceRadiusMeters ?? 100).toString();
      _geofencingEnabled = widget.school.isGeofencingEnabled;
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled on this device.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied. Please enable in browser/device settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (mounted) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lonController.text = position.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location coordinates retrieved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error retrieving device location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _handlePreviewLocation() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    final rad = int.tryParse(_radiusController.text.trim()) ?? 100;

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide valid Latitude and Longitude coordinates to preview.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => LocationPreviewDialog(
        schoolName: widget.school.name,
        latitude: lat,
        longitude: lon,
        radiusMeters: rad,
        isEnabled: _geofencingEnabled,
      ),
    );
  }

  Future<void> _handleSaveGeofence() async {
    if (!_formKey.currentState!.validate()) return;

    final latText = _latController.text.trim();
    final lonText = _lonController.text.trim();
    final radText = _radiusController.text.trim();

    final double? lat = latText.isNotEmpty ? double.tryParse(latText) : null;
    final double? lon = lonText.isNotEmpty ? double.tryParse(lonText) : null;
    final int rad = int.tryParse(radText) ?? 100;

    if (_geofencingEnabled && (lat == null || lon == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Both Latitude and Longitude are required when geofencing is enabled.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if ((lat == null) != (lon == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latitude and Longitude must both be provided, or both be empty.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref.read(settingsNotifierProvider.notifier).updateSchoolGeofence(
      schoolId: widget.school.id,
      enabled: _geofencingEnabled,
      latitude: lat,
      longitude: lon,
      radiusMeters: rad,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School geofence settings saved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = ref.read(settingsNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save geofence settings: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final isConfigured = _latController.text.trim().isNotEmpty && _lonController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            Icon(Icons.radar, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '📍 School Geofence & Attendance Location',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main Configuration Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Geofencing Enable Toggle
                  SwitchListTile.adaptive(
                    key: const Key('geofence_enable_switch'),
                    value: _geofencingEnabled,
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Enable School Geofencing',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Restrict location-sensitive attendance actions to the configured school radius.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _geofencingEnabled = val;
                      });
                    },
                  ),
                  const Divider(height: 24),

                  // 5. Current Status Indicator
                  _buildStatusIndicator(theme, isConfigured),
                  const SizedBox(height: 16),

                  // 2. Responsive Coordinates (Latitude & Longitude)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      if (isNarrow) {
                        return Column(
                          children: [
                            _buildLatitudeField(),
                            const SizedBox(height: 12),
                            _buildLongitudeField(),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildLatitudeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildLongitudeField()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Geofence Radius
                  TextFormField(
                    key: const Key('geofence_radius_field'),
                    controller: _radiusController,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Radius',
                      suffixText: 'meters',
                      hintText: 'e.g. 200',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.circle_outlined, size: 20),
                      helperText: 'Acceptable radius boundary for teacher check-in/check-out (1 - 10,000m)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Radius is required';
                      final val = int.tryParse(v.trim());
                      if (val == null) return 'Must be a valid integer';
                      if (val <= 0) return 'Radius must be positive';
                      if (val > 10000) return 'Maximum allowed radius is 10,000 meters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. Location Actions & Save Bar (responsive Wrap layout)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('use_current_location_btn'),
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: Text(_isLocating ? 'Locating...' : 'Use Current Location'),
                            onPressed: _isLocating ? null : _handleUseCurrentLocation,
                          ),
                          OutlinedButton.icon(
                            key: const Key('preview_location_btn'),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Preview Location'),
                            onPressed: _handlePreviewLocation,
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        key: const Key('save_geofence_settings_btn'),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save Geofence Settings'),
                        onPressed: _isSaving ? null : _handleSaveGeofence,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, bool isConfigured) {
    if (isConfigured) {
      final lat = _latController.text.trim();
      final lon = _lonController.text.trim();
      final rad = _radiusController.text.trim();

      return Container(
        key: const Key('geofence_status_configured'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ Geofence Configured',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Latitude: $lat | Longitude: $lon | Radius: ${rad}m',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green[900]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        key: const Key('geofence_status_not_configured'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber[800], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠ Location Not Configured',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Staff attendance validation requires school latitude and longitude coordinates.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber[900]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLatitudeField() {
    return TextFormField(
      key: const Key('geofence_latitude_field'),
      controller: _latController,
      decoration: const InputDecoration(
        labelText: 'Latitude',
        hintText: 'e.g. 17.4485',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.explore_outlined, size: 20),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final valStr = v?.trim();
        if (valStr == null || valStr.isEmpty) {
          if (_geofencingEnabled) return 'Latitude is required when geofencing is enabled';
          if (_lonController.text.trim().isNotEmpty) return 'Required when Longitude is provided';
          return null;
        }
        final val = double.tryParse(valStr);
        if (val == null) return 'Must be a valid number';
        if (val < -90.0 || val > 90.0) return 'Must be between -90 and +90';
        return null;
      },
    );
  }

  Widget _buildLongitudeField() {
    return TextFormField(
      key: const Key('geofence_longitude_field'),
      controller: _lonController,
      decoration: const InputDecoration(
        labelText: 'Longitude',
        hintText: 'e.g. 78.3741',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.explore_outlined, size: 20),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final valStr = v?.trim();
        if (valStr == null || valStr.isEmpty) {
          if (_geofencingEnabled) return 'Longitude is required when geofencing is enabled';
          if (_latController.text.trim().isNotEmpty) return 'Required when Latitude is provided';
          return null;
        }
        final val = double.tryParse(valStr);
        if (val == null) return 'Must be a valid number';
        if (val < -180.0 || val > 180.0) return 'Must be between -180 and +180';
        return null;
      },
    );
  }
}
