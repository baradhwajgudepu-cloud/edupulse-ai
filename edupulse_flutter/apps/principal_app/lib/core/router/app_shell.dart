import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _calculateSelectedIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) => _onItemTapped(index, context),
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home_rounded),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.people_alt_rounded),
            icon: Icon(Icons.people_alt_outlined),
            label: 'Students',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.how_to_reg_rounded),
            icon: Icon(Icons.how_to_reg_outlined),
            label: 'Attendance',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Finance',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.grid_view_rounded),
            icon: Icon(Icons.grid_view_outlined),
            label: 'More',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location.startsWith(AppRoutes.dashboard)) {
      return 0;
    }
    if (location.startsWith(AppRoutes.students)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.teacherAttendance) || location.startsWith(AppRoutes.geofence)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.fees)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.more) ||
        location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.notifications) ||
        location.startsWith(AppRoutes.analytics) ||
        location.startsWith(AppRoutes.teachers) ||
        location.startsWith(AppRoutes.communication) ||
        location.startsWith(AppRoutes.planner) ||
        location.startsWith(AppRoutes.reportCards) ||
        location.startsWith(AppRoutes.manageExams) ||
        location.startsWith(AppRoutes.teacherLeaves)) {
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
        context.go(AppRoutes.students);
        break;
      case 2:
        context.go(AppRoutes.teacherAttendance);
        break;
      case 3:
        context.go(AppRoutes.fees);
        break;
      case 4:
        context.go(AppRoutes.more);
        break;
    }
  }
}
