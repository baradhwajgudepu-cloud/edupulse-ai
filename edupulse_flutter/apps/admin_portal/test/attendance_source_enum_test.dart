import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/attendance/data/models/attendance_models.dart';

void main() {
  group('AttendanceSource Enum & Normalization Tests', () {
    test('1. Exact allowed enum values match backend contract', () {
      final allowedNames = AttendanceSource.values.map((e) => e.wireValue).toList();
      expect(allowedNames, containsAll(['MANUAL', 'BIOMETRIC', 'RFID', 'FACE_RECOGNITION', 'IMPORT']));
      expect(allowedNames.length, 5);
    });

    test('2. fromString normalizes legacy BULK_IMPORT to IMPORT', () {
      expect(AttendanceSource.fromString('BULK_IMPORT'), AttendanceSource.IMPORT);
      expect(AttendanceSource.fromString('bulk_import'), AttendanceSource.IMPORT);
      expect(AttendanceSource.fromString('Bulk_Import'), AttendanceSource.IMPORT);
      expect(AttendanceSource.fromString('EXCEL_IMPORT'), AttendanceSource.IMPORT);
    });

    test('3. fromString parses valid canonical values', () {
      expect(AttendanceSource.fromString('MANUAL'), AttendanceSource.MANUAL);
      expect(AttendanceSource.fromString('BIOMETRIC'), AttendanceSource.BIOMETRIC);
      expect(AttendanceSource.fromString('RFID'), AttendanceSource.RFID);
      expect(AttendanceSource.fromString('FACE_RECOGNITION'), AttendanceSource.FACE_RECOGNITION);
      expect(AttendanceSource.fromString('IMPORT'), AttendanceSource.IMPORT);
    });

    test('4. fromString gracefully defaults unknown/null to MANUAL', () {
      expect(AttendanceSource.fromString(null), AttendanceSource.MANUAL);
      expect(AttendanceSource.fromString(''), AttendanceSource.MANUAL);
      expect(AttendanceSource.fromString('UNKNOWN_SOURCE'), AttendanceSource.MANUAL);
    });

    test('5. AttendanceLogDto parses and normalizes attendanceSource safely', () {
      final jsonLegacy = {
        'student_id': 'stud_1',
        'attendance_status': 'PRESENT',
        'attendance_source': 'BULK_IMPORT',
      };
      final dto = AttendanceLogDto.fromJson(jsonLegacy);
      expect(dto.attendanceSource, 'IMPORT');

      final jsonManual = {
        'student_id': 'stud_2',
        'attendance_status': 'PRESENT',
        'attendance_source': 'MANUAL',
      };
      final dtoManual = AttendanceLogDto.fromJson(jsonManual);
      expect(dtoManual.attendanceSource, 'MANUAL');
    });
  });
}
