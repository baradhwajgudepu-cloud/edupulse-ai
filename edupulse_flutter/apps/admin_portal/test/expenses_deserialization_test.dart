import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/core/utils/numeric_utils.dart';
import 'package:admin_portal/features/fees/presentation/pages/expenses_screen.dart';
import 'package:admin_portal/features/fees/data/models/fee_models.dart';

void main() {
  group('Expenses and Financial Models Deserialization Tests', () {
    test('safeParseDouble handles string decimal, int, double, and null', () {
      expect(safeParseDouble('500.00'), 500.0);
      expect(safeParseDouble('1234.56'), 1234.56);
      expect(safeParseDouble(500), 500.0);
      expect(safeParseDouble(250.75), 250.75);
      expect(safeParseDouble(null), 0.0);
      expect(safeParseDouble('', 10.0), 10.0);
      expect(safeParseDouble('invalid', 5.0), 5.0);
    });

    test('safeParseInt handles string int, string float, int, num, and null', () {
      expect(safeParseInt('42'), 42);
      expect(safeParseInt('42.9'), 42);
      expect(safeParseInt(100), 100);
      expect(safeParseInt(55.5), 55);
      expect(safeParseInt(null, 1), 1);
      expect(safeParseInt('', 2), 2);
    });

    test('ExpenseItem.fromJson does not throw TypeError on Decimal string ("500.00")', () {
      final json = {
        'id': 'exp-101',
        'category': 'OPERATIONS',
        'subcategory': 'Electricity',
        'amount': '500.00', // FastAPI Decimal serialized as string
        'expense_date': '2026-09-21',
        'description': 'Campus electricity bill',
        'paid_to': 'State Electricity Board',
        'payment_method': 'BANK_TRANSFER',
        'reference_number': 'BILL-8822',
        'status': 'APPROVED',
      };

      expect(() => ExpenseItem.fromJson(json), returnsNormally);
      final item = ExpenseItem.fromJson(json);
      expect(item.id, 'exp-101');
      expect(item.amount, 500.0);
      expect(item.description, 'Campus electricity bill');
      expect(item.category, 'OPERATIONS');
    });

    test('Scholarship.fromJson does not throw TypeError on string concession value', () {
      final json = {
        'id': 'sch-1',
        'tenant_id': 'tenant-1',
        'school_id': 'school-1',
        'name': 'Merit Scholarship',
        'concession_type': 'FIXED',
        'value': '1500.00',
        'description': 'Top rankers',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      };

      expect(() => Scholarship.fromJson(json), returnsNormally);
      final item = Scholarship.fromJson(json);
      expect(item.value, 1500.0);
    });

    test('StudentFeeAssignment.fromJson parses Decimal strings for all monetary fields', () {
      final json = {
        'id': 'assign-1',
        'tenant_id': 'tenant-1',
        'student_id': 'student-1',
        'fee_structure_id': 'structure-1',
        'academic_year_id': 'ay-1',
        'assigned_amount': '12000.00',
        'discount_amount': '2000.00',
        'fine_amount': '150.00',
        'paid_amount': '5000.00',
        'status': 'PARTIALLY_PAID',
        'version': '1',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      };

      expect(() => StudentFeeAssignment.fromJson(json), returnsNormally);
      final item = StudentFeeAssignment.fromJson(json);
      expect(item.assignedAmount, 12000.0);
      expect(item.discountAmount, 2000.0);
      expect(item.fineAmount, 150.0);
      expect(item.paidAmount, 5000.0);
      expect(item.version, 1);
    });

    test('OutstandingFeeReportItem.fromJson parses Decimal strings cleanly', () {
      final json = {
        'student_id': 'st-1',
        'student_name': 'Rohan Das',
        'admission_number': 'ADM001',
        'class_id': 'cls-1',
        'class_name': 'Class 10',
        'section_id': 'sec-1',
        'section_name': 'A',
        'fee_structure_id': 'fs-1',
        'fee_type_id': 'ft-1',
        'fee_type_name': 'Tuition Fee',
        'assigned_amount': '25000.00',
        'discount_amount': '0.00',
        'fine_amount': '500.00',
        'paid_amount': '10000.00',
        'outstanding_amount': '15500.00',
        'due_date': '2026-09-30T00:00:00Z',
        'status': 'PARTIALLY_PAID',
      };

      expect(() => OutstandingFeeReportItem.fromJson(json), returnsNormally);
      final item = OutstandingFeeReportItem.fromJson(json);
      expect(item.outstandingAmount, 15500.0);
      expect(item.assignedAmount, 25000.0);
    });
  });
}
