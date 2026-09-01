import 'package:edupulse_network/edupulse_network.dart';
import '../models/dashboard_summary_dto.dart';

class DashboardRemoteDatasource {
  final BaseApiClient _apiClient;

  const DashboardRemoteDatasource(this._apiClient);

  Future<ApiResult<DashboardSummaryDto>> getDashboardSummary({
    required String schoolId,
  }) {
    return _apiClient.get(
      '/fees/reports/dashboard',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return DashboardSummaryDto.fromJson(
            payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
