import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/fees_provider.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feesStateProvider.notifier).fetchAnalytics();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(feesStateProvider.notifier).fetchAnalytics(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final feesState = ref.watch(feesStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees Analytics & AI Insights'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switch (feesState) {
                FeesInitial() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                FeesLoading() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                FeesError(:final message) => Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline,
                              size: 44, color: theme.colorScheme.error),
                          SizedBox(height: spacing.sm),
                          Text(
                            'Failed to load fee analytics',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton.icon(
                            onPressed: _onRefresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                FeesSuccess(:final data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Collection Progress Indicator Card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Collection Progress',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: spacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${data.collectionPercentage.toStringAsFixed(1)}%',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.donut_large_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.sm),
                              LinearProgressIndicator(
                                value: data.collectionPercentage / 100,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              SizedBox(height: spacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Collected: ₹${(data.monthCollection / 100000).toStringAsFixed(1)}L',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Dues: ₹${(data.pendingDues / 100000).toStringAsFixed(1)}L',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.md),

                      // AI Analytics Insights Box
                      Card(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                          side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  SizedBox(width: spacing.sm),
                                  Text(
                                    'AI Collections Prediction',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.md),
                              Text(
                                'Predicted Collection (Next 30 Days)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              Text(
                                '₹${data.predictedCollectionNext30Days.toStringAsFixed(2)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: spacing.md),
                              Container(
                                padding: EdgeInsets.all(spacing.sm),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(radius.sm),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 16,
                                    ),
                                    SizedBox(width: spacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Predicted using historical collection velocities and monthly student default risks indicators.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.md),

                      // Class-wise Dues List
                      Text(
                        'Outstanding Dues by Class',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      if (data.topOutstandingClasses.isEmpty)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(spacing.lg),
                            child: const Center(child: Text('No outstanding class dues reported.')),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.topOutstandingClasses.length,
                          separatorBuilder: (context, index) => SizedBox(height: spacing.xs),
                          itemBuilder: (context, index) {
                            final item = data.topOutstandingClasses[index];
                            final className = item['class_name'] as String? ?? 'Unknown Class';
                            final outstandingAmt = (item['outstanding_amount'] as num?)?.toDouble() ?? 0.0;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius.sm),
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.errorContainer,
                                  child: Icon(Icons.school, color: theme.colorScheme.error, size: 20),
                                ),
                                title: Text(
                                  className,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('Top outstanding dues'),
                                trailing: Text(
                                  '₹${outstandingAmt.toStringAsFixed(0)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      SizedBox(height: spacing.md),

                      // Historical Collection Trend
                      Text(
                        'Historical Collection Trend',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      if (data.historicalTrend.isEmpty)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(spacing.lg),
                            child: const Center(child: Text('No historical trend data available.')),
                          ),
                        )
                      else
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius.md),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(spacing.lg),
                            child: Column(
                              children: data.historicalTrend.entries.map((entry) {
                                final date = entry.key;
                                final val = entry.value;

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: spacing.xs),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        date,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 100,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: 0.7, // Visual placeholder for chart
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: spacing.sm),
                                          Text(
                                            '₹${(val / 100000).toStringAsFixed(1)}L',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
