import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../providers/tenant_providers.dart';
import '../../data/models/tenant_models.dart';

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tenantsListProvider.notifier).fetchTenants();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddTenantDialog() {
    showDialog(
      context: context,
      builder: (context) => const TenantFormDialog(),
    );
  }

  void _showEditTenantDialog(TenantDto tenant) {
    showDialog(
      context: context,
      builder: (context) => TenantFormDialog(tenant: tenant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tenantsListProvider);
    final selectedTenantId = ref.watch(selectedTenantIdProvider);
    
    // Register the watcher provider to ensure it listens to active tenant switching
    ref.watch(tenantSetupWatcherProvider);

    final filteredTenants = state.tenants.where((t) {
      final query = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(query) ||
          t.code.toLowerCase().contains(query) ||
          t.subdomain.toLowerCase().contains(query) ||
          t.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Management'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Tenant'),
            onPressed: _showAddTenantDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tenants by name, code, subdomain, or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                });
              },
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            // Tenants Table
            Expanded(
              child: state.isLoading && state.tenants.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTenants.isEmpty
                      ? const Center(child: Text('No tenants found.'))
                      : Card(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Code')),
                                  DataColumn(label: Text('Subdomain')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredTenants.map((tenant) {
                                  final isActive = selectedTenantId == tenant.id;
                                  return DataRow(
                                    selected: isActive,
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            Text(
                                              tenant.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.check_circle,
                                                color: theme.colorScheme.primary,
                                                size: 16,
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(tenant.code)),
                                      DataCell(Text(tenant.subdomain)),
                                      DataCell(Text(tenant.email)),
                                      DataCell(Text(tenant.phone ?? 'N/A')),
                                      DataCell(
                                        Chip(
                                          label: Text(tenant.status),
                                          backgroundColor: tenant.status == 'ACTIVE'
                                              ? Colors.green.shade100
                                              : Colors.red.shade100,
                                          labelStyle: TextStyle(
                                            color: tenant.status == 'ACTIVE'
                                                ? Colors.green.shade800
                                                : Colors.red.shade800,
                                            fontSize: 12,
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined),
                                              tooltip: 'Edit Tenant',
                                              onPressed: () => _showEditTenantDialog(tenant),
                                            ),
                                            Switch(
                                              value: tenant.status == 'ACTIVE',
                                              onChanged: (val) {
                                                ref
                                                    .read(tenantsListProvider.notifier)
                                                    .toggleTenantStatus(tenant);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isActive
                                                    ? theme.colorScheme.secondaryContainer
                                                    : theme.colorScheme.primary,
                                                foregroundColor: isActive
                                                    ? theme.colorScheme.onSecondaryContainer
                                                    : theme.colorScheme.onPrimary,
                                              ),
                                              onPressed: isActive
                                                  ? null
                                                  : () {
                                                      ref.read(selectedTenantIdProvider.notifier).state =
                                                          tenant.id;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Switched to Tenant: ${tenant.name}'),
                                                        ),
                                                      );
                                                    },
                                              child: Text(isActive ? 'Active' : 'Select'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantFormDialog extends ConsumerStatefulWidget {
  final TenantDto? tenant;

  const TenantFormDialog({super.key, this.tenant});

  @override
  ConsumerState<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends ConsumerState<TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _codeController;
  late final TextEditingController _subdomainController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _panController;
  late final TextEditingController _gstinController;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name ?? '');
    _displayNameController = TextEditingController(text: widget.tenant?.displayName ?? '');
    _codeController = TextEditingController(text: widget.tenant?.code ?? '');
    _subdomainController = TextEditingController(text: widget.tenant?.subdomain ?? '');
    _emailController = TextEditingController(text: widget.tenant?.email ?? '');
    _phoneController = TextEditingController(text: widget.tenant?.phone ?? '');
    _websiteController = TextEditingController(text: widget.tenant?.website ?? '');
    _addressController = TextEditingController(text: widget.tenant?.address ?? '');
    _cityController = TextEditingController(text: widget.tenant?.city ?? '');
    _stateController = TextEditingController(text: widget.tenant?.state ?? '');
    _postalCodeController = TextEditingController(text: widget.tenant?.postalCode ?? '');
    _panController = TextEditingController(text: widget.tenant?.pan ?? '');
    _gstinController = TextEditingController(text: widget.tenant?.gstin ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    _subdomainController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _panController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(tenantsListProvider.notifier);
    final isEdit = widget.tenant != null;

    final result = isEdit
        ? await notifier.updateTenant(
            widget.tenant!.id,
            TenantUpdateRequest(
              name: _nameController.text.trim(),
              displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
              code: _codeController.text.trim(),
              subdomain: _subdomainController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
              address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
              city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
              state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
              postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
              pan: _panController.text.trim().isEmpty ? null : _panController.text.trim(),
              gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
            ),
          )
        : await notifier.createTenant(
            TenantCreateRequest(
              name: _nameController.text.trim(),
              displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
              code: _codeController.text.trim(),
              subdomain: _subdomainController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
              address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
              city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
              state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
              postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
              pan: _panController.text.trim().isEmpty ? null : _panController.text.trim(),
              gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
            ),
          );

    result.when(
      onSuccess: (_) {
        Navigator.pop(context);
      },
      onFailure: (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tenant != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? 'Edit Tenant' : 'Create Tenant'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                // Legal Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tenant Legal Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Legal name is required' : null,
                ),
                const SizedBox(height: 8),
                // Display Name
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 8),
                // Code
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Unique Code * (lowercase, numbers, dashes)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Code is required';
                    if (!RegExp(r'^[a-z0-9\-]+$').hasMatch(v.trim())) {
                      return 'Invalid format. Must be lowercase alphanumeric and dashes only.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Subdomain
                TextFormField(
                  controller: _subdomainController,
                  decoration: const InputDecoration(labelText: 'Unique Subdomain * (lowercase, numbers, dashes)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Subdomain is required';
                    if (!RegExp(r'^[a-z0-9\-]+$').hasMatch(v.trim())) {
                      return 'Invalid format. Must be lowercase alphanumeric and dashes only.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Indian Contact Number (Optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^(?:\+91|0)?[6-9]\d{9}$').hasMatch(v.trim())) {
                      return 'Enter a valid 10-digit Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Website
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(labelText: 'Website URL'),
                ),
                const SizedBox(height: 8),
                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                // City
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 8),
                // State
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: 'State (e.g. Telangana)'),
                ),
                const SizedBox(height: 8),
                // Postal Code
                TextFormField(
                  controller: _postalCodeController,
                  decoration: const InputDecoration(labelText: 'Indian PIN Code (Optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v.trim())) {
                      return 'Enter a valid 6-digit Indian PIN Code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // PAN
                TextFormField(
                  controller: _panController,
                  decoration: const InputDecoration(labelText: 'Indian PAN Number (Optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v.trim().toUpperCase())) {
                      return 'Enter a valid 10-character Indian PAN number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // GSTIN
                TextFormField(
                  controller: _gstinController,
                  decoration: const InputDecoration(labelText: 'Indian GSTIN (Optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(v.trim().toUpperCase())) {
                      return 'Enter a valid 15-character Indian GSTIN';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save Changes' : 'Create Tenant'),
        ),
      ],
    );
  }
}
