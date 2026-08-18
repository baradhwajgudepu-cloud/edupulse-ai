enum AttendanceSessionStatus {
  DRAFT,
  SUBMITTED,
  LOCKED,
}

enum AttendanceStatus {
  PRESENT,
  ABSENT,
  LATE,
  HALF_DAY,
  MEDICAL_LEAVE,
  EXCUSED,
  HOLIDAY,
  ONLINE,
}

enum AttendanceSource {
  MANUAL,
  BIOMETRIC,
  RFID,
  FACE_RECOGNITION,
  IMPORT,
}

enum AttendanceReason {
  SICK,
  PERSONAL,
  SPORTS,
  OFFICIAL,
  UNKNOWN,
}
