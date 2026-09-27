import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/school_setup/presentation/widgets/school_logo_widget.dart';
import 'package:admin_portal/features/school_setup/presentation/widgets/school_logo_uploader.dart';

void main() {
  group('SchoolLogoWidget Tests', () {
    testWidgets('Renders fallback school icon when logoUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchoolLogoWidget(
              schoolId: 'school-1',
              logoUrl: null,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    });

    testWidgets('Renders memory image with BoxFit.contain when logo bytes are available', (tester) async {
      // 1x1 transparent PNG bytes
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolLogoBytesProvider((schoolId: 'school-1', version: '2026-09-04T12:00:00Z'))
                .overrideWith((ref) async => dummyPngBytes),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolLogoWidget(
                schoolId: 'school-1',
                logoUrl: '/api/v1/schools/school-1/logo',
                logoUpdatedAt: '2026-09-04T12:00:00Z',
                size: 48,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));
    });
  });

  group('SchoolLogoUploader Tests', () {
    testWidgets('Renders empty state with upload button and resolution guidelines', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SchoolLogoUploader(
                schoolId: 'sch-test-1',
                schoolName: 'Telangana Model School Test',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Logo'), findsOneWidget);
      expect(find.text('No school logo uploaded'), findsOneWidget);
      expect(find.text('Upload School Logo'), findsOneWidget);
      expect(find.textContaining('512×512'), findsOneWidget);
      expect(find.textContaining('5MB'), findsOneWidget);
    });

    testWidgets('Renders active state with replace and remove actions', (tester) async {
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolLogoBytesProvider((schoolId: 'sch-test-2', version: '2026-09-04T12:00:00Z'))
                .overrideWith((ref) async => dummyPngBytes),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolLogoUploader(
                schoolId: 'sch-test-2',
                schoolName: 'Telangana Model School Crest',
                currentLogoUrl: '/api/v1/schools/sch-test-2/logo',
                logoUpdatedAt: '2026-09-04T12:00:00Z',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Logo'), findsOneWidget);
      expect(find.text('Current Logo Active'), findsOneWidget);
      expect(find.text('Replace Logo'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });
  });
}
