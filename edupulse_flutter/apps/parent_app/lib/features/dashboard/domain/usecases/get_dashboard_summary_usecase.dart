import 'package:edupulse_network/edupulse_network.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  final DashboardRepository _repository;

  const GetDashboardSummaryUseCase(this._repository);

  Future<ApiResult<DashboardSummaryEntity>> call({required String schoolId}) {
    return _repository.getDashboardSummary(schoolId: schoolId);
  }
}
