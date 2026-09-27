import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum AppEnvironment {
  dev,
  staging,
  prod,
}

class BuildConfig {
  static const String defaultProdApiBaseUrl =
      'https://edupulse-api-295242569787.asia-south1.run.app/api/v1/';
  static const String defaultDevApiBaseUrl = 'http://127.0.0.1:8000/api/v1/';
  static const String defaultDevTenantId = 'd09b9362-3dc8-422d-a441-160735fcea96';

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

  factory BuildConfig.fromEnvironment({
    String? resolvedApiBaseUrl,
    String? resolvedTenantId,
    String? resolvedEnv,
  }) {
    const rawEnv = String.fromEnvironment('ENV');
    final String envString;
    if (resolvedEnv != null && resolvedEnv.isNotEmpty) {
      envString = resolvedEnv.trim().toLowerCase();
    } else if (rawEnv.isNotEmpty) {
      envString = rawEnv.trim().toLowerCase();
    } else {
      envString = kReleaseMode ? 'prod' : 'dev';
    }
    final AppEnvironment environment;

    switch (envString) {
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
        // Backward compatibility fallback for legacy or canonical production URLs
        if (resolvedApiBaseUrl != null &&
            (resolvedApiBaseUrl.contains('api.edupulse.ai') ||
             resolvedApiBaseUrl.contains('edupulse-api-295242569787'))) {
          environment = AppEnvironment.prod;
        } else {
          environment = AppEnvironment.dev;
        }
        break;
    }

    final String rawBaseUrl;
    if (resolvedApiBaseUrl != null && resolvedApiBaseUrl.isNotEmpty) {
      rawBaseUrl = resolvedApiBaseUrl;
    } else {
      const envUrl = String.fromEnvironment('API_BASE_URL');
      if (envUrl.isNotEmpty) {
        rawBaseUrl = envUrl;
      } else {
        rawBaseUrl = environment == AppEnvironment.prod
            ? defaultProdApiBaseUrl
            : defaultDevApiBaseUrl;
      }
    }
    final apiBaseUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl : '$rawBaseUrl/';

    const envTenantId = String.fromEnvironment('TENANT_ID');
    final targetTenantId = (resolvedTenantId ?? envTenantId).trim();
    final String tenantId;

    if (environment == AppEnvironment.prod) {
      if (apiBaseUrl.contains('127.0.0.1') ||
          apiBaseUrl.contains('localhost') ||
          apiBaseUrl.contains('10.0.2.2') ||
          apiBaseUrl.contains('192.168.')) {
        throw StateError(
          'Invalid production API_BASE_URL configuration! '
          'Production environment (ENV=prod) cannot use local or private LAN addresses ($apiBaseUrl). '
          'Please specify the canonical production API URL using --dart-define=API_BASE_URL=...',
        );
      }
      // In production, TENANT_ID is optional. If supplied (and not the dev default), preserve it.
      // If absent or matching the dev default, tenantId is set to an empty string.
      if (targetTenantId.isNotEmpty &&
          targetTenantId != defaultDevTenantId) {
        tenantId = targetTenantId;
      } else {
        tenantId = '';
      }
    } else {
      tenantId = targetTenantId.isNotEmpty
          ? targetTenantId
          : defaultDevTenantId;
    }

    return BuildConfig(
      env: environment,
      apiBaseUrl: apiBaseUrl,
      tenantId: tenantId,
    );
  }

  /// Asynchronously resolves the proper API base URL depending on platform & device characteristics.
  static Future<String> resolveApiBaseUrl() async {
    const rawEnv = String.fromEnvironment('ENV');
    final String envString;
    if (rawEnv.isNotEmpty) {
      envString = rawEnv.trim().toLowerCase();
    } else {
      envString = kReleaseMode ? 'prod' : 'dev';
    }
    final isProd = envString == 'prod' || envString == 'production';

    const definedUrl = String.fromEnvironment('API_BASE_URL');
    if (definedUrl.isNotEmpty) {
      final normalized = definedUrl.endsWith('/') ? definedUrl : '$definedUrl/';
      if (isProd &&
          (normalized.contains('127.0.0.1') ||
           normalized.contains('localhost') ||
           normalized.contains('10.0.2.2') ||
           normalized.contains('192.168.'))) {
        throw StateError(
          'Invalid production API_BASE_URL configuration! '
          'Production environment (ENV=prod) cannot use local or private LAN addresses ($normalized). '
          'Please specify the canonical production API URL using --dart-define=API_BASE_URL=...',
        );
      }
      return normalized;
    }

    if (isProd) {
      return defaultProdApiBaseUrl;
    }

    if (kIsWeb) {
      return defaultDevApiBaseUrl;
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

    return defaultDevApiBaseUrl;
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
