import 'package:dio/dio.dart';
import '../token_provider.dart';

class JwtInterceptor extends Interceptor {
  final AuthTokenProvider? _tokenProvider;
  final String? _tenantId;
  final String? Function()? _tenantIdGetter;

  JwtInterceptor({
    AuthTokenProvider? tokenProvider,
    String? tenantId,
    String? Function()? tenantIdGetter,
  })  : _tokenProvider = tokenProvider,
        _tenantId = tenantId,
        _tenantIdGetter = tenantIdGetter;

  bool _pathRequiresSchoolContext(String path) {
    String cleanPath = path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        cleanPath = uri.path;
      }
    }

    final cleanPathForCheck = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    if (cleanPathForCheck.contains('/auth/') ||
        cleanPathForCheck.contains('/notification') ||
        cleanPathForCheck.contains('/system/') ||
        cleanPathForCheck.contains('/health') ||
        cleanPathForCheck.contains('/tenants') ||
        cleanPathForCheck.contains('/platform/') ||
        cleanPathForCheck.contains('/roles') ||
        cleanPathForCheck.contains('/permissions') ||
        cleanPathForCheck.contains('/import-jobs/parse') ||
        cleanPathForCheck.contains('/reports/ai-intelligence') ||
        cleanPathForCheck.contains('/ai-intelligence') ||
        cleanPathForCheck.contains('/reports/tenant') ||
        cleanPathForCheck.contains('/identity/') ||
        cleanPathForCheck.contains('/schools/onboard')) {
      return false;
    }

    final uri = Uri.tryParse(cleanPathForCheck);
    if (uri == null) return true;
    final pathSegment = uri.path;

    if (pathSegment.endsWith('/schools') || pathSegment.endsWith('/schools/')) {
      return false;
    }

    final schoolsRegExp = RegExp(r'/schools/[0-9a-fA-F\-]+/?$');
    if (schoolsRegExp.hasMatch(pathSegment)) {
      return false;
    }

    return true;
  }

  bool _pathRequiresTenantHeader(String path) {
    String cleanPath = path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        cleanPath = uri.path;
      }
    }

    final cleanPathForCheck = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    if (cleanPathForCheck.contains('/auth/platform-login') ||
        cleanPathForCheck.contains('/health') ||
        cleanPathForCheck.contains('/system/') ||
        cleanPathForCheck.contains('/schools/onboard')) {
      return false;
    }
    return true;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tenantIdBefore = options.headers['X-Tenant-ID'] ?? options.headers['x-tenant-id'];

    final tenantId = _tenantIdGetter != null ? _tenantIdGetter() : _tenantId;
    if (tenantId != null && tenantId.isNotEmpty && _pathRequiresTenantHeader(options.path)) {
      options.headers['X-Tenant-ID'] = tenantId;
    }

    final tenantIdAfter = options.headers['X-Tenant-ID'] ?? options.headers['x-tenant-id'];

    if (options.path.contains('/auth/login') || options.path.contains('auth/login')) {
      // ignore: avoid_print
      print('==================================================');
      // ignore: avoid_print
      print('LOGIN REQUEST');
      // ignore: avoid_print
      print('URL: ${options.uri}');
      // ignore: avoid_print
      print('METHOD: ${options.method}');
      // ignore: avoid_print
      print('X-Tenant-ID (Before Interceptor): $tenantIdBefore');
      // ignore: avoid_print
      print('X-Tenant-ID (After Interceptor): $tenantIdAfter');
      final email = (options.data is Map) ? (options.data as Map)['email'] : null;
      final passwordPresent = (options.data is Map) && (options.data as Map)['password'] != null;
      final passwordLen = (options.data is Map) && passwordPresent ? ((options.data as Map)['password'] as String).length : 0;
      // ignore: avoid_print
      print('EMAIL: $email');
      // ignore: avoid_print
      print('PASSWORD: **REDACTED** (Present: $passwordPresent, Length: $passwordLen)');
      // ignore: avoid_print
      print('==================================================');
    }

    if (_tokenProvider != null) {
      final token = await _tokenProvider.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';

        final cleanPathForCheck = options.path.startsWith('/') ? options.path : '/${options.path}';
        final isPlatformOnboarding = cleanPathForCheck.contains('/schools/onboard') ||
            ((cleanPathForCheck.endsWith('/schools') || cleanPathForCheck.endsWith('/schools/')) &&
                options.method.toUpperCase() == 'POST');

        if (isPlatformOnboarding) {
          options.headers.remove('X-School-ID');
          options.headers.remove('x-school-id');
          options.headers.remove('X-Active-School-ID');
          options.headers.remove('x-active-school-id');
        } else {
          String? schoolId = await _tokenProvider.getSchoolId();
          if (schoolId == null || schoolId.isEmpty) {
            schoolId = options.headers['X-School-ID']?.toString();
          }
          if (schoolId == null || schoolId.isEmpty) {
            schoolId = options.queryParameters['school_id']?.toString() ??
                options.queryParameters['schoolId']?.toString();
          }
          if (schoolId == null || schoolId.isEmpty) {
            final uuidRegExp = RegExp(r'/schools/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})');
            final match = uuidRegExp.firstMatch(options.path);
            if (match != null) {
              schoolId = match.group(1);
            }
          }

          if (schoolId == null || schoolId.isEmpty) {
            if (_pathRequiresSchoolContext(options.path)) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Active school context required.',
                  type: DioExceptionType.cancel,
                ),
              );
              return;
            }
          } else {
            options.headers['X-School-ID'] = schoolId;
          }
        }
      }
    }

    if (options.path.contains('/fees/reports/dashboard')) {
      final safeHeaders = Map<String, dynamic>.from(options.headers)
        ..removeWhere((k, v) => k.toLowerCase().contains('auth') || k.toLowerCase().contains('token'));
      // ignore: avoid_print
      print('requestOptions.headers: $safeHeaders');
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.path.contains('/auth/login') || response.requestOptions.path.contains('auth/login')) {
      // ignore: avoid_print
      print('==================================================');
      // ignore: avoid_print
      print('LOGIN RESPONSE');
      // ignore: avoid_print
      print('STATUS: ${response.statusCode}');
      // ignore: avoid_print
      print('MESSAGE: Login successful.');
      // ignore: avoid_print
      print('==================================================');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.path.contains('/auth/login') || err.requestOptions.path.contains('auth/login')) {
      // ignore: avoid_print
      print('==================================================');
      // ignore: avoid_print
      print('LOGIN RESPONSE');
      // ignore: avoid_print
      print('STATUS: ${err.response?.statusCode}');
      // ignore: avoid_print
      print('MESSAGE: ${err.response?.data}');
      // ignore: avoid_print
      print('==================================================');
    }
    // ignore: avoid_print
    print('[JWT_INTERCEPTOR onError] URI: ${err.requestOptions.uri} | Method: ${err.requestOptions.method} | Type: ${err.type} | Message: ${err.message} | Error: ${err.error} | Status: ${err.response?.statusCode} | Data: ${err.response?.data}');
    super.onError(err, handler);
  }
}
