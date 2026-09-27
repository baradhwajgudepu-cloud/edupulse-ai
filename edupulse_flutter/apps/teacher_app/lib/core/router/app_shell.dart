import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'routes.dart';

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
          indicatorColor: EduPulseTheme.primaryTeal.withOpacity(0.12),
          elevation: 0,
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.home_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.menu_book_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.menu_book_outlined),
              label: 'Classes',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.how_to_reg_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.how_to_reg_outlined),
              label: 'Roll Call',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.assignment_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.assignment_outlined),
              label: 'Homework',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.grid_view_rounded, color: EduPulseTheme.primaryTeal),
              icon: Icon(Icons.grid_view_outlined),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location == AppRoutes.home || location.startsWith('${AppRoutes.home}/')) {
      return 0;
    }
    if (location.startsWith(AppRoutes.myClasses)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.attendance)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.homework)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.more) ||
        location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.marks) ||
        location.startsWith(AppRoutes.results) ||
        location.startsWith(AppRoutes.staffAttendance) ||
        location.startsWith(AppRoutes.teacherLeaveList) ||
        location.startsWith(AppRoutes.teacherLeaveCreate) ||
        location.startsWith(AppRoutes.communication) ||
        location.startsWith(AppRoutes.classAnalysis) ||
        location.startsWith(AppRoutes.homeworkGenerate) ||
        location.startsWith(AppRoutes.events) ||
        location.startsWith(AppRoutes.studentDirectory) ||
        location.startsWith(AppRoutes.notifications)) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.myClasses);
        break;
      case 2:
        context.go(AppRoutes.attendance);
        break;
      case 3:
        context.go(AppRoutes.homework);
        break;
      case 4:
        context.go(AppRoutes.more);
        break;
    }
  }
}
