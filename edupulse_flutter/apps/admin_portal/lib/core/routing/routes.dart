class AppRoutes {
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String dashboard = '/dashboard';
  static const String users = '/users';
  static const String userDetail = '/users/:id';
  static const String tenants = '/tenants';
  
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

  static const String results = '/results';
  static const String examTypes = '/results/exam-types';
  static const String examinations = '/results/examinations';
  static const String marksManagement = '/results/marks-management';
  static const String studentResultDetail = '/results/students/:studentId';
  static const String reportCards = '/results/report-cards';
  static const String reportCardDetail = '/results/report-cards/:studentId';

  static const String migrations = '/migrations';
  static const String migrationNew = '/migrations/students/new';
  static const String migrationDetail = '/migrations/students/:jobId';
  static const String academicSetupMigrationNew = '/migrations/academic-setup/new';
  static const String academicSetupMigrationDetail = '/migrations/academic-setup/:jobId';
  static const String guardianMappingMigrationNew = '/migrations/guardian-mapping/new';
  static const String guardianMappingMigrationDetail = '/migrations/guardian-mapping/:jobId';
  static const String guardianMigrationNew = '/migrations/guardians/new';
  static const String guardianMigrationDetail = '/migrations/guardians/:jobId';

  static const String teachers = '/teachers';
  static const String teacherDetail = '/teachers/:id';

  static const String attendance = '/attendance';
  static const String attendanceSessionDetail = '/attendance/:sessionId';

  static const String guardians = '/guardians';
  static const String guardianDetail = '/guardians/:id';
  static const String promotions = '/promotions';

  static const String reports = '/reports';

  static const String connectAnalytics = '/connect-analytics';
  static const String settings = '/settings';
  static const String notifications = '/notifications';

  // School Planner Routes
  static const String plannerCalendar = '/planner/calendar';
  static const String plannerEvents = '/planner/events';
  static const String plannerAnnouncements = '/planner/announcements';
  static const String plannerCirculars = '/planner/circulars';
  static const String plannerExams = '/planner/exams';
  static const String plannerSchedule = '/planner/schedule';

  // AI School Intelligence
  static const String aiIntelligence = '/ai-intelligence';
}


