import 'package:flutter/material.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final local = EduLocalization.of(context);
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    return Scaffold(
      appBar: AppBar(
        title: Text(local?.translate('dashboard') ?? 'Dashboard'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: spacing.md),
              Text(
                local?.translate('dashboard_placeholder') ??
                    'Welcome to EduPulse Parent App',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
