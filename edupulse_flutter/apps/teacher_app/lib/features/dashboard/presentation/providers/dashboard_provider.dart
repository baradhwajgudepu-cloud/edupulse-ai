import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../data/datasource/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardSuccess extends DashboardState {
  final DashboardDataEntity data;
  final String selectedDayOfWeek;
  const DashboardSuccess(this.data, this.selectedDayOfWeek);
}

class DashboardRefreshing extends DashboardState {
  final DashboardDataEntity data;
  final String selectedDayOfWeek;
  const DashboardRefreshing(this.data, this.selectedDayOfWeek);
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
}

class DashboardEmpty extends DashboardState {
  const DashboardEmpty();
}

final dashboardRemoteDatasourceProvider = Provider<DashboardRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRemoteDatasource(apiClient);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final remote = ref.watch(dashboardRemoteDatasourceProvider);
  return DashboardRepositoryImpl(remote);
});

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return const DashboardInitial();
  }

  String getBackendDayOfWeek(int dartWeekday) {
    switch (dartWeekday) {
      case 1:
        return 'MONDAY';
      case 2:
        return 'TUESDAY';
      case 3:
        return 'WEDNESDAY';
      case 4:
        return 'THURSDAY';
      case 5:
        return 'FRIDAY';
      case 6:
        return 'SATURDAY';
      case 7:
        return 'SUNDAY';
      default:
        return 'MONDAY';
    }
  }

  Future<void> fetchDashboard() async {
    final current = state;
    if (current is DashboardSuccess) {
      state = DashboardRefreshing(current.data, current.selectedDayOfWeek);
    } else if (current is! DashboardRefreshing) {
      state = const DashboardLoading();
    }

    final authState = ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const DashboardError('User is not authenticated.');
      return;
    }

    final user = authState.user;
    final schoolId = user.schools.isNotEmpty ? user.schools.first : null;
    if (schoolId == null) {
      state = const DashboardError('No school associated with this teacher account.');
      return;
    }

    final repo = ref.read(dashboardRepositoryProvider);
    final result = await repo.getDashboardData(
      schoolId: schoolId,
      email: user.email,
    );

    result.when(
      onSuccess: (data) {
        final today = DateTime.now();
        final defaultDay = getBackendDayOfWeek(today.weekday);
        state = DashboardSuccess(data, defaultDay);
      },
      onFailure: (failure) {
        if (failure.message.contains('active academic year')) {
          state = const DashboardError('NO_ACTIVE_ACADEMIC_YEAR');
        } else if (failure.message.contains('Teacher profile not found')) {
          state = const DashboardError('NO_TEACHER_PROFILE');
        } else {
          state = DashboardError(failure.message);
        }
      },
    );
  }

  void selectDay(String dayOfWeek) {
    final current = state;
    if (current is DashboardSuccess) {
      state = DashboardSuccess(current.data, dayOfWeek);
    } else if (current is DashboardRefreshing) {
      state = DashboardRefreshing(current.data, dayOfWeek);
    }
  }
}

final dashboardStateProvider = NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
