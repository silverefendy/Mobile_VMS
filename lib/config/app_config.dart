enum AppEnvironment { dev, staging, production }

class AppConfig {
  AppConfig._();

  static const String _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const bool enableApiLog = bool.fromEnvironment('ENABLE_API_LOG', defaultValue: true);
  static const bool enableSignedQr = bool.fromEnvironment('ENABLE_SIGNED_QR', defaultValue: true);
  static const bool enableOfflineQueue = bool.fromEnvironment('ENABLE_OFFLINE_QUEUE', defaultValue: true);

  // Runtime base URL — set by ServerConfigService at startup
  static String baseUrl = '';

  static AppEnvironment get environment {
    switch (_env) {
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }
}
