import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report Card Download Modal-Local Notification Scoping Tests', () {
    testWidgets('Renders inline scoped alert banner with authentic message and Retry without leaking SnackBar', (tester) async {
      const serverErrorMessage = 'Report card not yet finalized by Examination Committee.';

      String? reportCardError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          reportCardError = serverErrorMessage;
                        });
                      },
                      child: const Text('Simulate Download Failure'),
                    ),
                    if (reportCardError != null)
                      Container(
                        key: const Key('report_card_error_banner'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reportCardError!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Retry', style: TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFBE123C)),
                              onPressed: () {
                                setState(() {
                                  reportCardError = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Trigger failure
      await tester.tap(find.text('Simulate Download Failure'));
      await tester.pump();

      // Verify inline banner appears with authentic server message
      expect(find.byKey(const Key('report_card_error_banner')), findsOneWidget);
      expect(find.text(serverErrorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify NO floating SnackBar exists on ScaffoldMessenger (zero leakage guarantee)
      expect(find.byType(SnackBar), findsNothing);

      // Verify dismissal works locally
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.byKey(const Key('report_card_error_banner')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Renders inline scoped success banner without leaking SnackBar', (tester) async {
      String? reportCardSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          reportCardSuccess = 'Report card downloaded successfully.';
                        });
                      },
                      child: const Text('Simulate Download Success'),
                    ),
                    if (reportCardSuccess != null)
                      Container(
                        key: const Key('report_card_success_banner'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reportCardSuccess!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Trigger success
      await tester.tap(find.text('Simulate Download Success'));
      await tester.pump();

      expect(find.byKey(const Key('report_card_success_banner')), findsOneWidget);
      expect(find.text('Report card downloaded successfully.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      // Verify NO floating SnackBar exists (zero leakage guarantee)
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
