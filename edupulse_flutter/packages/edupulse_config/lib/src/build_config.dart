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

  factory BuildConfig.fromEnvironment() {
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

    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000/api/v1',
    );

    const tenantId = String.fromEnvironment(
      'TENANT_ID',
      defaultValue: '00000000-0000-0000-0000-000000000000',
    );

    return BuildConfig(
      env: environment,
      apiBaseUrl: apiBaseUrl,
      tenantId: tenantId,
    );
  }

  bool get isDevelopment => env == AppEnvironment.dev;
  bool get isStaging => env == AppEnvironment.staging;
  bool get isProduction => env == AppEnvironment.prod;
}
