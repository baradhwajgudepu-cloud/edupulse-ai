import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/fees/presentation/pages/salaries_screen.dart';

void main() {
  group('StaffSalaryItem Deserialization Tests', () {
    test('Correctly deserializes Decimal fields serialized as Strings ("0.00", "25000.50")', () {
      final json = {
        'id': 'sal_1',
        'staff_id': 'staff_1',
        'staff_name': 'Ramesh Kumar',
        'staff_code': 'EMP001',
        'month': '9',
        'year': '2026',
        'base_salary': '25000.50',
        'allowances': '5000.00',
        'deductions': '1250.75',
        'net_salary': '28749.75',
        'status': 'PENDING',
        'payment_date': null,
        'payment_method': null,
        'reference_number': null,
      };

      final item = StaffSalaryItem.fromJson(json);

      expect(item.id, 'sal_1');
      expect(item.staffId, 'staff_1');
      expect(item.staffName, 'Ramesh Kumar');
      expect(item.staffCode, 'EMP001');
      expect(item.month, 9);
      expect(item.year, 2026);
      expect(item.baseSalary, 25000.50);
      expect(item.allowances, 5000.00);
      expect(item.deductions, 1250.75);
      expect(item.netSalary, 28749.75);
      expect(item.status, 'PENDING');
    });

    test('Correctly deserializes zero Decimal string ("0.00") without TypeError', () {
      final json = {
        'id': 'sal_2',
        'staff_id': 'staff_2',
        'staff_name': 'Sunita Devi',
        'staff_code': 'EMP002',
        'month': 9,
        'year': 2026,
        'base_salary': '0.00',
        'allowances': '0.00',
        'deductions': '0.00',
        'net_salary': '0.00',
        'status': 'PENDING',
      };

      final item = StaffSalaryItem.fromJson(json);

      expect(item.baseSalary, 0.0);
      expect(item.allowances, 0.0);
      expect(item.deductions, 0.0);
      expect(item.netSalary, 0.0);
    });

    test('Handles native num values (int and double) gracefully', () {
      final json = {
        'id': 'sal_3',
        'staff_id': 'staff_3',
        'staff_name': 'K. V. Raman',
        'staff_code': 'EMP003',
        'month': 9,
        'year': 2026,
        'base_salary': 30000,
        'allowances': 4500.5,
        'deductions': 1500,
        'net_salary': 33000.5,
        'status': 'PAID',
      };

      final item = StaffSalaryItem.fromJson(json);

      expect(item.baseSalary, 30000.0);
      expect(item.allowances, 4500.5);
      expect(item.deductions, 1500.0);
      expect(item.netSalary, 33000.5);
    });

    test('Handles null values safely with default 0.0 without throwing', () {
      final json = {
        'id': 'sal_4',
        'staff_id': 'staff_4',
        'month': null,
        'year': null,
        'base_salary': null,
        'allowances': null,
        'deductions': null,
        'net_salary': null,
      };

      final item = StaffSalaryItem.fromJson(json);

      expect(item.month, 1);
      expect(item.year, 2026);
      expect(item.baseSalary, 0.0);
      expect(item.allowances, 0.0);
      expect(item.deductions, 0.0);
      expect(item.netSalary, 0.0);
      expect(item.staffName, 'Staff Member');
      expect(item.status, 'PENDING');
    });
  });
}
