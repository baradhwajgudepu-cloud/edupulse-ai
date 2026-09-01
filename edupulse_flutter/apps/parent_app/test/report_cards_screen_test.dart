import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:parent_app/features/report_cards/presentation/pages/report_cards_screen.dart';
import 'package:parent_app/features/homework/presentation/providers/homework_provider.dart';
import 'package:parent_app/features/homework/domain/usecases/download_attachment_usecase.dart';
import 'package:parent_app/core/providers/bootstrap_provider.dart';
import 'package:edupulse_files/edupulse_files.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'access', refreshToken: 'refresh', tokenType: 'bearer'));
  }
  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async => const ApiResult.success(null);
  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'access_new', refreshToken: 'refresh_new', tokenType: 'bearer'));
  }
  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(UserEntity(
      id: '123',
      email: 'parent@edupulse.ai',
      firstName: 'John',
      lastName: 'Doe',
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      isSuperuser: false,
      roles: ['parent'],
      schools: ['school_1'],
    ));
  }
  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async => const ApiResult.success(null);
}

class FakeSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'access';
  @override
  Future<String?> getRefreshToken() async => 'refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class TestBaseApiClient extends BaseApiClient {
  TestBaseApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/report-cards/student/')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'rc_1',
          'status': 'PUBLISHED',
          'pdf_url': '/static/report_cards/report.pdf',
          'published_at': '2026-08-02',
          'school_id': 'school_1',
          'ai_metrics': {
            'risk_level': 'LOW',
            'ai_narrative': 'Test narrative'
          }
        }
      }));
    }
    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
  }
}

class FakeDownloadAttachmentUseCase extends DownloadAttachmentUseCase {
  final ApiResult<String> result;
  final void Function(String url, String? filename)? onCall;

  FakeDownloadAttachmentUseCase(this.result, {this.onCall})
      : super(const FileDownloadService(StorageManager()));

  @override
  Future<ApiResult<String>> call({
    required String url,
    String? filename,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    if (onCall != null) {
      onCall!(url, filename);
    }
    if (onProgress != null) {
      onProgress(50, 100);
      onProgress(100, 100);
    }
    return result;
  }
}

class FakeStorageManager implements StorageManager {
  final String tempDir;
  const FakeStorageManager(this.tempDir);

  @override
  Future<String> getDownloadsDirectoryPath() async {
    return tempDir;
  }

  @override
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
}

void main() {
  late Directory tempDir;
  late FakeStorageManager fakeStorage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('report_card_test_');
    fakeStorage = FakeStorageManager(tempDir.path);
    
    // Stub open_filex platform MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_filex'),
      (MethodCall methodCall) async {
        return {'type': 0, 'message': 'done'};
      },
    );
  });

  tearDown(() {
    // Clear MethodChannel mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_filex'),
      null,
    );
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('ReportCardsScreen renders download button, performs successful download and error handling', (WidgetTester tester) async {
    String? downloadedUrl;
    String? downloadedFilename;
    
    final fakeDownload = FakeDownloadAttachmentUseCase(
      ApiResult.success('${tempDir.path}/EduPulse_ReportCard_Rahul_Sharma.pdf'),
      onCall: (url, filename) {
        downloadedUrl = url;
        downloadedFilename = filename;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          apiClientProvider.overrideWithValue(TestBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          storageManagerProvider.overrideWithValue(fakeStorage),
          downloadAttachmentUseCaseProvider.overrideWithValue(fakeDownload),
        ],
        child: const MaterialApp(
          home: ReportCardsScreen(),
        ),
      ),
    );

    // 1. Verify screen renders child info and download button
    await tester.pumpAndSettle();
    expect(find.text('Student: Rahul Sharma'), findsOneWidget);
    expect(find.text('Download PDF Report'), findsOneWidget);

    // 2. Tap Download and verify callback params
    await tester.runAsync(() async {
      await tester.tap(find.text('Download PDF Report'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Verify it called download with correct filename and resolved/normalized url
    expect(downloadedFilename, 'EduPulse_ReportCard_Rahul_Sharma.pdf');
    expect(downloadedUrl, isNotNull);
    expect(downloadedUrl!.contains('//report-cards'), false); // normalized path check

    // Verify success snackbar appears
    expect(find.text('Report card downloaded successfully'), findsOneWidget);
  });

  testWidgets('ReportCardsScreen download failure maps and displays friendly message', (WidgetTester tester) async {
    final fakeDownload = FakeDownloadAttachmentUseCase(
      const ApiResult.failure(ApiFailure(message: 'Report card not found.', type: ApiFailureType.unknown)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          apiClientProvider.overrideWithValue(TestBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          storageManagerProvider.overrideWithValue(fakeStorage),
          downloadAttachmentUseCaseProvider.overrideWithValue(fakeDownload),
        ],
        child: const MaterialApp(
          home: ReportCardsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Download PDF Report'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Verify mapped error message is rendered
    expect(find.text('Report card not found.'), findsOneWidget);
  });
}
