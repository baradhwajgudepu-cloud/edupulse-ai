import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../attendance/presentation/pages/attendance_screen.dart';
import '../../../academics/presentation/pages/academics_screen.dart';
import '../../../homework/presentation/pages/homework_list_screen.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: const Text('Academic & Operational Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.co_present_rounded), text: 'Attendance'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Exams & Performance'),
              Tab(icon: Icon(Icons.assignment_rounded), text: 'Homework Feed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AttendanceScreen(),
            AcademicsScreen(),
            HomeworkListScreen(),
          ],
        ),
      ),
    );
  }
}
