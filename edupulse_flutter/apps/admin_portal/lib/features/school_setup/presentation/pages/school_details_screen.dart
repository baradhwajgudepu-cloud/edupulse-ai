import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/school_setup_providers.dart';

class SchoolDetailsScreen extends ConsumerStatefulWidget {
  final String? schoolId;
  const SchoolDetailsScreen({super.key, this.schoolId});

  @override
  ConsumerState<SchoolDetailsScreen> createState() => _SchoolDetailsScreenState();
}

class _SchoolDetailsScreenState extends ConsumerState<SchoolDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  int _entityVersion = 1;

  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _principalNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _udiseCodeController = TextEditingController();

  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');

  String _selectedBoard = 'CBSE';
  String _selectedType = 'HIGH_SCHOOL';
  String _selectedStatus = 'ACTIVE';

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.schoolId != null && widget.schoolId != 'new';
    _latitudeController.addListener(_onGeofenceCoordsChanged);
    _longitudeController.addListener(_onGeofenceCoordsChanged);
    if (_isEditMode) {
      Future.microtask(() => _loadSchoolDetails());
    }
  }

  void _onGeofenceCoordsChanged() {
    setState(() {});
  }

  Future<void> _loadSchoolDetails() async {
    final school = await ref.read(schoolDetailProvider(widget.schoolId!).future);
    setState(() {
      _nameController.text = school.name;
      _displayNameController.text = school.displayName ?? '';
      _codeController.text = school.code;
      _emailController.text = school.email;
      _phoneController.text = school.phone ?? '';
      _websiteController.text = school.website ?? '';
      _principalNameController.text = school.principalName ?? '';
      _addressController.text = school.address ?? '';
      _cityController.text = school.city ?? '';
      _stateController.text = school.state ?? '';
      _postalCodeController.text = school.postalCode ?? '';
      _logoUrlController.text = school.logoUrl ?? '';
      _udiseCodeController.text = school.udiseCode ?? '';
      _selectedBoard = school.board;
      _selectedType = school.schoolType;
      _selectedStatus = school.status;
      _entityVersion = school.version;
      _latitudeController.text = school.latitude?.toString() ?? '';
      _longitudeController.text = school.longitude?.toString() ?? '';
      _radiusController.text = school.geofenceRadiusMeters?.toString() ?? '100';
    });
  }

  @override
  void dispose() {
    _latitudeController.removeListener(_onGeofenceCoordsChanged);
    _longitudeController.removeListener(_onGeofenceCoordsChanged);
    _nameController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _principalNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _logoUrlController.dispose();
    _udiseCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.'), backgroundColor: Colors.orange),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.'), backgroundColor: Colors.orange),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.'), backgroundColor: Colors.orange),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching current location...'), duration: Duration(seconds: 1)),
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveGeofence() async {
    if (widget.schoolId == null || widget.schoolId == 'new') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register the campus details first.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    final double? lat = double.tryParse(_latitudeController.text);
    final double? lon = double.tryParse(_longitudeController.text);
    final int rad = int.tryParse(_radiusController.text) ?? 100;

    if ((lat == null) != (lon == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude and Longitude must both be provided, or both be empty.'), backgroundColor: Colors.red),
      );
      return;
    }

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'PUT',
          path: '/schools/${widget.schoolId}',
          data: {
            'latitude': lat,
            'longitude': lon,
            'geofence_radius_meters': rad,
          },
          successMsg: 'Campus geofence updated successfully',
        );

    if (success) {
      ref.invalidate(schoolsListProvider);
      ref.invalidate(schoolDetailProvider(widget.schoolId!));
      _loadSchoolDetails();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildGeofenceStatus(ThemeData theme) {
    final bool isConfigured = _latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty;
    if (isConfigured) {
      return Row(
        key: const Key('geofence_status_configured'),
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text(
            'Geofence configured',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      return Row(
        key: const Key('geofence_status_not_configured'),
        children: [
          Icon(Icons.warning_amber_outlined, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Text(
            'Geofence not configured',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.amber[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final latStr = _latitudeController.text;
    final lonStr = _longitudeController.text;
    if ((latStr.isEmpty) != (lonStr.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude and Longitude must both be provided, or both be empty.'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = {
      'name': _nameController.text,
      'display_name': _displayNameController.text.isEmpty ? null : _displayNameController.text,
      'code': _codeController.text,
      'board': _selectedBoard,
      'school_type': _selectedType,
      'email': _emailController.text,
      'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
      'website': _websiteController.text.isEmpty ? null : _websiteController.text,
      'principal_name': _principalNameController.text.isEmpty ? null : _principalNameController.text,
      'address': _addressController.text.isEmpty ? null : _addressController.text,
      'city': _cityController.text.isEmpty ? null : _cityController.text,
      'state': _stateController.text.isEmpty ? null : _stateController.text,
      'postal_code': _postalCodeController.text.isEmpty ? null : _postalCodeController.text,
      'logo_url': _logoUrlController.text.isEmpty ? null : _logoUrlController.text,
      'udise_code': _udiseCodeController.text.isEmpty ? null : _udiseCodeController.text,
      'status': _selectedStatus,
      'latitude': latStr.isEmpty ? null : double.tryParse(latStr),
      'longitude': lonStr.isEmpty ? null : double.tryParse(lonStr),
      'geofence_radius_meters': _radiusController.text.isEmpty ? 100 : int.tryParse(_radiusController.text) ?? 100,
    };

    final path = _isEditMode ? '/schools/${widget.schoolId}' : '/schools';
    final method = _isEditMode ? 'PUT' : 'POST';

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: method,
          path: path,
          data: data,
          successMsg: _isEditMode ? 'Campus details updated' : 'Campus registered successfully',
        );

    if (success) {
      ref.invalidate(schoolsListProvider);
      if (_isEditMode) {
        ref.invalidate(schoolDetailProvider(widget.schoolId!));
      }
      context.pop();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
      if (actionState.isConflict) {
        _loadSchoolDetails(); // Force reload to fetch latest database details
      }
    }
  }

  Future<void> _deleteSchool() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campus?'),
        content: const Text(
            'This performs a soft-delete on the campus. Children entities will remain mapped but inaccessible.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(setupActionProvider.notifier).execute(
          method: 'DELETE',
          path: '/schools/${widget.schoolId}',
          successMsg: 'School soft-deleted successfully',
        );

    if (success) {
      ref.invalidate(schoolsListProvider);
      context.pop();
    } else {
      final actionState = ref.read(setupActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.errorMessage ?? 'Delete failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(setupActionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Campus Settings' : 'New Campus Setup'),
        actions: [
          if (_isEditMode)
            IconButton(
              tooltip: 'Delete campus',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: actionState.isLoading ? null : _deleteSchool,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode) ...[
                Text('Optimistic Lock Version: $_entityVersion', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('General Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Campus Name*', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(labelText: 'Campus Code*', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _udiseCodeController,
                              decoration: const InputDecoration(labelText: 'UDISE Registry Code (11-digit)', border: OutlineInputBorder()),
                              validator: (v) => v != null && v.isNotEmpty && v.length != 11 ? 'Must be 11 digits' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedBoard,
                              decoration: const InputDecoration(labelText: 'Affiliation Board*', border: OutlineInputBorder()),
                              items: ['CBSE', 'ICSE', 'SSC', 'STATE', 'IB', 'IGCSE', 'CAMBRIDGE', 'OTHER']
                                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedBoard = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(labelText: 'School Type*', border: OutlineInputBorder()),
                              items: ['PRIMARY', 'HIGH_SCHOOL', 'JR_COLLEGE', 'DEGREE_COLLEGE', 'UNIVERSITY', 'OTHER']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedType = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact & Location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Contact Email*', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(labelText: 'Website Link', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _principalNameController,
                        decoration: const InputDecoration(labelText: 'Principal Full Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address Details', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(labelText: 'Postal Code', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status*', border: OutlineInputBorder()),
                        items: ['ACTIVE', 'INACTIVE', 'SUSPENDED']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _logoUrlController,
                        decoration: const InputDecoration(labelText: 'Logo Asset Link', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Attendance Geofence',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Status Widget
                      _buildGeofenceStatus(theme),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('latitude_field'),
                              controller: _latitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                                hintText: 'e.g. 17.4485',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  if (_longitudeController.text.isNotEmpty) return 'Required';
                                  return null;
                                }
                                final val = double.tryParse(v);
                                if (val == null) return 'Must be a number';
                                if (val < -90 || val > 90) return 'Must be between -90 and 90';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('longitude_field'),
                              controller: _longitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                                hintText: 'e.g. 78.3741',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  if (_latitudeController.text.isNotEmpty) return 'Required';
                                  return null;
                                }
                                final val = double.tryParse(v);
                                if (val == null) return 'Must be a number';
                                if (val < -180 || val > 180) return 'Must be between -180 and 180';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('radius_field'),
                              controller: _radiusController,
                              decoration: const InputDecoration(
                                labelText: 'Radius (meters)*',
                                border: OutlineInputBorder(),
                                hintText: '100',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final val = int.tryParse(v);
                                if (val == null) return 'Must be a whole number';
                                if (val <= 0) return 'Must be positive';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('use_current_location_button'),
                              icon: const Icon(Icons.my_location),
                              label: const Text('Use Current Location'),
                              onPressed: _useCurrentLocation,
                            ),
                          ),
                        ],
                      ),
                      if (_isEditMode) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            key: const Key('save_geofence_button'),
                            onPressed: actionState.isLoading ? null : _saveGeofence,
                            child: const Text('Save Geofence'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: actionState.isLoading ? null : _saveForm,
                    child: actionState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Campus'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
