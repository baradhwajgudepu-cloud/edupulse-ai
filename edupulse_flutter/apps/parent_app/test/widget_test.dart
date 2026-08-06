import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:parent_app/app.dart';
import 'package:parent_app/core/providers/bootstrap_provider.dart';

void main() {
  testWidgets('App bootstraps and routes to Dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    // Let the GoRouter resolve, splash delay execute, and route transition to dashboard
    await tester.pumpAndSettle();

    // Verify we have navigated successfully to the dashboard screen
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
