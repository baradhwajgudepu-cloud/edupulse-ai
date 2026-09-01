import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasource/dashboard_remote_datasource.dart';
import '../mappers/dashboard_mapper.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDatasource _remoteDatasource;

  const DashboardRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<DashboardSummaryEntity>> getDashboardSummary({
    required String schoolId,
  }) async {
    final result =
        await _remoteDatasource.getDashboardSummary(schoolId: schoolId);
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
