import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

/// Standardized Empty State matching Google AI Studio design.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? icon;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: isDark ? EduPulseTheme.slate800.withAlpha(100) : EduPulseTheme.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                ),
              ),
              alignment: Alignment.center,
              child: icon ??
                  Icon(
                    Icons.folder_open_outlined,
                    size: 26,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : EduPulseTheme.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : EduPulseTheme.slate900,
                  side: BorderSide(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized Error State with retry action matching Google AI Studio design.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    this.description = "We couldn't load this information. Please check your connection and try again.",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFFF1F2).withAlpha(150),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF9F1239) : const Color(0xFFFECDD3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF9F1239) : const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline_rounded,
                size: 24,
                color: EduPulseTheme.roseDanger,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : EduPulseTheme.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFE2E8F0) : EduPulseTheme.slate700,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : EduPulseTheme.slate900,
                  side: BorderSide(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum LoadingSkeletonType {
  card,
  table,
  kpi,
}

/// Standardized Loading Skeleton matching Google AI Studio pulse states.
class LoadingSkeletonWidget extends StatelessWidget {
  final LoadingSkeletonType type;
  final int rows;

  const LoadingSkeletonWidget({
    super.key,
    this.type = LoadingSkeletonType.card,
    this.rows = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pulseBase = isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate100;
    final pulseHighlight = isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200;

    if (type == LoadingSkeletonType.kpi) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? EduPulseTheme.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: pulseHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 110,
                      height: 20,
                      decoration: BoxDecoration(
                        color: pulseHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    if (type == LoadingSkeletonType.table) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? EduPulseTheme.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: pulseBase,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            ...List.generate(rows, (index) {
              return Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: pulseHighlight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: pulseHighlight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: pulseBase,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 14,
                      decoration: BoxDecoration(
                        color: pulseHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(rows, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? EduPulseTheme.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: pulseHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: pulseBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 10,
                decoration: BoxDecoration(
                  color: pulseBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 180,
                height: 10,
                decoration: BoxDecoration(
                  color: pulseBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Standardized Offline Banner matching Google AI Studio design.
class OfflineBannerWidget extends StatelessWidget {
  final bool isOnline;

  const OfflineBannerWidget({
    super.key,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: EduPulseTheme.amberWarning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.black87),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Slow connection detected. Working in cached offline mode — updates will sync automatically when back online.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
