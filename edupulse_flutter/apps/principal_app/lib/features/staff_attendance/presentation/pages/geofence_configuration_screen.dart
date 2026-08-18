import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/staff_attendance_provider.dart';

class GeofenceConfigurationScreen extends ConsumerStatefulWidget {
  const GeofenceConfigurationScreen({super.key});

  @override
  ConsumerState<GeofenceConfigurationScreen> createState() => _GeofenceConfigurationScreenState();
}

class _GeofenceConfigurationScreenState extends ConsumerState<GeofenceConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _radiusController;
  
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _radiusController = TextEditingController();
    
    // Fetch configuration on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schoolGeofenceStateProvider.notifier).fetchGeofence();
    });
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _populateFields(SchoolGeofenceState state) {
    if (state.geofence != null) {
      _latitudeController.text = state.geofence!.latitude?.toString() ?? '';
      _longitudeController.text = state.geofence!.longitude?.toString() ?? '';
      _radiusController.text = state.geofence!.geofenceRadiusMeters.toString();
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final double lat = double.parse(_latitudeController.text);
      final double lng = double.parse(_longitudeController.text);
      final int radius = int.parse(_radiusController.text);

      final success = await ref.read(schoolGeofenceStateProvider.notifier).updateGeofence(
        latitude: lat,
        longitude: lng,
        radius: radius,
      );

      if (success && mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School geofence updated successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(schoolGeofenceStateProvider);

    // Populate values if not editing and form values are empty
    if (!_isEditing && _latitudeController.text.isEmpty && state.geofence != null) {
      _populateFields(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Settings'),
        actions: [
          if (state.geofence != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _populateFields(state);
                });
              },
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                // Info Box
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'School Geofence Configuration',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure the physical coordinates and check-in radius limit for staff members to verify attendance check-ins. Coordinates and radius must be exact.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.md),

                // Error Feedback
                if (state.errorMessage != null) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                ],

                // Success Feedback
                if (state.updateSuccessMessage != null && !_isEditing) ...[
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Text(
                        state.updateSuccessMessage!,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                ],

                // Lat Long Section
                Text(
                  'Geographic Location',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        enabled: _isEditing && !state.isUpdating,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g. 17.4482',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius.md),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final lat = double.tryParse(value);
                          if (lat == null) {
                            return 'Invalid number';
                          }
                          if (lat < -90 || lat > 90) {
                            return 'Must be -90 to 90';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        enabled: _isEditing && !state.isUpdating,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g. 78.3741',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius.md),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final lng = double.tryParse(value);
                          if (lng == null) {
                            return 'Invalid number';
                          }
                          if (lng < -180 || lng > 180) {
                            return 'Must be -180 to 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),

                // Radius Section
                Text(
                  'Check-In Radius (Meters)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.sm),

                TextFormField(
                  controller: _radiusController,
                  enabled: _isEditing && !state.isUpdating,
                  decoration: InputDecoration(
                    labelText: 'Allowed Radius',
                    hintText: 'e.g. 150',
                    suffixText: 'meters',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius.md),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Radius is required';
                    }
                    final radiusVal = int.tryParse(value);
                    if (radiusVal == null) {
                      return 'Must be a valid integer';
                    }
                    if (radiusVal <= 0) {
                      return 'Must be greater than 0';
                    }
                    if (radiusVal > 10000) {
                      return 'Maximum allowed radius is 10,000 meters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing.xl),

                // Actions Button Row
                if (_isEditing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: state.isUpdating
                            ? null
                            : () {
                                setState(() {
                                  _isEditing = false;
                                  _populateFields(state);
                                });
                              },
                        child: const Text('Cancel'),
                      ),
                      SizedBox(width: spacing.md),
                      ElevatedButton(
                        onPressed: state.isUpdating ? null : _saveForm,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
                        ),
                        child: state.isUpdating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Configuration'),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Text(
                      'Editing is disabled. Tap edit in top right to modify settings.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
