import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasource/attendance_remote_datasource.dart';
import '../mappers/attendance_mapper.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDatasource _remoteDatasource;

  const AttendanceRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<List<AttendanceRecordEntity>>> getAttendanceRecords({
    required String studentId,
    required String academicYearId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getAttendanceRecords(
      studentId: studentId,
      academicYearId: academicYearId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (list) =>
          ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
