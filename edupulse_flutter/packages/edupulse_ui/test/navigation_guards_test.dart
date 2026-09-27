import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse_ui/edupulse_ui.dart';

void main() {
  group('Navigation Guards & Responsive Layout Tests', () {
    testWidgets('RootExitGuard shows exit snackbar on first back press', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RootExitGuard(
              exitMessage: 'Press back again to exit',
              child: Center(child: Text('Home Screen')),
            ),
          ),
        ),
      );

      expect(find.text('Home Screen'), findsOneWidget);

      // Trigger back navigation
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();

      // Verify snackbar is shown
      expect(find.text('Press back again to exit'), findsOneWidget);
    });

    testWidgets('UnsavedFormGuard shows confirmation dialog when dirty', (tester) async {
      bool discarded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => Scaffold(
                          appBar: AppBar(title: const Text('Edit Form')),
                          body: UnsavedFormGuard(
                            isDirty: true,
                            onDiscard: () => discarded = true,
                            child: const Center(child: Text('Form Body')),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Form'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      expect(find.text('Form Body'), findsOneWidget);

      // Attempt to pop via back navigation
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Discard Unsaved Changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(discarded, isTrue);
      expect(find.text('Form Body'), findsNothing);
    });

    testWidgets('ResponsiveSafeAreaScroll renders on small 320dp screen without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveSafeAreaScroll(
              child: Column(
                children: [
                  Text('Header'),
                  SizedBox(height: 300),
                  Text('Middle Section'),
                  SizedBox(height: 300),
                  Text('Footer Button'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Header'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
