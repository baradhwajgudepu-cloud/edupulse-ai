import 'package:edupulse_network/edupulse_network.dart';
import '../entities/dashboard_data.dart';

abstract class DashboardRepository {
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  });
}
