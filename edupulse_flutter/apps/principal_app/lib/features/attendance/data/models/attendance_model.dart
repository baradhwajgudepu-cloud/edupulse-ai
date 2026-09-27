class AttendanceRecord {
  final String id;
  final String studentId;
  final String status; // PRESENT, ABSENT, LATE, HALFDAY
  final String date;
  final String classId;
  final String sectionId;
  final String? studentName;
  final String? admissionNumber;
  final String? rollNumber;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.status,
    required this.date,
    required this.classId,
    required this.sectionId,
    this.studentName,
    this.admissionNumber,
    this.rollNumber,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      status: json['status'] as String? ?? json['attendance_status'] as String? ?? 'PRESENT',
      date: json['attendance_date'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      studentName: json['student_name'] as String?,
      admissionNumber: json['admission_number'] as String?,
      rollNumber: json['roll_number'] as String?,
    );
  }
}
