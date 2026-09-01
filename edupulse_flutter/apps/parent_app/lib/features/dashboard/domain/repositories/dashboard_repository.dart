import 'package:edupulse_network/edupulse_network.dart';
import '../entities/dashboard_summary.dart';

abstract class DashboardRepository {
  Future<ApiResult<DashboardSummaryEntity>> getDashboardSummary({
    required String schoolId,
  });
}
