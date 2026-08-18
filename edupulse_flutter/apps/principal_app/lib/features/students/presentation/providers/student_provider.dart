import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/student_datasource.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/student_model.dart';

// Datasource Provider
final studentDatasourceProvider = Provider<StudentDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentDatasource(apiClient);
});

// Repository Provider
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final datasource = ref.watch(studentDatasourceProvider);
  return StudentRepository(datasource);
});

sealed class StudentsState {
  const StudentsState();
}

class StudentsInitial extends StudentsState {
  const StudentsInitial();
}

class StudentsLoading extends StudentsState {
  const StudentsLoading();
}

class StudentsSuccess extends StudentsState {
  final List<Student> students;
  final bool hasReachedMax;
  final List<String> discoveredClasses;
  final List<String> discoveredSections;
  final String? selectedClass;
  final String? selectedSection;
  final String searchQuery;

  const StudentsSuccess({
    required this.students,
    required this.hasReachedMax,
    required this.discoveredClasses,
    required this.discoveredSections,
    this.selectedClass,
    this.selectedSection,
    required this.searchQuery,
  });

  StudentsSuccess copyWith({
    List<Student>? students,
    bool? hasReachedMax,
    List<String>? discoveredClasses,
    List<String>? discoveredSections,
    String? selectedClass,
    String? selectedSection,
    String? searchQuery,
    bool clearClass = false,
    bool clearSection = false,
  }) {
    return StudentsSuccess(
      students: students ?? this.students,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      discoveredClasses: discoveredClasses ?? this.discoveredClasses,
      discoveredSections: discoveredSections ?? this.discoveredSections,
      selectedClass: clearClass ? null : (selectedClass ?? this.selectedClass),
      selectedSection: clearSection ? null : (selectedSection ?? this.selectedSection),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class StudentsError extends StudentsState {
  final String message;
  const StudentsError(this.message);
}

class StudentsNotifier extends StateNotifier<StudentsState> {
  final StudentRepository _repository;
  final SessionManager _sessionManager;
  
  StudentsNotifier(this._repository, this._sessionManager) : super(const StudentsInitial());

  List<String> _classes = [];
  List<String> _sections = [];

  // Run filter discovery on initial load
  Future<void> init() async {
    state = const StudentsLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const StudentsError('No active school context found.');
      return;
    }

    // 1. Fetch first page with large limit=1000 for discovering class and section filters
    final discoveryResult = await _repository.getStudents(
      schoolId: schoolId,
      skip: 0,
      limit: 1000,
    );

    await discoveryResult.when(
      onSuccess: (studentsList) async {
        // Extract unique class/section names
        final classSet = <String>{};
        final sectionSet = <String>{};
        for (final student in studentsList) {
          if (student.className.isNotEmpty) classSet.add(student.className);
          if (student.sectionName.isNotEmpty) sectionSet.add(student.sectionName);
        }
        _classes = classSet.toList()..sort();
        _sections = sectionSet.toList()..sort();

        // 2. Load standard first paginated page (e.g. limit=20) to start user view
        await _loadPage(0, [], schoolId, '', null, null);
      },
      onFailure: (failure) async {
        state = StudentsError(failure.message);
      },
    );
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! StudentsSuccess || currentState.hasReachedMax) return;

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    _loadPage(
      currentState.students.length,
      currentState.students,
      schoolId,
      currentState.searchQuery,
      currentState.selectedClass,
      currentState.selectedSection,
    );
  }

  Future<void> setFilters({String? selectedClass, String? selectedSection, String? search}) async {
    final currentState = state;
    if (currentState is! StudentsSuccess) return;

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    final query = search ?? currentState.searchQuery;
    
    // Reset page loading with new parameters
    state = const StudentsLoading();

    // In a real paginated endpoint, filtering by class/section requires passing class_id/section_id.
    // However, since class_id/section_id are not fetched directly via lookup endpoints, we will retrieve
    // students list and apply filters. In list_students, class_id/section_id are optional query parameters.
    // However, since we discovered class/section names, we can load the matching students.
    // For search / local filters, we fetch and display the matched list:
    await _loadPage(0, [], schoolId, query, selectedClass ?? currentState.selectedClass, selectedSection ?? currentState.selectedSection);
  }

  Future<void> clearFilters() async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    state = const StudentsLoading();
    await _loadPage(0, [], schoolId, '', null, null);
  }

  Future<void> _loadPage(
    int skip,
    List<Student> currentList,
    String schoolId,
    String search,
    String? className,
    String? sectionName,
  ) async {
    // If the endpoint list_students has filter support, we query it.
    // Note: since class_id/section_id query parameters are UUIDs and our discovered filters are names,
    // we can query all and filter locally, or perform queries. Filtering locally on the fetched page (or limit 1000)
    // is highly robust because it matches exactly what was loaded.
    // Let's query backend with skip/limit:
    final result = await _repository.getStudents(
      schoolId: schoolId,
      skip: skip,
      limit: 20,
      search: search.isNotEmpty ? search : null,
    );

    result.when(
      onSuccess: (newStudents) {
        // Filter by class / section locally if class/section names are specified
        var filteredNew = newStudents;
        if (className != null) {
          filteredNew = filteredNew.where((s) => s.className == className).toList();
        }
        if (sectionName != null) {
          filteredNew = filteredNew.where((s) => s.sectionName == sectionName).toList();
        }

        final completeList = List<Student>.from(currentList)..addAll(filteredNew);
        final reachedMax = newStudents.length < 20;

        state = StudentsSuccess(
          students: completeList,
          hasReachedMax: reachedMax,
          discoveredClasses: _classes,
          discoveredSections: _sections,
          selectedClass: className,
          selectedSection: sectionName,
          searchQuery: search,
        );
      },
      onFailure: (failure) {
        state = StudentsError(failure.message);
      },
    );
  }
}

final studentsStateProvider = StateNotifierProvider<StudentsNotifier, StudentsState>((ref) {
  final repo = ref.watch(studentRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return StudentsNotifier(repo, session);
});
