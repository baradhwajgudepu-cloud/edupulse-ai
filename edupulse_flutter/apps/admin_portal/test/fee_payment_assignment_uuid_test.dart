import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/fees/data/models/fee_models.dart';
import 'package:admin_portal/features/fees/presentation/widgets/record_fee_payment_dialog.dart';

void main() {
  group('Fee Payment Assignment UUID Validation & Empty State Tests', () {
    test('UUID regex correctly matches valid 36-character UUIDs and rejects default_assign_id', () {
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

      expect(uuidRegex.hasMatch('b56f8f82-a987-4ce8-b57f-d8f94119d65c'), isTrue);
      expect(uuidRegex.hasMatch('00000000-0000-0000-0000-000000000000'), isTrue);

      expect(uuidRegex.hasMatch('default_assign_id'), isFalse);
      expect(uuidRegex.hasMatch(''), isFalse);
      expect(uuidRegex.hasMatch('12345'), isFalse);
    });

    testWidgets('Displays No Fee Assignments Found banner when student has no fee structures', (tester) async {
      final emptyLedger = StudentLedger(
        studentId: 'st-no-assign',
        openingBalance: 0.0,
        assignments: [],
        scholarships: [],
        payments: [],
        closingBalance: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecordFeePaymentDialog(
                studentId: 'st-no-assign',
                studentName: 'Aarav Sharma',
                admissionNumber: 'ADM-2026-001',
                schoolId: 'b56f8f82-a987-4ce8-b57f-d8f94119d65c',
                initialLedger: emptyLedger,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Fee Assignments Found'), findsOneWidget);
      expect(find.textContaining('No fee structures are currently assigned to this student'), findsOneWidget);
      // Ensure the payment submission button is absent/disabled
      expect(find.byKey(const Key('modal_submit_payment_button')), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Renders assignment details and submit button when valid assignments exist', (tester) async {
      final validLedger = StudentLedger(
        studentId: 'st-valid',
        openingBalance: 0.0,
        assignments: [
          StudentFeeAssignment(
            id: 'e69c5e37-9759-42b7-a3cf-eefdf3453b02',
            tenantId: 'd48479e0-f38b-49d9-bb43-d3ca8ec9ff58',
            studentId: 'st-valid',
            feeStructureId: '2eef6554-734d-45df-bbad-7ff6b840e676',
            academicYearId: '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
            assignedAmount: 15000.0,
            discountAmount: 0.0,
            fineAmount: 0.0,
            paidAmount: 5000.0,
            status: FeeAssignmentStatus.PARTIALLY_PAID,
            version: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        scholarships: [],
        payments: [],
        closingBalance: 10000.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecordFeePaymentDialog(
                studentId: 'st-valid',
                studentName: 'Rohan Gupta',
                admissionNumber: 'ADM-2026-002',
                schoolId: 'b56f8f82-a987-4ce8-b57f-d8f94119d65c',
                initialLedger: validLedger,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Record Fee Payment'), findsWidgets);
      expect(find.text('Rohan Gupta'), findsOneWidget);
      expect(find.byKey(const Key('modal_payment_amount_field')), findsOneWidget);
      expect(find.byKey(const Key('modal_submit_payment_button')), findsOneWidget);
    });
  });
}
