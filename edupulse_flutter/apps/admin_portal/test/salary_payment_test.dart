import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/fees/presentation/pages/salaries_screen.dart';

void main() {
  group('Salary Payment Recording and Receipt Tests', () {
    test('StaffSalaryItem correctly parses payment history fields', () {
      final json = {
        'id': 'sal-pay-1',
        'staff_id': 'staff-1',
        'staff_name': 'Meera Nair',
        'staff_code': 'TCH-005',
        'month': 9,
        'year': 2026,
        'base_salary': '40000.00',
        'allowances': '3000.00',
        'deductions': '1500.00',
        'net_salary': '41500.00',
        'status': 'PAID',
        'payment_date': '2026-09-20',
        'payment_method': 'BANK_TRANSFER',
        'reference_number': 'NEFT-998822',
        'remarks': 'Monthly salary processed',
      };

      final item = StaffSalaryItem.fromJson(json);

      expect(item.status, 'PAID');
      expect(item.paymentDate, '2026-09-20');
      expect(item.paymentMethod, 'BANK_TRANSFER');
      expect(item.referenceNumber, 'NEFT-998822');
      expect(item.remarks, 'Monthly salary processed');
      expect(item.netSalary, 41500.0);
    });

    testWidgets('Renders Payment Slip button for PAID records', (tester) async {
      final paidSalary = StaffSalaryItem(
        id: 'sal-100',
        staffId: 'staff-100',
        staffName: 'Ananya Roy',
        staffCode: 'TCH-100',
        month: 9,
        year: 2026,
        baseSalary: 50000.0,
        allowances: 2000.0,
        deductions: 1000.0,
        netSalary: 51000.0,
        status: 'PAID',
        paymentDate: '2026-09-21',
        paymentMethod: 'ONLINE',
        referenceNumber: 'UPI-776655',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DataTable(
                columns: const [
                  DataColumn(label: Text('Staff')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  DataRow(
                    cells: [
                      DataCell(Text(paidSalary.staffName)),
                      DataCell(Chip(label: Text(paidSalary.status))),
                      DataCell(
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Payment Slip'),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('Payment Slip'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });
  });
}
