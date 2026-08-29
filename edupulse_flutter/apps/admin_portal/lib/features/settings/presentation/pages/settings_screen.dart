import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _boardController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _postalCodeController;
  late TextEditingController _logoUrlController;

  // Report Card signature / title / display toggles
  late TextEditingController _repTitleController;
  late TextEditingController _repLogoUrlController;
  late TextEditingController _principalSigController;
  late TextEditingController _classTeacherSigController;
  bool _showAttendanceChart = true;
  bool _showAiInsights = true;

  // Promotion policy
  late TextEditingController _minAttendanceController;
  late TextEditingController _minOverallController;
  late TextEditingController _maxFailedSubjectsController;

  // Academic settings
  String? _currentAyId;

  // Notification preference switches
  bool _tenantInApp = true;
  bool _tenantPush = true;
  bool _tenantWhatsapp = true;
  bool _tenantSms = false;
  bool _tenantEmail = false;

  // WhatsApp configuration controllers
  bool _whatsappEnabled = false;
  String _whatsappProviderVal = 'mock';
  late TextEditingController _waPhoneIdController;
  late TextEditingController _waAccountIdController;
  late TextEditingController _waUrlController;
  late TextEditingController _waTokenController;

  // Loaded cache
  bool _isInitialized = false;
  bool _notifIsInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _boardController = TextEditingController();
    _phoneController = TextEditingController();
    _websiteController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _postalCodeController = TextEditingController();
    _logoUrlController = TextEditingController();

    _repTitleController = TextEditingController();
    _repLogoUrlController = TextEditingController();
    _principalSigController = TextEditingController();
    _classTeacherSigController = TextEditingController();

    _minAttendanceController = TextEditingController();
    _minOverallController = TextEditingController();
    _maxFailedSubjectsController = TextEditingController();

    _waPhoneIdController = TextEditingController();
    _waAccountIdController = TextEditingController();
    _waUrlController = TextEditingController();
    _waTokenController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _boardController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _logoUrlController.dispose();

    _repTitleController.dispose();
    _repLogoUrlController.dispose();
    _principalSigController.dispose();
    _classTeacherSigController.dispose();

    _minAttendanceController.dispose();
    _minOverallController.dispose();
    _maxFailedSubjectsController.dispose();

    _waPhoneIdController.dispose();
    _waAccountIdController.dispose();
    _waUrlController.dispose();
    _waTokenController.dispose();
    super.dispose();
  }

  void _initializeValues(dynamic school) {
    if (_isInitialized) return;
    
    _nameController.text = school.name;
    _codeController.text = school.code;
    _boardController.text = school.board;
    _phoneController.text = school.phone ?? '';
    _websiteController.text = school.website ?? '';
    _addressController.text = school.address ?? '';
    _cityController.text = school.city ?? '';
    _stateController.text = school.state ?? '';
    _countryController.text = school.country ?? '';
    _postalCodeController.text = school.postalCode ?? '';
    _logoUrlController.text = school.logoUrl ?? '';

    // Settings nested fields
    final settings = school.settings ?? <String, dynamic>{};
    
    // 1. Report Card config
    final rcSettings = settings['report_card_settings'] as Map<String, dynamic>? ?? {};
    _repTitleController.text = rcSettings['title'] ?? 'Delhi Public School';
    _repLogoUrlController.text = rcSettings['logo_url'] ?? '';
    _principalSigController.text = rcSettings['principal_signature_label'] ?? 'Principal Signature';
    _classTeacherSigController.text = rcSettings['class_teacher_signature_label'] ?? 'Class Teacher Signature';
    _showAttendanceChart = rcSettings['show_attendance'] ?? true;
    _showAiInsights = rcSettings['show_ai_insights'] ?? true;

    // 2. Promotion Policy
    final promPolicy = settings['promotion_policy'] as Map<String, dynamic>? ?? {};
    _minAttendanceController.text = '${promPolicy['min_attendance_pct'] ?? 75.0}';
    _minOverallController.text = '${promPolicy['min_overall_pct'] ?? 35.0}';
    _maxFailedSubjectsController.text = '${promPolicy['max_failed_subjects'] ?? 0}';

    // 3. Current Academic Year
    _currentAyId = settings['current_academic_year_id'] ?? '';

    _isInitialized = true;
  }

  void _initializeNotifValues(Map<String, dynamic> tenantPrefs) {
    if (_notifIsInitialized) return;
    
    final policy = tenantPrefs['notification_policy'] as Map<String, dynamic>? ?? {};
    final defaultChannels = policy['general'] as List<dynamic>? ?? ['IN_APP', 'PUSH', 'WHATSAPP'];
    _tenantInApp = defaultChannels.contains('IN_APP');
    _tenantPush = defaultChannels.contains('PUSH');
    _tenantWhatsapp = defaultChannels.contains('WHATSAPP');
    _tenantSms = defaultChannels.contains('SMS');
    _tenantEmail = defaultChannels.contains('EMAIL');

    _whatsappEnabled = tenantPrefs['whatsapp_enabled'] as bool? ?? false;
    _whatsappProviderVal = tenantPrefs['whatsapp_provider'] as String? ?? 'mock';
    _waPhoneIdController.text = tenantPrefs['whatsapp_phone_number_id'] as String? ?? '';
    _waAccountIdController.text = tenantPrefs['whatsapp_business_account_id'] as String? ?? '';
    _waUrlController.text = tenantPrefs['whatsapp_api_url'] as String? ?? '';
    _waTokenController.text = tenantPrefs['whatsapp_access_token'] != null ? '********' : '';
    
    _notifIsInitialized = true;
  }

  Future<void> _handleSave(dynamic school) async {
    if (!_formKey.currentState!.validate()) return;

    final existingSettings = school.settings ?? <String, dynamic>{};
    final updatedSettings = Map<String, dynamic>.from(existingSettings);
    
    updatedSettings['report_card_settings'] = {
      'title': _repTitleController.text.trim(),
      'logo_url': _repLogoUrlController.text.trim(),
      'principal_signature_label': _principalSigController.text.trim(),
      'class_teacher_signature_label': _classTeacherSigController.text.trim(),
      'show_attendance': _showAttendanceChart,
      'show_ai_insights': _showAiInsights,
    };

    updatedSettings['promotion_policy'] = {
      'min_attendance_pct': double.tryParse(_minAttendanceController.text.trim()) ?? 75.0,
      'min_overall_pct': double.tryParse(_minOverallController.text.trim()) ?? 35.0,
      'max_failed_subjects': int.tryParse(_maxFailedSubjectsController.text.trim()) ?? 0,
    };

    if (_currentAyId != null && _currentAyId!.isNotEmpty) {
      updatedSettings['current_academic_year_id'] = _currentAyId;
    }

    final success = await ref.read(settingsNotifierProvider.notifier).updateSchool(
      schoolId: school.id,
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      board: _boardController.text.trim(),
      schoolType: school.schoolType,
      email: school.email,
      phone: _phoneController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      regionState: _stateController.text.trim(),
      country: _countryController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      logoUrl: _logoUrlController.text.trim(),
      settings: updatedSettings,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      } else {
        final err = ref.read(settingsNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSaveNotifSettings() async {
    final defaultChannels = <String>[];
    if (_tenantInApp) defaultChannels.add('IN_APP');
    if (_tenantPush) defaultChannels.add('PUSH');
    if (_tenantWhatsapp) defaultChannels.add('WHATSAPP');
    if (_tenantSms) defaultChannels.add('SMS');
    if (_tenantEmail) defaultChannels.add('EMAIL');

    final payload = {
      'notification_policy': {
        'general': defaultChannels,
        'attendance': defaultChannels,
        'homework': defaultChannels,
        'marks': defaultChannels,
        'report_card': defaultChannels,
        'announcement': defaultChannels,
        'event': defaultChannels,
        'fee': defaultChannels,
      },
      'whatsapp_enabled': _whatsappEnabled,
      'whatsapp_provider': _whatsappProviderVal,
      'whatsapp_phone_number_id': _waPhoneIdController.text.trim(),
      'whatsapp_business_account_id': _waAccountIdController.text.trim(),
      'whatsapp_api_url': _waUrlController.text.trim(),
    };

    if (_waTokenController.text.isNotEmpty && _waTokenController.text != '********') {
      payload['whatsapp_access_token'] = _waTokenController.text.trim();
    }

    final success = await ref.read(settingsNotifierProvider.notifier).updateTenantPreferences(payload);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings updated successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update notification settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(currentSchoolProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final tenantPrefsAsync = ref.watch(tenantPreferencesProvider);
    final deliveriesAsync = ref.watch(deliveriesProvider);
    
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() {
          _isInitialized = false;
          _notifIsInitialized = false;
        });
        ref.invalidate(currentSchoolProvider);
        ref.invalidate(tenantPreferencesProvider);
        ref.invalidate(deliveriesProvider);
      }
    });

    if (selectedSchoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('School Settings')),
        body: const Center(child: Text('Please select a school context first.')),
      );
    }

    final ayState = ref.watch(academicYearsProvider(selectedSchoolId));
    Future.microtask(() {
      if (ayState.years.isEmpty && !ayState.isLoading) {
        ref.read(academicYearsProvider(selectedSchoolId).notifier).fetchYears();
      }
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings & Policies'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'General Setup & Policies'),
              Tab(icon: Icon(Icons.notifications_active), text: 'Notification Engine Logs & config'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: GENERAL SETUP ---
            schoolAsync.when(
              data: (school) {
                _initializeValues(school);

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('School Profile & Identity', Icons.business, theme),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(labelText: 'School Name *'),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _codeController,
                                        decoration: const InputDecoration(labelText: 'School Code *'),
                                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _boardController,
                                        decoration: const InputDecoration(labelText: 'Affiliation Board *'),
                                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _websiteController,
                                        decoration: const InputDecoration(labelText: 'Official Website'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _logoUrlController,
                                  decoration: const InputDecoration(labelText: 'Branding Logo URL'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader('Address & Location', Icons.location_on, theme),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(labelText: 'Street Address'),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _cityController,
                                        decoration: const InputDecoration(labelText: 'City'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _stateController,
                                        decoration: const InputDecoration(labelText: 'State/Region'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _countryController,
                                        decoration: const InputDecoration(labelText: 'Country'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _postalCodeController,
                                        decoration: const InputDecoration(labelText: 'Postal Code / PIN'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader('Academic Setup', Icons.calendar_month, theme),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Academic Year Context', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _currentAyId != null && _currentAyId!.isNotEmpty ? _currentAyId : null,
                                  decoration: const InputDecoration(labelText: 'Current Year'),
                                  onChanged: (val) {
                                    setState(() {
                                      _currentAyId = val;
                                    });
                                  },
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('-- Not Specified --'),
                                    ),
                                    ...ayState.years.map((y) => DropdownMenuItem<String>(
                                      value: y.id,
                                      child: Text(y.name),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader('Report Card Generator Settings', Icons.badge, theme),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _repTitleController,
                                  decoration: const InputDecoration(labelText: 'PDF Title Heading'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _repLogoUrlController,
                                  decoration: const InputDecoration(labelText: 'Report Card Logo URL Override'),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _principalSigController,
                                        decoration: const InputDecoration(labelText: 'Principal Signature Label'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _classTeacherSigController,
                                        decoration: const InputDecoration(labelText: 'Class Teacher Signature Label'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SwitchListTile(
                                  title: const Text('Show Attendance Chart'),
                                  subtitle: const Text('Render the attendance analytics block on student report cards'),
                                  value: _showAttendanceChart,
                                  onChanged: (val) {
                                    setState(() {
                                      _showAttendanceChart = val;
                                    });
                                  },
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show AI Insights'),
                                  subtitle: const Text('Include the AI Predictive Performance and weakness pattern insights block'),
                                  value: _showAiInsights,
                                  onChanged: (val) {
                                    setState(() {
                                      _showAiInsights = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader('Student Promotion Requirements', Icons.trending_up, theme),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.md),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _minAttendanceController,
                                  decoration: const InputDecoration(labelText: 'Minimum Attendance Percentage required (%)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _minOverallController,
                                  decoration: const InputDecoration(labelText: 'Minimum Overall Mark percentage needed (%)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _maxFailedSubjectsController,
                                  decoration: const InputDecoration(labelText: 'Maximum Allowed Failed Subjects'),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            onPressed: () => _handleSave(school),
                            icon: const Icon(Icons.check),
                            label: const Text('Save Configuration Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading configuration settings: $err')),
            ),

            // --- TAB 2: NOTIFICATION ENGINE & LOGS ---
            tenantPrefsAsync.when(
              data: (tenantPrefs) {
                _initializeNotifValues(tenantPrefs);

                return SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Default Communication Channels', Icons.alt_route_rounded, theme),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('In-App Notification Feed'),
                                subtitle: const Text('Deliver alerts to internal user inbox feed'),
                                value: _tenantInApp,
                                onChanged: (val) => setState(() => _tenantInApp = val),
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text('Mobile Push (Firebase FCM)'),
                                subtitle: const Text('Dispatch push notifications to registered devices'),
                                value: _tenantPush,
                                onChanged: (val) => setState(() => _tenantPush = val),
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text('WhatsApp Integration Alerts'),
                                subtitle: const Text('Broadcast template notifications via WhatsApp messaging service'),
                                value: _tenantWhatsapp,
                                onChanged: (val) => setState(() => _tenantWhatsapp = val),
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text('SMS / Text Messaging'),
                                subtitle: const Text('Forward events via SMS gateway provider'),
                                value: _tenantSms,
                                onChanged: (val) => setState(() => _tenantSms = val),
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text('Email Dispatches'),
                                subtitle: const Text('Forward notification newsletters to email inbox'),
                                value: _tenantEmail,
                                onChanged: (val) => setState(() => _tenantEmail = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('WhatsApp Gateway Credentials', Icons.chat_bubble, theme),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Enable WhatsApp Engine'),
                                subtitle: const Text('Control tenant-wide active WhatsApp scheduling queue'),
                                value: _whatsappEnabled,
                                onChanged: (val) => setState(() => _whatsappEnabled = val),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _whatsappProviderVal,
                                decoration: const InputDecoration(labelText: 'WhatsApp Provider Service'),
                                items: const [
                                  DropdownMenuItem(value: 'mock', child: Text('Mock WhatsApp Provider (Testing)')),
                                  DropdownMenuItem(value: 'meta', child: Text('Meta Graph Cloud API (Production)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _whatsappProviderVal = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _waUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Base Graph API URL',
                                  hintText: 'https://graph.facebook.com/v21.0',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _waPhoneIdController,
                                decoration: const InputDecoration(labelText: 'Phone Number ID'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _waAccountIdController,
                                decoration: const InputDecoration(labelText: 'WABA Business Account ID'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _waTokenController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Meta Access Token (Secure Password Field)',
                                  hintText: 'Enter permanent developer system access token',
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _handleSaveNotifSettings,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save Notification config', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Centralized Delivery Logs & History', Icons.history, theme),
                      const SizedBox(height: 12),
                      deliveriesAsync.when(
                        data: (logs) {
                          if (logs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('No notification delivery records found.'),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: logs.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final d = logs[index];
                              final createTime = DateFormat('dd MMM, hh:mm a').format(d.createdAt.toLocal());
                              
                              Color statusColor = Colors.grey;
                              IconData statusIcon = Icons.help_outline;
                              if (d.status == 'SENT' || d.status == 'DELIVERED') {
                                statusColor = Colors.green;
                                statusIcon = Icons.check_circle_outline;
                              } else if (d.status == 'PENDING' || d.status == 'QUEUED') {
                                statusColor = Colors.orange;
                                statusIcon = Icons.hourglass_empty;
                              } else if (d.status == 'FAILED') {
                                statusColor = Colors.red;
                                statusIcon = Icons.error_outline;
                              }

                              return ListTile(
                                leading: Icon(
                                  d.channel == 'WHATSAPP'
                                      ? Icons.chat_outlined
                                      : d.channel == 'PUSH'
                                          ? Icons.phonelink_ring_outlined
                                          : Icons.mail_outline_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text('${d.channel} delivery to User ${d.recipientId.substring(0, 8)}...'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Provider: ${d.provider} | Created: $createTime'),
                                    if (d.errorMessage != null)
                                      Text(
                                        'Error: ${d.errorMessage}',
                                        style: const TextStyle(color: Colors.red, fontSize: 11),
                                      ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 12, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        d.status,
                                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Error loading delivery logs: $err'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading notification settings: $err')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
