class StaffDailyAttendanceReportItem {
  final String teacherId;
  final String teacherName;
  final String? designation;
  final String? department;
  final String attendanceStatus;
  final String? checkInTime;
  final String? checkOutTime;
  final String? remarks;
  
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkInDistanceMeters;
  
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkOutDistanceMeters;
  
  final bool isMockedLocation;

  StaffDailyAttendanceReportItem({
    required this.teacherId,
    required this.teacherName,
    this.designation,
    this.department,
    required this.attendanceStatus,
    this.checkInTime,
    this.checkOutTime,
    this.remarks,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInDistanceMeters,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutDistanceMeters,
    required this.isMockedLocation,
  });

  factory StaffDailyAttendanceReportItem.fromJson(Map<String, dynamic> json) {
    return StaffDailyAttendanceReportItem(
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      attendanceStatus: json['attendance_status'] as String? ?? 'ABSENT',
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      remarks: json['remarks'] as String?,
      checkInLatitude: (json['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num?)?.toDouble(),
      checkInDistanceMeters: (json['check_in_distance_meters'] as num?)?.toDouble(),
      checkOutLatitude: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['check_out_longitude'] as num?)?.toDouble(),
      checkOutDistanceMeters: (json['check_out_distance_meters'] as num?)?.toDouble(),
      isMockedLocation: json['is_mocked_location'] as bool? ?? false,
    );
  }
}

class StaffDailyAttendanceSummary {
  final String date;
  final int totalTeachers;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int halfDayCount;
  final int onLeaveCount;
  final double attendanceRate;
  final List<StaffDailyAttendanceReportItem> records;

  StaffDailyAttendanceSummary({
    required this.date,
    required this.totalTeachers,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.halfDayCount,
    required this.onLeaveCount,
    required this.attendanceRate,
    required this.records,
  });

  factory StaffDailyAttendanceSummary.fromJson(Map<String, dynamic> json) {
    final list = json['records'] as List<dynamic>? ?? [];
    final recordsList = list.map((e) => StaffDailyAttendanceReportItem.fromJson(e as Map<String, dynamic>)).toList();
    return StaffDailyAttendanceSummary(
      date: json['date'] as String? ?? '',
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
      lateCount: (json['late_count'] as num?)?.toInt() ?? 0,
      halfDayCount: (json['half_day_count'] as num?)?.toInt() ?? 0,
      onLeaveCount: (json['on_leave_count'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      records: recordsList,
    );
  }
}

class StaffAttendanceHistoryItem {
  final String id;
  final String attendanceDate;
  final String status;
  final String? checkInTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkInDistanceMeters;
  final String? checkOutTime;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkOutDistanceMeters;
  final bool isMockedLocation;
  final String? remarks;
  final int? durationSeconds;

  StaffAttendanceHistoryItem({
    required this.id,
    required this.attendanceDate,
    required this.status,
    this.checkInTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInDistanceMeters,
    this.checkOutTime,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutDistanceMeters,
    required this.isMockedLocation,
    this.remarks,
    this.durationSeconds,
  });

  factory StaffAttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    return StaffAttendanceHistoryItem(
      id: json['id'] as String? ?? '',
      attendanceDate: json['attendance_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      checkInTime: json['check_in_time'] as String?,
      checkInLatitude: (json['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num?)?.toDouble(),
      checkInDistanceMeters: (json['check_in_distance_meters'] as num?)?.toDouble(),
      checkOutTime: json['check_out_time'] as String?,
      checkOutLatitude: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['check_out_longitude'] as num?)?.toDouble(),
      checkOutDistanceMeters: (json['check_out_distance_meters'] as num?)?.toDouble(),
      isMockedLocation: json['is_mocked_location'] as bool? ?? false,
      remarks: json['remarks'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }
}

class SchoolGeofenceModel {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusMeters;

  SchoolGeofenceModel({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    required this.geofenceRadiusMeters,
  });

  factory SchoolGeofenceModel.fromJson(Map<String, dynamic> json) {
    return SchoolGeofenceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters: (json['geofence_radius_meters'] as num?)?.toInt() ?? 100,
    );
  }
}
