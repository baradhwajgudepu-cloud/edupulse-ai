import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'routes.dart';

/// 5-tab Bottom Navigation Shell for Parent App matching the Google AI Studio prototype.
/// Tabs: Home (/dashboard), Attendance (/attendance), Homework (/homework), Fees (/pay-fees), Profile (/profile).
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _calculateSelectedIndex(location);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) => _onItemTapped(index, context),
          backgroundColor: Colors.transparent,
          indicatorColor: EduPulseTheme.primaryTeal.withValues(alpha: 0.12),
          elevation: 0,
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.home_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.calendar_month_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Attendance',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.assignment_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.assignment_outlined),
              label: 'Homework',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.credit_card_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.credit_card_outlined),
              label: 'Fees',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.person_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location == AppRoutes.dashboard || location.startsWith('${AppRoutes.dashboard}/')) {
      return 0;
    }
    if (location.startsWith(AppRoutes.attendance)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.homework)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.payFees)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.reportCards) ||
        location.startsWith(AppRoutes.exams) ||
        location.startsWith(AppRoutes.announcements) ||
        location.startsWith(AppRoutes.notifications) ||
        location.startsWith(AppRoutes.communication)) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.attendance);
        break;
      case 2:
        context.go(AppRoutes.homework);
        break;
      case 3:
        context.go(AppRoutes.payFees);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }
}

