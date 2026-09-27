class AppRoutes {
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String privacyPolicy = '/privacy-policy';
  static const String dashboard = '/dashboard';
  static const String users = '/users';
  static const String userDetail = '/users/:id';
  static const String rolesPermissions = '/roles-permissions';
  static const String tenants = '/tenants';
  static const String unauthorized = '/unauthorized';
  
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
  static const String teacherAssignments = '/teacher-assignments';
  
  static const String students = '/students';

  static const String schoolSetup = '/school-setup';
  static const String schoolAdministration = '/school-admin';
  static const String rooms = '/rooms';
  static const String studentDetail = '/students/:id';
  static const String bulkImport = '/bulk-import';
  static const String schoolOnboarding = '/school-onboarding';
  static const String fees = '/fees';
  static const String feesAssign = '/fees/assign';
  static const String feesLedger = '/fees/ledger';
  static const String feesOutstanding = '/fees/outstanding';
  static const String salaries = '/fees/salaries';
  static const String expenses = '/fees/expenses';

  static const String results = '/results';
  static const String examTypes = '/results/exam-types';
  static const String examinations = '/results/examinations';
  static const String examinationDashboard = '/results/examinations/:examId';
  static const String examinationDetail = '/results/examinations/:id';
  static const String marksManagement = '/results/marks-management';
  static const String marksImport = '/results/import-marks';
  static const String studentResultDetail = '/results/students/:studentId';
  static const String resultsPublishing = '/results/publishing';
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
  static const String attendanceDashboard = '/attendance';
  static const String attendanceMark = '/attendance/mark';
  static const String attendanceRegister = '/attendance/register';
  static const String attendanceUpload = '/attendance/upload';
  static const String attendanceBulkUpload = '/attendance/bulk-upload';
  static const String attendanceImports = '/attendance/imports';
  static const String attendanceImportHistory = '/attendance/import-history';
  static const String attendanceAudit = '/attendance/audit';
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
  static const String timetables = '/planner/timetables';
  static const String syllabusEditor = '/planner/syllabus';
  static const String academicPlanning = '/planner/academic-planning';

  // AI School Intelligence
  static const String aiIntelligence = '/ai-intelligence';
}


