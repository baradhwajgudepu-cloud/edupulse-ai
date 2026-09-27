import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_core/edupulse_core.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/my_classes/presentation/providers/my_classes_provider.dart';
import '../../features/student_directory/presentation/providers/student_directory_provider.dart';
import '../../features/homework/presentation/providers/homework_provider.dart';
import '../../features/events/presentation/providers/events_provider.dart';

/// Holds the currently active school ID for the logged-in teacher.
final activeSchoolIdProvider = StateProvider<String?>((ref) {
  // Derive default from authState if not explicitly selected
  final authState = ref.watch(authStateProvider);
  if (authState is Authenticated && authState.user.schools.isNotEmpty) {
    return authState.user.schools.first;
  }
  return null;
});

/// Derives the human-readable name of the currently active school.
final activeSchoolNameProvider = Provider<String>((ref) {
  final activeId = ref.watch(activeSchoolIdProvider);
  final authState = ref.watch(authStateProvider);
  if (activeId == null || authState is! Authenticated) {
    return 'Active School';
  }
  return authState.user.schoolNames[activeId] ?? 'School: ${activeId.substring(0, activeId.length > 8 ? 8 : activeId.length)}';
});

/// Controller to safely switch active school context and persist it.
class SchoolContextController {
  final Ref _ref;

  SchoolContextController(this._ref);

  Future<void> switchSchool(String schoolId) async {
    try {
      final sessionManager = _ref.read(sessionManagerProvider);
      final authState = _ref.read(authStateProvider);

      String schoolName = 'School';
      if (authState is Authenticated) {
        schoolName = authState.user.schoolNames[schoolId] ?? 'School: $schoolId';
      }

      await sessionManager.saveSchoolId(schoolId);
      await sessionManager.saveSchoolName(schoolName);

      _ref.read(activeSchoolIdProvider.notifier).state = schoolId;

      // Invalidate school-scoped cached state to prevent cross-school data contamination
      _ref.invalidate(dashboardStateProvider);
      _ref.invalidate(myClassesStateProvider);
      _ref.invalidate(studentDirectoryStateProvider);
      _ref.invalidate(homeworkListProvider);
      _ref.invalidate(eventsProvider);

      EduLogger.i('Active school context successfully switched to: $schoolId ($schoolName)');

      // Re-hydrate active school context data
      await _ref.read(dashboardStateProvider.notifier).fetchDashboard();
      await _ref.read(myClassesStateProvider.notifier).fetchClasses();
    } catch (e) {
      EduLogger.e('Failed to switch school context: $e');
    }
  }
}

final schoolContextControllerProvider = Provider<SchoolContextController>((ref) {
  return SchoolContextController(ref);
});
