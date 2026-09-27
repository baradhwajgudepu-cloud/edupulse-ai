import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

import 'package:admin_portal/features/school_admin/presentation/pages/school_administration_screen.dart';
import 'package:admin_portal/features/school_admin/presentation/providers/school_admin_providers.dart';
import 'package:admin_portal/features/school_admin/data/models/school_admin_models.dart';
import 'package:admin_portal/features/school_admin/presentation/widgets/document_upload_dialog.dart';
import 'package:admin_portal/features/school_admin/presentation/widgets/document_replace_dialog.dart';
import 'package:admin_portal/features/school_admin/presentation/widgets/document_preview_dialog.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/payroll/presentation/providers/payroll_providers.dart';
import 'package:admin_portal/features/payroll/data/models/payroll_models.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

// ----------------------------------------------------------------------
// Mock File Picker
// ----------------------------------------------------------------------
class FakeFilePicker extends FilePicker {
  FilePickerResult? mockResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return mockResult;
  }
}

// ----------------------------------------------------------------------
// Mock / Spy SchoolAdminActionNotifier
// ----------------------------------------------------------------------
class MockSchoolAdminActionNotifier extends StateNotifier<SchoolAdminActionState>
    implements SchoolAdminActionNotifier {
  MockSchoolAdminActionNotifier() : super(const SchoolAdminActionState());

  final List<Map<String, dynamic>> uploadCalls = [];
  final List<Map<String, dynamic>> replaceCalls = [];
  final List<Map<String, dynamic>> fetchCalls = [];
  final List<Map<String, dynamic>> unlockCalls = [];
  final List<Map<String, dynamic>> deleteCalls = [];

  Uint8List? mockFetchBytes;
  String? mockUnlockToken = 'token_test_123';
  bool uploadShouldSucceed = true;
  bool replaceShouldSucceed = true;

  @override
  Future<bool> uploadDocumentWithFile({
    required String schoolId,
    required List<int> fileBytes,
    required String fileName,
    required String category,
    required String title,
    String? issuingAuthority,
    String? documentNumber,
    String? issueDate,
    String? expiryDate,
    String confidentialityLevel = 'STANDARD',
    bool isPasswordProtected = false,
    String? passcode,
    String? remarks,
  }) async {
    uploadCalls.add({
      'schoolId': schoolId,
      'fileBytes': fileBytes,
      'fileName': fileName,
      'category': category,
      'title': title,
      'issuingAuthority': issuingAuthority,
      'documentNumber': documentNumber,
      'issueDate': issueDate,
      'expiryDate': expiryDate,
      'confidentialityLevel': confidentialityLevel,
      'isPasswordProtected': isPasswordProtected,
      'passcode': passcode,
      'remarks': remarks,
    });
    if (uploadShouldSucceed) {
      state = state.copyWith(isLoading: false, successMessage: 'Document uploaded successfully');
      return true;
    } else {
      state = state.copyWith(isLoading: false, errorMessage: 'Upload failed in test');
      return false;
    }
  }

  @override
  Future<bool> replaceDocumentFile({
    required String schoolId,
    required String documentId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    replaceCalls.add({
      'schoolId': schoolId,
      'documentId': documentId,
      'fileBytes': fileBytes,
      'fileName': fileName,
    });
    if (replaceShouldSucceed) {
      state = state.copyWith(isLoading: false, successMessage: 'Document file replaced successfully');
      return true;
    } else {
      state = state.copyWith(isLoading: false, errorMessage: 'Replace failed in test');
      return false;
    }
  }

  @override
  Future<Uint8List?> fetchDocumentBytes({
    required String documentId,
    String? unlockToken,
    bool inline = true,
  }) async {
    fetchCalls.add({
      'documentId': documentId,
      'unlockToken': unlockToken,
      'inline': inline,
    });
    return mockFetchBytes;
  }

  @override
  Future<String?> unlockDocument(String documentId, String passcode) async {
    unlockCalls.add({
      'documentId': documentId,
      'passcode': passcode,
    });
    if (passcode == 'Secret123') {
      return mockUnlockToken;
    }
    return null;
  }

  @override
  Future<bool> deleteDocument(String schoolId, String documentId) async {
    deleteCalls.add({'schoolId': schoolId, 'documentId': documentId});
    return true;
  }


  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ----------------------------------------------------------------------
// Mock Auth & School Setup Providers
// ----------------------------------------------------------------------
class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _initialUser;
  FakeAuthStateNotifier(this._initialUser);

  @override
  AuthState build() => Authenticated(_initialUser);
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState>
    implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFilePicker fakePicker;
  late MockSchoolAdminActionNotifier mockActionNotifier;

  const schoolId = 'sch-test-1';

  final dummy1x1PngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ]);

  final dummyPdfBytes = Uint8List.fromList([
    0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, // %PDF-1.4
    0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A,
  ]);

  final mockDocumentStandard = SchoolDocumentDto.fromJson({
    'id': 'doc-1',
    'school_id': schoolId,
    'title': 'Building Safety Fitness Certificate',
    'category': 'BUILDING',
    'file_name': 'Building_Safety_Certificate_2026.png',
    'file_path': 'tenants/ten-test-1/schools/sch-test-1/documents/building/doc-1_Building_Safety_Certificate_2026.png',
    'file_size_bytes': 67,
    'mime_type': 'image/png',
    'confidentiality_level': 'STANDARD',
    'is_password_protected': false,
    'issuing_authority': 'Municipal Corporation',
    'document_number': 'MC/BLD/2026/102',
    'issue_date': '2026-01-10',
    'expiry_date': '2028-01-09',
    'is_expiring_soon': false,
    'is_expired': false,
    'uploaded_by_name': 'Chief Engineer',
  });

  final mockDocumentProtected = SchoolDocumentDto.fromJson({
    'id': 'doc-2',
    'school_id': schoolId,
    'title': 'Annual Fire Safety Certificate',
    'category': 'FIRE_SAFETY',
    'file_name': 'Fire_Safety_TMS_2025.pdf',
    'file_path': 'tenants/ten-test-1/schools/sch-test-1/documents/fire_safety/doc-2_Fire_Safety_TMS_2025.pdf',
    'file_size_bytes': 524288,
    'mime_type': 'application/pdf',
    'confidentiality_level': 'CONFIDENTIAL',
    'is_password_protected': true,
    'issuing_authority': 'State Disaster & Fire Services',
    'document_number': 'FIRE/NOC/2025/88',
    'issue_date': '2025-10-15',
    'expiry_date': '2026-10-15',
    'is_expiring_soon': true,
    'days_until_expiry': 19,
    'is_expired': false,
    'uploaded_by_name': 'Safety Inspector',
  });

  setUp(() {
    fakePicker = FakeFilePicker();
    FilePicker.platform = fakePicker;
    mockActionNotifier = MockSchoolAdminActionNotifier();
  });

  Widget buildSubject(Widget child) {
    return ProviderScope(
      overrides: [
        schoolAdminActionProvider.overrideWith((ref) => mockActionNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  // ======================================================================
  // 1. DocumentUploadDialog Tests
  // ======================================================================
  group('DocumentUploadDialog Tests', () {
    testWidgets('Renders partitioned UI with Upload File and Document Details sections', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      // Dialog title & subtitle
      expect(find.text('Upload & Register Document'), findsOneWidget);
      expect(find.text('Select document file and enter official verification details.'), findsOneWidget);

      // Section 1: Upload File
      expect(find.text('1. Upload File'), findsOneWidget);
      expect(find.text('Attach official PDF or image certificate from device'), findsOneWidget);
      expect(find.text('Click or tap here to select a file from device'), findsOneWidget);
      expect(find.text('Supported formats: PDF, JPG, JPEG, PNG (Max 15 MB)'), findsOneWidget);

      // Section 2: Document Details
      expect(find.text('2. Document Details'), findsOneWidget);
      expect(find.text('Record compliance classification, dates, and security policies'), findsOneWidget);
      expect(find.text('Document Title *'), findsOneWidget);
      expect(find.text('Issuing Authority'), findsOneWidget);
      expect(find.text('Document / Order #'), findsOneWidget);
      expect(find.text('Issue Date'), findsOneWidget);
      expect(find.text('Expiry Date'), findsOneWidget);
      expect(find.text('Remarks / Notes'), findsOneWidget);
      expect(find.text('Encrypt with Secret Passcode Protection'), findsOneWidget);
      expect(find.text('Save & Upload Document'), findsOneWidget);
    });

    testWidgets('Validates missing file selection on submission', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      // Enter title
      await tester.enterText(find.widgetWithText(TextFormField, 'Document Title *'), 'State Recognition 2026');
      await tester.pumpAndSettle();

      // Tap submit without picking file
      await tester.tap(find.text('Save & Upload Document'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a document file (PDF or Image) to upload.'), findsOneWidget);
      expect(mockActionNotifier.uploadCalls.isEmpty, isTrue);
    });

    testWidgets('Rejects files exceeding 15 MB limit with clear error message', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'Heavy_Audit_Document.pdf',
          size: 16 * 1024 * 1024,
          bytes: Uint8List(100),
        ),
      ]);

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click or tap here to select a file from device'));
      await tester.pumpAndSettle();

      expect(find.textContaining('File exceeds maximum limit of 15 MB (16.0 MB).'), findsOneWidget);
    });

    testWidgets('Rejects unsupported file extensions (e.g. .docx or .txt)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'Notes.docx',
          size: 1024 * 50,
          bytes: Uint8List(100),
        ),
      ]);

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click or tap here to select a file from device'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unsupported format ".docx". Allowed: PDF, JPG, JPEG, PNG.'), findsOneWidget);
    });

    testWidgets('Successful image selection displays thumbnail preview and metadata status', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'sanitary_inspection_seal.png',
          size: dummy1x1PngBytes.length,
          bytes: dummy1x1PngBytes,
        ),
      ]);

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click or tap here to select a file from device'));
      await tester.pumpAndSettle();

      expect(find.text('sanitary_inspection_seal.png'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);
      expect(find.text('Ready to upload'), findsOneWidget);
      expect(find.text('sanitary inspection seal'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Successful PDF selection displays PDF badge and icon', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'Affiliation_Grant_Letter.pdf',
          size: 1024 * 750, // 750 KB
          bytes: dummyPdfBytes,
        ),
      ]);

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click or tap here to select a file from device'));
      await tester.pumpAndSettle();

      expect(find.text('Affiliation_Grant_Letter.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('750.0 KB'), findsOneWidget);
      expect(find.text('Ready to upload'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('Submits complete document with all metadata and password protection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'CBSE_Affiliation_2026.pdf',
          size: dummyPdfBytes.length,
          bytes: dummyPdfBytes,
        ),
      ]);

      await tester.pumpWidget(buildSubject(const DocumentUploadDialog(schoolId: schoolId)));
      await tester.pumpAndSettle();

      // 1. Pick file
      await tester.tap(find.text('Click or tap here to select a file from device'));
      await tester.pumpAndSettle();

      // 2. Fill metadata
      await tester.enterText(find.widgetWithText(TextFormField, 'Document Title *'), 'CBSE Affiliation Certificate 2026');
      await tester.enterText(find.widgetWithText(TextFormField, 'Issuing Authority'), 'Central Board of Secondary Education');
      await tester.enterText(find.widgetWithText(TextFormField, 'Document / Order #'), 'CBSE/AFF/2026/0019');
      await tester.enterText(find.widgetWithText(TextFormField, 'Remarks / Notes'), 'Permanent affiliation sanctioned by board.');

      // 3. Scroll to and toggle passcode protection, then set passcode
      final checkboxFinder = find.text('Encrypt with Secret Passcode Protection');
      await tester.ensureVisible(checkboxFinder);
      await tester.pumpAndSettle();
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final passcodeFinder = find.widgetWithText(TextFormField, 'Secret Passcode *');
      await tester.ensureVisible(passcodeFinder);
      await tester.pumpAndSettle();
      await tester.enterText(passcodeFinder, 'VaultPass2026');
      await tester.pumpAndSettle();

      // 4. Submit
      final submitFinder = find.text('Save & Upload Document');
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(mockActionNotifier.uploadCalls.length, equals(1));
      final call = mockActionNotifier.uploadCalls.first;
      expect(call['schoolId'], equals(schoolId));
      expect(call['fileName'], equals('CBSE_Affiliation_2026.pdf'));
      expect(call['title'], equals('CBSE Affiliation Certificate 2026'));
      expect(call['issuingAuthority'], equals('Central Board of Secondary Education'));
      expect(call['documentNumber'], equals('CBSE/AFF/2026/0019'));
      expect(call['remarks'], equals('Permanent affiliation sanctioned by board.'));
      expect(call['isPasswordProtected'], isTrue);
      expect(call['passcode'], equals('VaultPass2026'));
    });
  });

  // ======================================================================
  // 2. DocumentReplaceDialog Tests
  // ======================================================================
  group('DocumentReplaceDialog Tests', () {
    testWidgets('Renders existing file info and accepts replacement file', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'Fire_Safety_TMS_2026_Renewed.pdf',
          size: dummyPdfBytes.length,
          bytes: dummyPdfBytes,
        ),
      ]);

      await tester.pumpWidget(buildSubject(DocumentReplaceDialog(
        schoolId: schoolId,
        document: mockDocumentProtected,
      )));
      await tester.pumpAndSettle();

      // Header & existing document info
      expect(find.text('Replace Document File'), findsOneWidget);
      expect(find.text('Annual Fire Safety Certificate'), findsOneWidget);
      expect(find.text('Fire_Safety_TMS_2025.pdf'), findsOneWidget);

      // Select replacement file
      final pickAreaFinder = find.text('Click or tap here to choose new file');
      expect(pickAreaFinder, findsOneWidget);
      await tester.tap(pickAreaFinder);
      await tester.pumpAndSettle();

      expect(find.text('Fire_Safety_TMS_2026_Renewed.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);

      // Submit replacement
      await tester.tap(find.text('Replace File'));
      await tester.pumpAndSettle();

      expect(mockActionNotifier.replaceCalls.length, equals(1));
      final call = mockActionNotifier.replaceCalls.first;
      expect(call['schoolId'], equals(schoolId));
      expect(call['documentId'], equals('doc-2'));
      expect(call['fileName'], equals('Fire_Safety_TMS_2026_Renewed.pdf'));
    });
  });

  // ======================================================================
  // 3. DocumentPreviewDialog Tests
  // ======================================================================
  group('DocumentPreviewDialog Tests', () {
    testWidgets('Renders unlocked image document preview with zoom capabilities', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Mock return image bytes
      mockActionNotifier.mockFetchBytes = dummy1x1PngBytes;

      await tester.pumpWidget(buildSubject(DocumentPreviewDialog(
        schoolId: schoolId,
        document: mockDocumentStandard,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Building Safety Fitness Certificate'), findsOneWidget);
      expect(find.textContaining('Building_Safety_Certificate_2026.png'), findsOneWidget);
      expect(find.textContaining('Municipal Corporation'), findsOneWidget);
      expect(find.textContaining('2026-01-10'), findsOneWidget);

      // Interactive viewer image is rendered
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Download button is available
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('Requires secret passcode to unlock and stream protected document', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockActionNotifier.mockFetchBytes = dummyPdfBytes;

      await tester.pumpWidget(buildSubject(DocumentPreviewDialog(
        schoolId: schoolId,
        document: mockDocumentProtected,
      )));
      await tester.pumpAndSettle();

      // Locked state UI
      expect(find.text('Password Protected Document'), findsOneWidget);
      expect(find.textContaining('Enter the passcode to unlock and view.'), findsOneWidget);
      expect(find.text('Unlock Document'), findsOneWidget);

      // Enter secret passcode and tap unlock
      await tester.enterText(find.widgetWithText(TextField, 'Secret Passcode'), 'Secret123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock Document'));
      await tester.pumpAndSettle();

      // Assert unlock was called with passcode
      expect(mockActionNotifier.unlockCalls.length, equals(1));
      expect(mockActionNotifier.unlockCalls.first['passcode'], equals('Secret123'));

      // Now unlocked, streams document bytes with token
      expect(mockActionNotifier.fetchCalls.length, equals(1));
      expect(mockActionNotifier.fetchCalls.first['unlockToken'], equals('token_test_123'));

      // PDF preview card shown with official download button
      expect(find.text('Download Official PDF Document'), findsOneWidget);
    });
  });

  // ======================================================================
  // 4. SchoolAdministrationScreen Documents Vault Tab Integration
  // ======================================================================
  group('SchoolAdministrationScreen Documents Vault Tab Integration', () {
    const mockUser = UserEntity(
      id: 'usr-admin-1',
      firstName: 'Admin',
      lastName: 'Officer',
      email: 'admin@telangana-model.edu',
      tenantId: 'ten-test-1',
      isSuperuser: false,
      roles: ['PRINCIPAL'],
      schools: [schoolId],
      schoolNames: {schoolId: 'Telangana Model School'},
    );

    const mockSchool = SchoolDto(
      id: schoolId,
      tenantId: 'ten-test-1',
      name: 'Telangana Model School',
      code: 'TMS01',
      board: 'STATE',
      schoolType: 'K12',
      email: 'info@tms.edu',
      isActive: true,
      status: 'ACTIVE',
      version: 1,
    );

    final mockProfile = SchoolProfileDto.fromJson({
      'id': 'prof-1',
      'tenant_id': 'ten-test-1',
      'school_id': schoolId,
      'school_name': 'Telangana Model School',
      'school_code': 'TMS01',
      'email': 'info@tms.edu',
      'phone': '+91 98765 43210',
      'state': 'Telangana',
      'board': 'STATE',
      'udise_code': '36140500101',
      'udise_status': 'VERIFIED',
      'udise_verification_status': 'VERIFIED',
      'udise_verified_at': '2025-06-15T10:00:00Z',
      'udise_verified_by_name': 'District Educational Officer',
      'udise_notes': 'Authoritatively verified via Telangana DSE portal.',
      'custom_values': {'Transport Facility': 'Yes', 'Hostel Facility': 'No'},
    });

    const mockCompliance = ComplianceDashboardDto(
      schoolId: schoolId,
      schoolName: 'Telangana Model School',
      udiseCode: '36140500101',
      udiseConfigured: true,
      udiseVerificationStatus: 'VERIFIED',
      totalRecognitions: 2,
      activeRecognitions: 2,
      centralRecognitionsCount: 1,
      stateRecognitionsCount: 1,
      totalDocuments: 2,
      confidentialDocumentsCount: 1,
      expiringDocumentsCount: 1,
      expiredDocumentsCount: 0,
      payrollPolicyConfigured: true,
      payrollReady: true,
      teachersCount: 25,
      pendingPayrollCount: 0,
      approvedPayrollCount: 25,
    );

    final mockExpiryMonitor = DocumentExpiryMonitorDto.fromJson({
      'total_monitored': 2,
      'expiring_soon_count': 1,
      'expired_count': 0,
      'alerts': [
        {
          'document_id': 'doc-2',
          'title': 'Annual Fire Safety Certificate',
          'category': 'FIRE_SAFETY',
          'expiry_date': '2026-10-15',
          'days_remaining': 19,
          'is_expired': false,
          'recommended_action': 'Initiate Fire Dept inspection for NOC renewal.',
        }
      ],
      'missing_mandatory_categories': <String>[],
    });

    final mockPolicy = PayrollPolicyDto.fromJson({
      'id': 'pol-1',
      'school_id': schoolId,
      'policy_name': 'Standard Policy',
      'calculation_basis': 'WORKING_DAYS',
      'standard_working_days': 24,
      'daily_rate_formula': 'GROSS_DIVIDED_BY_WORKING_DAYS',
      'half_day_deduction_factor': 0.50,
      'unpaid_leave_deduction_factor': 1.00,
      'late_grace_count': 3,
      'late_deduction_factor': 0.25,
      'is_active': true,
    });

    Widget createScreenSubject() {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
          selectedSchoolIdProvider.overrideWith((ref) => schoolId),
          schoolsListProvider.overrideWith(
            (ref) => FakeSchoolsListNotifier(
              const SchoolsListState(schools: [mockSchool], isLoading: false),
            ),
          ),
          schoolDetailProvider(schoolId).overrideWith((ref) => Future.value(mockSchool)),
          schoolProfileProvider(schoolId).overrideWith((ref) => Future.value(mockProfile)),
          complianceDashboardProvider(schoolId).overrideWith((ref) => Future.value(mockCompliance)),
          schoolRecognitionsProvider(schoolId).overrideWith((ref) => Future.value([])),
          schoolDocumentsProvider(schoolId).overrideWith((ref) => Future.value([mockDocumentStandard, mockDocumentProtected])),
          documentExpiryMonitorProvider(schoolId).overrideWith((ref) => Future.value(mockExpiryMonitor)),
          documentAccessLogsProvider(schoolId).overrideWith((ref) => Future.value([])),
          schoolCustomFieldsProvider(schoolId).overrideWith((ref) => Future.value([])),
          payrollPoliciesProvider(schoolId).overrideWith((ref) => Future.value([mockPolicy])),
          schoolAdminActionProvider.overrideWith((ref) => mockActionNotifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SchoolAdministrationScreen(initialTab: 5),
          ),
        ),
      );
    }

    testWidgets('Displays document cards with action triggers for Upload, Preview, and Replace', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createScreenSubject());
      await tester.pumpAndSettle();

      // Verify Documents Vault screen header
      expect(find.text('Institutional Documents & Secure Vault'), findsOneWidget);
      expect(find.text('Upload Document'), findsOneWidget);

      // Verify documents are rendered
      expect(find.text('Building Safety Fitness Certificate'), findsOneWidget);
      expect(find.text('Annual Fire Safety Certificate'), findsOneWidget);

      // Tap 'Upload Document' button to ensure DocumentUploadDialog is launched
      await tester.tap(find.text('Upload Document'));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentUploadDialog), findsOneWidget);
      expect(find.text('1. Upload File'), findsOneWidget);
      expect(find.text('2. Document Details'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentUploadDialog), findsNothing);
    });
  });
}
