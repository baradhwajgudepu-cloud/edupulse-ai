class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String users = '/users';
  static const String userDetail = '/users/:id';
  
  static const String schools = '/schools';
  static const String schoolDetail = '/schools/:id';
  static const String academicYears = '/schools/:schoolId/academic-years';
  static const String academicYearDetail = '/schools/:schoolId/academic-years/:id';
  static const String classes = '/classes';
  static const String classDetail = '/classes/:id';
  static const String sections = '/sections';
  static const String sectionDetail = '/sections/:id';
  static const String subjects = '/subjects';
  static const String subjectDetail = '/subjects/:id';
  
  static const String students = '/students';
  static const String studentDetail = '/students/:id';
  static const String bulkImport = '/bulk-import';
  static const String schoolOnboarding = '/school-onboarding';
  static const String fees = '/fees';
  static const String feesAssign = '/fees/assign';
  static const String feesLedger = '/fees/ledger';
  static const String feesOutstanding = '/fees/outstanding';

  static const String migrations = '/migrations';
  static const String migrationNew = '/migrations/students/new';
  static const String migrationDetail = '/migrations/students/:jobId';
  static const String academicSetupMigrationNew = '/migrations/academic-setup/new';
  static const String academicSetupMigrationDetail = '/migrations/academic-setup/:jobId';
  static const String guardianMappingMigrationNew = '/migrations/guardian-mapping/new';
  static const String guardianMappingMigrationDetail = '/migrations/guardian-mapping/:jobId';
}


