import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse_config/edupulse_config.dart';

void main() {
  group('BuildConfig Environment & Tenant Validation Tests', () {
    test('Development environment defaults', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'dev',
        resolvedApiBaseUrl: 'http://127.0.0.1:8000/api/v1',
      );
      expect(config.env, equals(AppEnvironment.dev));
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.isStaging, isFalse);
      expect(config.apiBaseUrl, equals('http://127.0.0.1:8000/api/v1/'));
      expect(config.tenantId, equals('d09b9362-3dc8-422d-a441-160735fcea96'));
    });

    test('Staging environment configuration', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'staging',
        resolvedApiBaseUrl: 'https://staging-api.edupulse.local/api/v1',
        resolvedTenantId: 'staging-tenant-1234',
      );
      expect(config.env, equals(AppEnvironment.staging));
      expect(config.isStaging, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.tenantId, equals('staging-tenant-1234'));
      expect(config.apiBaseUrl, equals('https://staging-api.edupulse.local/api/v1/'));
    });

    test('Production environment throws StateError when API_BASE_URL is localhost', () {
      expect(
        () => BuildConfig.fromEnvironment(
          resolvedEnv: 'prod',
          resolvedApiBaseUrl: 'http://127.0.0.1:8000/api/v1',
          resolvedTenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
        ),
        throwsStateError,
      );
      expect(
        () => BuildConfig.fromEnvironment(
          resolvedEnv: 'prod',
          resolvedApiBaseUrl: 'http://localhost:8000/api/v1',
        ),
        throwsStateError,
      );
      expect(
        () => BuildConfig.fromEnvironment(
          resolvedEnv: 'prod',
          resolvedApiBaseUrl: 'http://10.0.2.2:8000/api/v1',
        ),
        throwsStateError,
      );
      expect(
        () => BuildConfig.fromEnvironment(
          resolvedEnv: 'prod',
          resolvedApiBaseUrl: 'http://192.168.31.132:8000/api/v1',
        ),
        throwsStateError,
      );
    });

    test('Production environment allows absent TENANT_ID and sets tenantId to empty string', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'prod',
        resolvedApiBaseUrl: 'https://api.edupulse.local/api/v1',
        resolvedTenantId: '',
      );
      expect(config.env, equals(AppEnvironment.prod));
      expect(config.isProduction, isTrue);
      expect(config.tenantId, equals(''));
      expect(config.apiBaseUrl, equals('https://api.edupulse.local/api/v1/'));
    });

    test('Production environment sets tenantId to empty string when dev default TENANT_ID is passed', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'prod',
        resolvedApiBaseUrl: 'https://api.edupulse.local/api/v1',
        resolvedTenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      );
      expect(config.env, equals(AppEnvironment.prod));
      expect(config.isProduction, isTrue);
      expect(config.tenantId, equals(''));
    });

    test('Production environment preserves fallback when valid TENANT_ID is supplied', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'prod',
        resolvedApiBaseUrl: 'https://api.edupulse.local/api/v1',
        resolvedTenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
      );
      expect(config.env, equals(AppEnvironment.prod));
      expect(config.isProduction, isTrue);
      expect(config.tenantId, equals('f004a214-ab3e-443d-a683-588c664a0987'));
      expect(config.apiBaseUrl, equals('https://api.edupulse.local/api/v1/'));
    });

    test('Backward compatibility legacy URL check works when resolvedEnv is omitted', () {
      final configWithoutTenant = BuildConfig.fromEnvironment(
        resolvedApiBaseUrl: 'https://edupulse-api-295242569787.asia-south1.run.app/api/v1',
      );
      expect(configWithoutTenant.isProduction, isTrue);
      expect(configWithoutTenant.tenantId, equals(''));

      final configWithTenant = BuildConfig.fromEnvironment(
        resolvedApiBaseUrl: 'https://edupulse-api-295242569787.asia-south1.run.app/api/v1',
        resolvedTenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
      );
      expect(configWithTenant.isProduction, isTrue);
      expect(configWithTenant.tenantId, equals('f004a214-ab3e-443d-a683-588c664a0987'));
    });

    test('Canonical production API URL automatically sets environment to prod when resolvedEnv is omitted', () {
      final config = BuildConfig.fromEnvironment(
        resolvedApiBaseUrl: 'https://api.edupulse.ai/api/v1',
      );
      expect(config.env, equals(AppEnvironment.prod));
      expect(config.isProduction, isTrue);
      expect(config.apiBaseUrl, equals('https://api.edupulse.ai/api/v1/'));
      expect(config.tenantId, equals(''));
    });

    test('Production environment defaults to canonical Cloud Run production URL when API_BASE_URL is omitted', () {
      final config = BuildConfig.fromEnvironment(
        resolvedEnv: 'prod',
      );
      expect(config.env, equals(AppEnvironment.prod));
      expect(config.isProduction, isTrue);
      expect(config.apiBaseUrl, equals('https://edupulse-api-295242569787.asia-south1.run.app/api/v1/'));
      expect(config.tenantId, equals(''));
    });
  });
}
