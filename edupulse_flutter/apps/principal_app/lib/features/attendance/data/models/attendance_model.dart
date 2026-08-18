class AttendanceRecord {
  final String id;
  final String studentId;
  final String status; // PRESENT, ABSENT, LATE, HALFDAY
  final String date;
  final String classId;
  final String sectionId;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.status,
    required this.date,
    required this.classId,
    required this.sectionId,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      status: json['attendance_status'] as String? ?? 'PRESENT',
      date: json['attendance_date'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
    );
  }
}
