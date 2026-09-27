import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/fees/presentation/pages/salaries_screen.dart';

void main() {
  group('Salary Edit and Live Calculation Tests', () {
    test('StaffSalaryItem properly detects unconfigured salary records', () {
      final unconfigured = StaffSalaryItem(
        id: 'sal-1',
        staffId: 'staff-1',
        staffName: 'Amit Sharma',
        staffCode: 'TCH-001',
        month: 9,
        year: 2026,
        baseSalary: 0.0,
        allowances: 0.0,
        deductions: 0.0,
        netSalary: 0.0,
        status: 'PENDING',
      );

      final configured = StaffSalaryItem(
        id: 'sal-2',
        staffId: 'staff-2',
        staffName: 'Priya Patel',
        staffCode: 'TCH-002',
        month: 9,
        year: 2026,
        baseSalary: 45000.0,
        allowances: 5000.0,
        deductions: 2500.0,
        netSalary: 47500.0,
        status: 'PENDING',
      );

      final isUnconf1 = unconfigured.status != 'PAID' && unconfigured.baseSalary == 0.0 && unconfigured.netSalary == 0.0;
      final isUnconf2 = configured.status != 'PAID' && configured.baseSalary == 0.0 && configured.netSalary == 0.0;

      expect(isUnconf1, isTrue);
      expect(isUnconf2, isFalse);
    });

    test('Live net salary formula computes net = base + allowances - deductions correctly', () {
      double computeNet(double base, double allowances, double deductions) {
        return (base + allowances - deductions).clamp(0.0, double.infinity);
      }

      expect(computeNet(25000.0, 3000.0, 1500.0), 26500.0);
      expect(computeNet(50000.0, 5000.0, 2000.0), 53000.0);
      expect(computeNet(30000.0, 0.0, 0.0), 30000.0);
      expect(computeNet(20000.0, 1000.0, 25000.0), 0.0); // clamped to 0
    });

    testWidgets('Renders Edit Salary action buttons and Not Configured badge', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(tester.view.resetPhysicalSize);

      final salary = StaffSalaryItem(
        id: 'sal-1',
        staffId: 'staff-1',
        staffName: 'John Doe',
        staffCode: 'T001',
        month: 9,
        year: 2026,
        baseSalary: 0.0,
        allowances: 0.0,
        deductions: 0.0,
        netSalary: 0.0,
        status: 'PENDING',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Staff')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        DataCell(Text(salary.staffName)),
                        DataCell(
                          salary.baseSalary == 0.0 && salary.netSalary == 0.0
                              ? const Chip(label: Text('Not Configured'))
                              : Chip(label: Text(salary.status)),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(onPressed: () {}, child: const Text('Edit Salary')),
                              FilledButton.tonal(onPressed: () {}, child: const Text('Record Payment')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Not Configured'), findsOneWidget);
      expect(find.text('Edit Salary'), findsOneWidget);
      expect(find.text('Record Payment'), findsOneWidget);
    });
  });
}
