import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/src/base_api_client.dart';
import 'package:edupulse_network/src/interceptors/jwt_interceptor.dart';
import 'package:edupulse_network/src/token_provider.dart';

class FakeTokenProvider implements AuthTokenProvider {
  final String? accessToken;
  final String? schoolId;

  FakeTokenProvider({this.accessToken, this.schoolId});

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> refreshSession() async {}

  @override
  Future<String?> getSchoolId() async => schoolId;
}

void main() {
  test('BaseApiClient request URL resolution test', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://192.168.31.132:8000/api/v1/'));
    final List<String> resolvedUrls = [];
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        resolvedUrls.add(options.uri.toString());
        handler.reject(DioException(
          requestOptions: options,
          error: 'Bypassing actual request',
        ));
      },
    ));

    final client = BaseApiClient(dio);

    final pathsToTest = [
      '/fees/reports/dashboard',
      '/notifications',
      '/examinations',
      '/attendances/daily',
      '/students',
      '/teachers',
      'fees/reports/dashboard',
      'notifications',
    ];

    for (final path in pathsToTest) {
      try {
        await client.get(path, mapper: (_) => _);
      } catch (_) {}
    }

    expect(resolvedUrls.length, pathsToTest.length);
    for (int i = 0; i < resolvedUrls.length; i++) {
      final url = resolvedUrls[i];
      final path = pathsToTest[i];
      // ignore: avoid_print
      print('Path: $path -> Resolved: $url');
      expect(url.contains('/api/v1/'), isTrue);
    }
  });

  test('JwtInterceptor path context check tests', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1/'));
    
    final mockTokenProvider = FakeTokenProvider(
      accessToken: 'token_123',
      schoolId: null,
    );
    
    dio.interceptors.add(JwtInterceptor(
      tokenProvider: mockTokenProvider,
      tenantId: 'tenant_123',
    ));
    
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'status': 'success'},
        ));
      },
    ));

    // List of paths that should NOT require school context (should succeed)
    final pathsNotRequiringContext = [
      '/schools',
      '/schools/',
      '/api/v1/schools',
      '/api/v1/schools/',
      'http://127.0.0.1:8000/api/v1/schools',
      'https://example.com/api/v1/schools',
      '/api/v1/schools/d09b9362-3dc8-422d-a441-160735fcea96',
      '/api/v1/schools/d09b9362-3dc8-422d-a441-160735fcea96/',
      '/api/v1/schools/d09b9362-3dc8-422d-a441-160735fcea96/academic-years',
      '/import-jobs/parse',
      '/auth/login',
    ];

    for (final path in pathsNotRequiringContext) {
      try {
        final result = await dio.post(path);
        expect(result.statusCode, 200);
      } catch (e) {
        fail('Path $path unexpectedly failed/cancelled: $e');
      }
    }

    // List of paths that SHOULD require school context (should be rejected/cancelled)
    final pathsRequiringContext = [
      '/classes',
      '/sections',
      '/subjects',
      '/teachers',
    ];

    for (final path in pathsRequiringContext) {
      try {
        await dio.post(path);
        fail('Path $path unexpectedly succeeded when school context was missing');
      } catch (e) {
        expect(e, isA<DioException>());
        final de = e as DioException;
        expect(de.type, DioExceptionType.cancel);
        expect(de.error, 'Active school context required.');
      }
    }
  });
}
