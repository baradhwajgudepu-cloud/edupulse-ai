import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../providers/fees_provider.dart';
import '../../data/models/fee_models.dart';

class FeesDashboardScreen extends ConsumerStatefulWidget {
  const FeesDashboardScreen({super.key});

  @override
  ConsumerState<FeesDashboardScreen> createState() => _FeesDashboardScreenState();
}

class _FeesDashboardScreenState extends ConsumerState<FeesDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(feesDashboardProvider(schoolId).notifier).fetchDashboardData();
        ref.read(feeTypesProvider.notifier).fetchTypes();
        ref.read(scholarshipsProvider(schoolId).notifier).fetchScholarships();
        ref.read(feeStructuresProvider(schoolId).notifier).fetchStructures();
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);

    // Watch school context changes and reload
    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        _refreshAll();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fee Management')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Please select a school campus first using the top selector bar to configure fee management.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Fee Types'),
            Tab(icon: Icon(Icons.card_membership_outlined), text: 'Scholarships'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Structures'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(schoolId: schoolId),
          _FeeTypesTab(),
          _ScholarshipsTab(schoolId: schoolId),
          _FeeStructuresTab(schoolId: schoolId),
        ],
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD TAB
// ==========================================
class _DashboardTab extends ConsumerWidget {
  final String schoolId;
  const _DashboardTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(feesDashboardProvider(schoolId));
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    if (dashboardState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dashboardState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${dashboardState.error}', style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(feesDashboardProvider(schoolId).notifier).fetchDashboardData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (schoolId.isNotEmpty) {
      ref.watch(classesProvider(schoolId));
    }

    final m = dashboardState.metrics;
    if (m == null) {
      return const Center(child: Text('No metrics data loaded.'));
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of Primary Stats
          if (isMobile) ...[
            _buildStatCard(theme, 'Today\'s Collection', currencyFormatter.format(m.todayCollection), Icons.today, Colors.blue),
            const SizedBox(height: 12),
            _buildStatCard(theme, 'Monthly Collection', currencyFormatter.format(m.monthCollection), Icons.calendar_month, Colors.green),
            const SizedBox(height: 12),
            _buildStatCard(theme, 'Outstanding Dues', currencyFormatter.format(m.pendingDues), Icons.warning_amber_rounded, Colors.orange, onTap: () => context.push(AppRoutes.feesOutstanding)),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildStatCard(theme, 'Today\'s Collection', currencyFormatter.format(m.todayCollection), Icons.today, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(theme, 'Monthly Collection', currencyFormatter.format(m.monthCollection), Icons.calendar_month, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(theme, 'Outstanding Dues', currencyFormatter.format(m.pendingDues), Icons.warning_amber_rounded, Colors.orange, onTap: () => context.push(AppRoutes.feesOutstanding))),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Quick Actions Row
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.feesAssign),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Assign Fee to Student',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.feesLedger),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Student Fee Ledgers',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Collection Progress & Defaulters Count
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
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
                        Text('Overall Collection Velocity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${m.collectionPercentage.toStringAsFixed(1)}%',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Icon(Icons.donut_large, color: theme.colorScheme.primary, size: 28),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (m.collectionPercentage / 100).clamp(0.0, 1.0),
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          color: theme.colorScheme.primary,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => context.push('${AppRoutes.feesOutstanding}?only_defaulters=true'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Late Defaulters', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${m.defaultersCount}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              Icon(Icons.people_outline, color: theme.colorScheme.error, size: 28),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Students with past due unpaid invoices.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // AI Collection Prediction
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'AI Collections Prediction & Forecasts',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!dashboardState.isAiAvailable || dashboardState.analytics == null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'AI insights engine is currently offline or unreachable.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Predicted Collection Velocity (Next 30 Days)',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(dashboardState.analytics!.predictedCollectionNext30Days),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Historical 30-Day Trend Velocity Graph Projection',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...dashboardState.analytics!.historicalTrend.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(currencyFormatter.format(entry.value), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Outstanding Dues by Class
          Text('Outstanding Dues by Class', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (m.topOutstandingClasses.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No outstanding class dues reported.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: m.topOutstandingClasses.length,
              itemBuilder: (context, index) {
                final cls = m.topOutstandingClasses[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () {
                      final classesState = ref.read(classesProvider(schoolId));
                      String? matchedClassId;
                      for (final c in classesState.classes) {
                        if (c.name == cls.className) {
                          matchedClassId = c.id;
                          break;
                        }
                      }
                      if (matchedClassId != null) {
                        context.push('${AppRoutes.feesOutstanding}?class_id=$matchedClassId');
                      } else {
                        context.push(AppRoutes.feesOutstanding);
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(Icons.school, color: theme.colorScheme.error, size: 20),
                    ),
                    title: Text(cls.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Class/Grade Dues'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyFormatter.format(cls.outstandingAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. FEE TYPES CONFIGURATION TAB
// ==========================================
class _FeeTypesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feeTypesProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.types.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTypeDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Fee Type'),
      ),
      body: state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(feeTypesProvider.notifier).fetchTypes(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : state.types.isEmpty
              ? const Center(child: Text('No fee types defined yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.types.length,
                  itemBuilder: (context, index) {
                    final type = state.types[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.category, color: theme.colorScheme.primary),
                        ),
                        title: Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Code: ${type.code}${type.description != null ? " • ${type.description}" : ""}'),
                        trailing: type.isSystem
                            ? const Tooltip(
                                message: 'System Fee types cannot be deleted',
                                child: Icon(Icons.lock_outline, color: Colors.grey),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDeleteType(context, ref, type),
                              ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showCreateTypeDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String code = '';
    String description = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create Fee Type'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g., Tuition Fee'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Name is required';
                      if (val.trim().length > 100) return 'Name max 100 characters';
                      return null;
                    },
                    onSaved: (val) => name = val!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Code', hintText: 'e.g., TUITION'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Code is required';
                      if (val.trim().length > 50) return 'Code max 50 characters';
                      return null;
                    },
                    onSaved: (val) => code = val!.trim().toUpperCase(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    maxLines: 2,
                    validator: (val) {
                      if (val != null && val.trim().length > 500) return 'Description max 500 characters';
                      return null;
                    },
                    onSaved: (val) => description = val?.trim() ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final navigator = Navigator.of(ctx);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final success = await ref.read(feeTypesProvider.notifier).createType(
                        name,
                        code,
                        description.isEmpty ? null : description,
                      );
                  if (success) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Fee Type created successfully.')),
                    );
                  } else {
                    final err = ref.read(feeTypesProvider).error ?? 'Failed to create fee type.';
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteType(BuildContext context, WidgetRef ref, FeeType type) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Fee Type'),
          content: Text('Are you sure you want to delete "${type.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final success = await ref.read(feeTypesProvider.notifier).deleteType(type.id);
                navigator.pop();
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Fee Type deleted successfully.')),
                  );
                } else {
                  final err = ref.read(feeTypesProvider).error ?? 'Failed to delete fee type.';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. SCHOLARSHIPS TAB
// ==========================================
class _ScholarshipsTab extends ConsumerWidget {
  final String schoolId;
  const _ScholarshipsTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scholarshipsProvider(schoolId));
    final theme = Theme.of(context);

    if (state.isLoading && state.scholarships.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateScholarshipDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Scholarship'),
      ),
      body: state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(scholarshipsProvider(schoolId).notifier).fetchScholarships(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : state.scholarships.isEmpty
              ? const Center(child: Text('No scholarships or concessions defined yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.scholarships.length,
                  itemBuilder: (context, index) {
                    final scholarship = state.scholarships[index];
                    final isPercent = scholarship.concessionType == ConcessionType.PERCENTAGE;
                    final valueString = isPercent ? '${scholarship.value.toStringAsFixed(0)}%' : '₹${scholarship.value.toStringAsFixed(0)}';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(Icons.card_membership, color: Colors.orange.shade800),
                        ),
                        title: Text(scholarship.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${scholarship.concessionType.name} Concession • ${scholarship.description ?? ""}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                valueString,
                                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDeleteScholarship(context, ref, scholarship),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showCreateScholarshipDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    ConcessionType type = ConcessionType.FIXED;
    double value = 0.0;
    String description = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Create Scholarship/Concession'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Concession Name', hintText: 'e.g., Sibling Discount'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Name is required';
                          if (val.trim().length > 100) return 'Name max 100 characters';
                          return null;
                        },
                        onSaved: (val) => name = val!.trim(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ConcessionType>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: ConcessionType.values.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t.name));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => type = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Concession Value',
                          suffixText: type == ConcessionType.PERCENTAGE ? '%' : '₹',
                          hintText: type == ConcessionType.PERCENTAGE ? 'e.g., 20' : 'e.g., 5000',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Value is required';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0) return 'Must be a positive number';
                          if (type == ConcessionType.PERCENTAGE && (numVal < 1 || numVal > 100)) {
                            return 'Percentage must be between 1 and 100';
                          }
                          return null;
                        },
                        onSaved: (val) => value = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                        maxLines: 2,
                        validator: (val) {
                          if (val != null && val.trim().length > 500) return 'Description max 500 characters';
                          return null;
                        },
                        onSaved: (val) => description = val?.trim() ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final navigator = Navigator.of(ctx);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final success = await ref.read(scholarshipsProvider(schoolId).notifier).createScholarship(
                            name,
                            type,
                            value,
                            description.isEmpty ? null : description,
                          );
                      if (success) {
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Concession rule created successfully.')),
                        );
                      } else {
                        final err = ref.read(scholarshipsProvider(schoolId)).error ?? 'Failed to create concession.';
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteScholarship(BuildContext context, WidgetRef ref, Scholarship scholarship) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Scholarship'),
          content: Text('Are you sure you want to delete "${scholarship.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final success = await ref.read(scholarshipsProvider(schoolId).notifier).deleteScholarship(scholarship.id);
                navigator.pop();
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Scholarship deleted successfully.')),
                  );
                } else {
                  final err = ref.read(scholarshipsProvider(schoolId)).error ?? 'Failed to delete scholarship.';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 4. FEE STRUCTURES TAB
// ==========================================
class _FeeStructuresTab extends ConsumerStatefulWidget {
  final String schoolId;
  const _FeeStructuresTab({required this.schoolId});

  @override
  ConsumerState<_FeeStructuresTab> createState() => _FeeStructuresTabState();
}

class _FeeStructuresTabState extends ConsumerState<_FeeStructuresTab> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feeStructuresProvider(widget.schoolId));
    final typesState = ref.watch(feeTypesProvider);
    final classesState = ref.watch(classesProvider(widget.schoolId));
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Helpers to resolve names
    String getFeeTypeName(String id) {
      final t = typesState.types.firstWhere((element) => element.id == id, orElse: () => FeeType(id: '', tenantId: '', name: 'Loading...', code: '', isSystem: false, createdAt: DateTime.now(), updatedAt: DateTime.now()));
      return t.name;
    }

    String getClassName(String? id) {
      if (id == null || id.isEmpty) return 'All Classes';
      for (final c in classesState.classes) {
        if (c.id == id) return c.name;
      }
      return 'Class Scope';
    }

    if (state.isLoading && state.structures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStructureDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Assign Cost'),
      ),
      body: state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(feeStructuresProvider(widget.schoolId).notifier).fetchStructures(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : state.structures.isEmpty
              ? const Center(child: Text('No class-specific fee structures assigned yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.structures.length,
                  itemBuilder: (context, index) {
                    final structure = state.structures[index];
                    final classLabel = getClassName(structure.classId);
                    final fineLabel = structure.fineRule != null
                        ? 'Late fee: ${structure.fineRule!.fineType == FineType.PERCENTAGE ? "${structure.fineRule!.fineValue.toStringAsFixed(0)}%" : "₹${structure.fineRule!.fineValue.toStringAsFixed(0)}"} after ${structure.fineRule!.gracePeriodDays} days'
                        : 'No late fee fine rule';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              child: Icon(Icons.menu_book, color: Colors.teal.shade800),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getFeeTypeName(structure.feeTypeId),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Target: $classLabel', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Due date: ${DateFormat('dd MMM yyyy').format(structure.dueDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(fineLabel, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    currencyFormatter.format(structure.amount),
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _confirmDeleteStructure(context, structure),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showCreateStructureDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final typesState = ref.read(feeTypesProvider);
    final ayState = ref.read(academicYearsProvider(widget.schoolId));
    final classesState = ref.read(classesProvider(widget.schoolId));

    String? selectedFeeTypeId = typesState.types.isNotEmpty ? typesState.types.first.id : null;
    
    // Choose active/current Academic Year
    String? selectedAyId;
    if (ayState.years.isNotEmpty) {
      final currentAy = ayState.years.firstWhere((y) => y.isCurrent, orElse: () => ayState.years.first);
      selectedAyId = currentAy.id;
    }

    String? selectedClassId; // null means "All Classes"
    double amount = 0.0;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    String description = '';

    bool addFineRule = false;
    int gracePeriod = 0;
    FineType fineType = FineType.FIXED;
    double fineValue = 0.0;

    final dueDatePickerController = TextEditingController(text: DateFormat('dd MMM yyyy').format(dueDate));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Configure Class Fee Structure'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fee Type Selector
                      DropdownButtonFormField<String>(
                        value: selectedFeeTypeId,
                        decoration: const InputDecoration(labelText: 'Fee Tag'),
                        items: typesState.types.map((t) {
                          return DropdownMenuItem(value: t.id, child: Text(t.name));
                        }).toList(),
                        onChanged: (v) => selectedFeeTypeId = v,
                        validator: (val) => val == null ? 'Fee type is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Academic Year Selector
                      DropdownButtonFormField<String>(
                        value: selectedAyId,
                        decoration: const InputDecoration(labelText: 'Academic Year'),
                        items: ayState.years.map((y) {
                          return DropdownMenuItem(value: y.id, child: Text('${y.name} ${y.isCurrent ? "(Current)" : ""}'));
                        }).toList(),
                        onChanged: (v) => selectedAyId = v,
                        validator: (val) => val == null ? 'Academic year is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Class Selector (including All Classes option)
                      DropdownButtonFormField<String?>(
                        value: selectedClassId,
                        decoration: const InputDecoration(labelText: 'Class Scoping'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Classes (Global)')),
                          ...classesState.classes.map((c) {
                            return DropdownMenuItem<String?>(value: c.id, child: Text(c.name));
                          }),
                        ],
                        onChanged: (v) => selectedClassId = v,
                      ),
                      const SizedBox(height: 12),

                      // Amount Input
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Structure Amount', prefixText: '₹'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Amount is required';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0) return 'Must be a positive amount';
                          return null;
                        },
                        onSaved: (val) => amount = double.parse(val!),
                      ),
                      const SizedBox(height: 12),

                      // Due Date date picker
                      TextFormField(
                        controller: dueDatePickerController,
                        decoration: const InputDecoration(labelText: 'Due Date', suffixIcon: Icon(Icons.calendar_month)),
                        readOnly: true,
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (selected != null) {
                            dueDate = selected;
                            dueDatePickerController.text = DateFormat('dd MMM yyyy').format(selected);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                        maxLines: 2,
                        validator: (val) {
                          if (val != null && val.trim().length > 500) return 'Description max 500 characters';
                          return null;
                        },
                        onSaved: (val) => description = val?.trim() ?? '',
                      ),
                      const SizedBox(height: 16),

                      // Late Fine Switch
                      CheckboxListTile(
                        title: const Text('Attach Late Fine Rule'),
                        value: addFineRule,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => addFineRule = v);
                          }
                        },
                      ),

                      if (addFineRule) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Grace Period (Days)'),
                          keyboardType: TextInputType.number,
                          initialValue: gracePeriod.toString(),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Grace period is required';
                            final intVal = int.tryParse(val);
                            if (intVal == null || intVal < 0) return 'Must be a non-negative number';
                            return null;
                          },
                          onSaved: (val) => gracePeriod = int.parse(val!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<FineType>(
                          value: fineType,
                          decoration: const InputDecoration(labelText: 'Fine Type'),
                          items: FineType.values.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f.name));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => fineType = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Fine Value',
                            suffixText: fineType == FineType.PERCENTAGE ? '%' : '₹',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Fine value is required';
                            final numVal = double.tryParse(val);
                            if (numVal == null || numVal <= 0) return 'Must be a positive value';
                            return null;
                          },
                          onSaved: (val) => fineValue = double.parse(val!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final navigator = Navigator.of(ctx);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      FineRuleInput? fineInput;
                      if (addFineRule) {
                        fineInput = FineRuleInput(
                          gracePeriodDays: gracePeriod,
                          fineType: fineType,
                          fineValue: fineValue,
                        );
                      }

                      final success = await ref.read(feeStructuresProvider(widget.schoolId).notifier).createStructure(
                            feeTypeId: selectedFeeTypeId!,
                            academicYearId: selectedAyId!,
                            classId: selectedClassId, // Explicitly null if All Classes is selected
                            amount: amount,
                            dueDate: dueDate,
                            description: description.isEmpty ? null : description,
                            fineRuleInput: fineInput,
                          );

                      if (success) {
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Fee structure assigned successfully.')),
                        );
                      } else {
                        final err = ref.read(feeStructuresProvider(widget.schoolId)).error ?? 'Failed to configure fee structure.';
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteStructure(BuildContext context, FeeStructure structure) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Fee Structure'),
          content: const Text('Are you sure you want to delete this class fee structure allocation?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final success = await ref.read(feeStructuresProvider(widget.schoolId).notifier).deleteStructure(structure.id);
                navigator.pop();
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Structure deleted successfully.')),
                  );
                } else {
                  final err = ref.read(feeStructuresProvider(widget.schoolId)).error ?? 'Failed to delete structure.';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
