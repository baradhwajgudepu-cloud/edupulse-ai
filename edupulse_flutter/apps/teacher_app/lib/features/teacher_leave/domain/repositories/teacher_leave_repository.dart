import 'package:edupulse_network/edupulse_network.dart';
import '../entities/teacher_leave_entity.dart';

abstract class TeacherLeaveRepository {
  Future<ApiResult<TeacherLeaveEntity>> createLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? remarks,
  });

  Future<ApiResult<List<TeacherLeaveEntity>>> getMyLeaves();

  Future<ApiResult<TeacherLeaveEntity>> getLeave(String leaveId);

  Future<ApiResult<TeacherLeaveEntity>> cancelLeave({
    required String leaveId,
    required String cancellationReason,
  });
}
