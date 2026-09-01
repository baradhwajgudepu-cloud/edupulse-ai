import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/communication_analytics_provider.dart';
import 'package:edupulse_models/edupulse_models.dart';

class CommunicationAnalyticsScreen extends ConsumerStatefulWidget {
  const CommunicationAnalyticsScreen({super.key});

  @override
  ConsumerState<CommunicationAnalyticsScreen> createState() => _CommunicationAnalyticsScreenState();
}

class _CommunicationAnalyticsScreenState extends ConsumerState<CommunicationAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communicationAnalyticsProvider.notifier).fetchAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final analyticsState = ref.watch(communicationAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduPulse Connect Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(communicationAnalyticsProvider.notifier).fetchAnalytics(),
          ),
        ],
      ),
      body: analyticsState.isLoading && analyticsState.analytics == null
          ? const Center(child: CircularProgressIndicator())
          : analyticsState.errorMessage != null
              ? Center(child: Text(analyticsState.errorMessage!))
              : _buildContent(analyticsState.analytics!, spacing, radius, theme),
    );
  }

  Widget _buildContent(
    CommunicationAnalytics data,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final double resolutionRate = data.totalRequests > 0
        ? (data.resolvedCount / data.totalRequests) * 100
        : 100.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI cards row
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Queries',
                  value: data.totalRequests.toString(),
                  icon: Icons.forum_rounded,
                  color: Colors.blue,
                  spacing: spacing,
                  radius: radius,
                  theme: theme,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _buildKpiCard(
                  title: 'Resolution Rate',
                  value: '${resolutionRate.toStringAsFixed(1)}%',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  spacing: spacing,
                  radius: radius,
                  theme: theme,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _buildKpiCard(
                  title: 'SLA Breaches',
                  value: data.slaBreachCount.toString(),
                  icon: Icons.gpp_maybe_rounded,
                  color: Colors.red,
                  spacing: spacing,
                  radius: radius,
                  theme: theme,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _buildKpiCard(
                  title: 'Avg Resolution Time',
                  value: '${data.averageResolutionTimeHours.toStringAsFixed(1)}h',
                  icon: Icons.timelapse_rounded,
                  color: Colors.orange,
                  spacing: spacing,
                  radius: radius,
                  theme: theme,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // 2. Charts Section (Status breakdown and Category breakdown side-by-side)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Breakdown Card
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius.md),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queries Status Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: spacing.md),
                        _buildStatusProgressRow('Open / New', data.openCount, data.totalRequests, Colors.blue, spacing, theme),
                        _buildStatusProgressRow('Acknowledged', data.acknowledgedCount, data.totalRequests, Colors.teal, spacing, theme),
                        _buildStatusProgressRow('In Progress', data.inProgressCount, data.totalRequests, Colors.orange, spacing, theme),
                        _buildStatusProgressRow('Escalated', data.escalatedCount, data.totalRequests, Colors.red, spacing, theme),
                        _buildStatusProgressRow('Reopened', data.reopenCount, data.totalRequests, Colors.indigo, spacing, theme),
                        _buildStatusProgressRow('Resolved', data.resolvedCount, data.totalRequests, Colors.green, spacing, theme),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              // Category Trends Breakdown
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius.md),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queries Category Trends',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: spacing.md),
                        _buildStatusProgressRow('Academic', _countCategory(data.urgentRequests, 'ACADEMIC'), data.urgentRequests.length, Colors.purple, spacing, theme),
                        _buildStatusProgressRow('Attendance', _countCategory(data.urgentRequests, 'ATTENDANCE'), data.urgentRequests.length, Colors.blue, spacing, theme),
                        _buildStatusProgressRow('Financial / Fees', _countCategory(data.urgentRequests, 'FINANCIAL'), data.urgentRequests.length, Colors.amber, spacing, theme),
                        _buildStatusProgressRow('Transport', _countCategory(data.urgentRequests, 'TRANSPORT'), data.urgentRequests.length, Colors.orange, spacing, theme),
                        _buildStatusProgressRow('Other / General', _countCategory(data.urgentRequests, 'OTHER'), data.urgentRequests.length, Colors.grey, spacing, theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // 3. Urgent / Escalated / SLA Breached Queries Table List
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: spacing.xs),
                      Text(
                        'Urgent & SLA Breached Queue',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  if (data.urgentRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No urgent or SLA breached requests in the queue.')),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.urgentRequests.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final req = data.urgentRequests[index];
                        return ListTile(
                          title: Text(req.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Category: ${req.category} | Created: ${_formatDate(req.createdAt)}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              req.priority,
                              style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required AppSpacing spacing,
    required AppRadius radius,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusProgressRow(
    String label,
    int count,
    int total,
    Color color,
    AppSpacing spacing,
    ThemeData theme,
  ) {
    final double pct = total > 0 ? count / total : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text('$count / $total (${(pct * 100).toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: spacing.xs),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  int _countCategory(List<CommunicationRequest> list, String category) {
    return list.where((req) => req.category.toUpperCase() == category.toUpperCase()).length;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
