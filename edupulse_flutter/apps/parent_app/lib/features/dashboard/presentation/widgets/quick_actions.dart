import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  void _onActionTap(BuildContext context, String actionName, {String? route}) {
    if (route != null) {
      context.push(route);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('$actionName feature will be available in the next release.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          local?.translate('quick_actions') ?? 'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(
              context: context,
              label: local?.translate('pay_fees') ?? 'Pay Fees',
              icon: Icons.payments_rounded,
              color: Colors.green,
              route: AppRoutes.payFees,
            ),
            _buildActionItem(
              context: context,
              label: local?.translate('attendance') ?? 'Attendance',
              icon: Icons.fact_check_rounded,
              color: Colors.blue,
              route: AppRoutes.attendance,
            ),
            _buildActionItem(
              context: context,
              label: local?.translate('homework') ?? 'Homework',
              icon: Icons.menu_book_rounded,
              color: Colors.orange,
              route: AppRoutes.homework,
            ),
            _buildActionItem(
              context: context,
              label: local?.translate('report_cards') ?? 'Report Cards',
              icon: Icons.assessment_rounded,
              color: Colors.purple,
              route: AppRoutes.reportCards,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    String? route,
  }) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Expanded(
      child: GestureDetector(
        onTap: () => _onActionTap(context, label, route: route),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(radius.md),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
