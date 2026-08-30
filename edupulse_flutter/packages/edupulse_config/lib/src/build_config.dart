import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum AppEnvironment {
  dev,
  staging,
  prod,
}

class BuildConfig {
  final AppEnvironment env;
  final String apiBaseUrl;
  final String tenantId;
  final Duration timeout;

  const BuildConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.tenantId,
    this.timeout = const Duration(seconds: 15),
  });

  factory BuildConfig.fromEnvironment({String? resolvedApiBaseUrl}) {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    final AppEnvironment environment;

    switch (envString.toLowerCase()) {
      case 'prod':
      case 'production':
        environment = AppEnvironment.prod;
        break;
      case 'staging':
        environment = AppEnvironment.staging;
        break;
      case 'dev':
      case 'development':
      default:
        environment = AppEnvironment.dev;
        break;
    }

    final rawBaseUrl = resolvedApiBaseUrl ??
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8000/api/v1/',
        );
    final apiBaseUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl : '$rawBaseUrl/';

    const tenantId = String.fromEnvironment(
      'TENANT_ID',
      defaultValue: 'd09b9362-3dc8-422d-a441-160735fcea96',
    );

    return BuildConfig(
      env: environment,
      apiBaseUrl: apiBaseUrl,
      tenantId: tenantId,
    );
  }

  /// Asynchronously resolves the proper API base URL depending on platform & device characteristics.
  static Future<String> resolveApiBaseUrl() async {
    const definedUrl = String.fromEnvironment('API_BASE_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl.endsWith('/') ? definedUrl : '$definedUrl/';
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1/';
    }

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final isEmulator = !androidInfo.isPhysicalDevice;

      if (isEmulator) {
        return 'http://10.0.2.2:8000/api/v1/';
      } else {
        const devLanIp = String.fromEnvironment('DEV_LAN_IP', defaultValue: '192.168.31.132');
        return 'http://$devLanIp:8000/api/v1/';
      }
    }

    return 'http://127.0.0.1:8000/api/v1/';
  }

  void printDiagnostics() {
    String platformStr;
    if (kIsWeb) {
      platformStr = 'Web Browser';
    } else if (Platform.isAndroid) {
      platformStr = apiBaseUrl.contains('10.0.2.2')
          ? 'Android Emulator'
          : 'Android Physical Device';
    } else if (Platform.isIOS) {
      platformStr = 'iOS Device/Simulator';
    } else {
      platformStr = 'Desktop';
    }

    debugPrint('====================================');
    debugPrint('EduPulse Build Configuration');
    debugPrint('Environment : ${env.name.toUpperCase()}');
    debugPrint('Platform    : $platformStr');
    debugPrint('API Base URL: $apiBaseUrl');
    debugPrint('Tenant ID   : $tenantId');
    debugPrint('====================================');
  }

  bool get isDevelopment => env == AppEnvironment.dev;
  bool get isStaging => env == AppEnvironment.staging;
  bool get isProduction => env == AppEnvironment.prod;
}
