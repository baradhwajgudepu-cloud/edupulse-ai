import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/migration_providers.dart';
import '../../data/models/migration_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

class MigrationCenterScreen extends ConsumerStatefulWidget {
  const MigrationCenterScreen({super.key});

  @override
  ConsumerState<MigrationCenterScreen> createState() => _MigrationCenterScreenState();
}

class _MigrationCenterScreenState extends ConsumerState<MigrationCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(migrationJobListProvider(schoolId).notifier).fetchJobs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Migration Center')),
        body: const Center(
          child: Text('Please select a school context from the top navigation first.'),
        ),
      );
    }

    final state = ref.watch(migrationJobListProvider(schoolId));
    final notifier = ref.read(migrationJobListProvider(schoolId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Migration Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.fetchJobs(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading migration jobs: ${state.error}',
                          style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => notifier.fetchJobs(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Actions Area
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(studentMigrationWizardProvider.notifier).reset();
                              context.push('/migrations/students/new');
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('New Student Migration'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(academicSetupMigrationWizardProvider.notifier).reset();
                              context.push('/migrations/academic-setup/new');
                            },
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('New Academic Setup Migration'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(guardianMappingMigrationWizardProvider.notifier).reset();
                              context.push('/migrations/guardian-mapping/new');
                            },
                            icon: const Icon(Icons.supervised_user_circle_outlined),
                            label: const Text('New Student-Guardian Mapping'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Filtering Choice Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Filter Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: state.filterType == 'ALL',
                            onSelected: (val) {
                              if (val) notifier.changeFilter('ALL');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Students'),
                            selected: state.filterType == 'STUDENTS',
                            onSelected: (val) {
                              if (val) notifier.changeFilter('STUDENTS');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Academic Setup'),
                            selected: state.filterType == 'ACADEMIC_SETUP',
                            onSelected: (val) {
                              if (val) notifier.changeFilter('ACADEMIC_SETUP');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Guardian Mappings'),
                            selected: state.filterType == 'GUARDIAN_MAPPING',
                            onSelected: (val) {
                              if (val) notifier.changeFilter('GUARDIAN_MAPPING');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Migration History (${state.jobs.length})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: state.jobs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text('No migration jobs found.', style: theme.textTheme.titleMedium),
                                  ],
                                ),
                              )
                            : isMobile
                                ? _buildMobileList(state.jobs, theme)
                                : _buildDesktopTable(state.jobs, theme),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    Color textColor;
    switch (status) {
      case 'COMPLETED':
        color = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'COMPLETED_WITH_ERRORS':
        color = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'FAILED':
        color = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'RUNNING':
        color = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'VALIDATED':
        color = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        break;
      case 'VALIDATING':
        color = Colors.amber.shade50;
        textColor = Colors.amber.shade700;
        break;
      case 'CANCELLED':
        color = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      default:
        color = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMobileList(List<ImportJobDto> jobs, ThemeData theme) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isAcademicSetup = job.importType == 'ACADEMIC_SETUP';
        final isGuardianMapping = job.importType == 'GUARDIAN_MAPPING';
        final detailRoute = isGuardianMapping
            ? '/migrations/guardian-mapping/${job.id}'
            : isAcademicSetup
                ? '/migrations/academic-setup/${job.id}'
                : '/migrations/students/${job.id}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(detailRoute),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.sourceFilename,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip(job.status, theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      String typeLabel = 'Students';
                      if (job.importType == 'ACADEMIC_SETUP') {
                        typeLabel = 'Academic Setup';
                      } else if (job.importType == 'GUARDIAN_MAPPING') {
                        typeLabel = 'Guardian Mapping';
                      }
                      return Text('Type: $typeLabel',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500));
                    }
                  ),
                  const SizedBox(height: 4),
                  Text('Rows: ${job.totalRows} (Success: ${job.successfulRows} | Failed: ${job.failedRows})',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Created At: ${dateFormat.format(job.createdAt.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push(detailRoute),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<ImportJobDto> jobs, ThemeData theme) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Source File')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Total Rows')),
            DataColumn(label: Text('Success')),
            DataColumn(label: Text('Failed')),
            DataColumn(label: Text('Created Date')),
            DataColumn(label: Text('Action')),
          ],
          rows: jobs.map((job) {
            final isAcademicSetup = job.importType == 'ACADEMIC_SETUP';
            final isGuardianMapping = job.importType == 'GUARDIAN_MAPPING';
            final detailRoute = isGuardianMapping
                ? '/migrations/guardian-mapping/${job.id}'
                : isAcademicSetup
                    ? '/migrations/academic-setup/${job.id}'
                    : '/migrations/students/${job.id}';

            String typeLabel = 'Students';
            if (job.importType == 'ACADEMIC_SETUP') {
              typeLabel = 'Academic Setup';
            } else if (job.importType == 'GUARDIAN_MAPPING') {
              typeLabel = 'Guardian Mapping';
            }

            return DataRow(
              cells: [
                DataCell(Text(job.sourceFilename)),
                DataCell(Text(typeLabel)),
                DataCell(_buildStatusChip(job.status, theme)),
                DataCell(Text(job.totalRows.toString())),
                DataCell(Text(job.successfulRows.toString())),
                DataCell(Text(job.failedRows.toString())),
                DataCell(Text(dateFormat.format(job.createdAt.toLocal()))),
                DataCell(
                  TextButton(
                    onPressed: () => context.push(detailRoute),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
