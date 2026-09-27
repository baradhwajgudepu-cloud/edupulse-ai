import 'package:flutter/material.dart';
import 'examination_detail_screen.dart';

export 'examination_detail_screen.dart';

/// Legacy wrapper for [ExaminationDetailScreen] to preserve backward compatibility.
class ExaminationDashboardScreen extends StatelessWidget {
  final String examId;
  final int initialTabIndex;

  const ExaminationDashboardScreen({
    super.key,
    required this.examId,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ExaminationDetailScreen(
      examinationId: examId,
      initialTabIndex: initialTabIndex,
    );
  }
}
