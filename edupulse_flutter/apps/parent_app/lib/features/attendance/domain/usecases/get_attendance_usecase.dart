import 'package:edupulse_network/edupulse_network.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceUseCase {
  final AttendanceRepository _repository;

  const GetAttendanceUseCase(this._repository);

  Future<ApiResult<List<AttendanceRecordEntity>>> call({
    required String studentId,
    required String academicYearId,
    required String schoolId,
  }) {
    return _repository.getAttendanceRecords(
      studentId: studentId,
      academicYearId: academicYearId,
      schoolId: schoolId,
    );
  }
}
