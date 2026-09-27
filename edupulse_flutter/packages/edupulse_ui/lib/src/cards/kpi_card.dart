import 'package:flutter/material.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

/// KPI Card component matching the approved Google AI Studio design system.
/// Displays key metric values, trend indicator, icon, and subtitle.
class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? icon;
  final String? badgeText;
  final String? trendValue;
  final bool? trendPositive;
  final bool trendNeutral;
  final bool uppercaseTitle;
  final VoidCallback? onTap;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.badgeText,
    this.trendValue,
    this.trendPositive,
    this.trendNeutral = false,
    this.uppercaseTitle = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200;
    final cardBg = isDark ? EduPulseTheme.slate800 : Colors.white;
    final titleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final valueColor = isDark ? const Color(0xFFF8FAFC) : EduPulseTheme.slate900;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color trendColor;
    final IconData trendIcon;
    if (trendNeutral || trendPositive == null) {
      trendColor = subtextColor;
      trendIcon = Icons.remove_rounded;
    } else if (trendPositive == true) {
      trendColor = isDark ? const Color(0xFF34D399) : EduPulseTheme.emeraldSuccess;
      trendIcon = Icons.trending_up_rounded;
    } else {
      trendColor = isDark ? const Color(0xFFF87171) : EduPulseTheme.roseDanger;
      trendIcon = Icons.trending_down_rounded;
    }

    Widget content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Title & Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uppercaseTitle ? title.toUpperCase() : title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: valueColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
              ],
            ],
          ),

          // Footer row: Subtitle or Trend
          if (subtitle != null || trendValue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate100,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (subtitle != null && trendValue != null)
                    const SizedBox(width: 6),
                  if (trendValue != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trendIcon, size: 14, color: trendColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              trendValue!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: trendColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: content,
              )
            : content,
      ),
    );
  }
}
