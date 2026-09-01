import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:intl/intl.dart';

String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
  try {
    final parsed = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy').format(parsed);
  } catch (_) {
    return dateStr;
  }
}

final parentAnnouncementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final result = await apiClient.get(
    '/notifications',
    mapper: (json) => json as Map<String, dynamic>,
  );
  return result.when(
    onSuccess: (data) {
      final List list = (data['data'] as List?) ?? [];
      return list
          .where((note) => note['notification_type'] == 'ANNOUNCEMENT' || note['related_module'] == 'announcement')
          .cast<Map<String, dynamic>>()
          .toList();
    },
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final announcementsAsync = ref.watch(parentAnnouncementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Notices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_rounded, size: 64, color: theme.colorScheme.outline),
                SizedBox(height: spacing.md),
                Text(
                  'Failed to load announcements',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(err.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (notices) {
          if (notices.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.outline),
                    SizedBox(height: spacing.md),
                    Text(
                      'No notices published yet',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(parentAnnouncementsProvider.future),
            child: ListView.builder(
              padding: EdgeInsets.all(spacing.md),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final notice = notices[index];
                final title = notice['title'] as String? ?? 'Notice';
                final message = notice['message'] as String? ?? 'N/A';
                final dateStrRaw = notice['created_at'] as String? ?? 'N/A';
                final dateStr = formatDate(dateStrRaw);
                final priority = notice['priority'] as String? ?? 'NORMAL';

                final isHigh = priority == 'HIGH';

                return Card(
                  margin: EdgeInsets.only(bottom: spacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isHigh ? theme.colorScheme.error : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isHigh)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(radius.sm),
                                ),
                                child: Text(
                                  'URGENT',
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          'Posted: $dateStr',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const Divider(),
                        SizedBox(height: spacing.xs),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
