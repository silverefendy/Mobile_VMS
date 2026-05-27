enum AppEnvironment { dev, staging, production }

class AppConfig {
  AppConfig._();

  static const String _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  static const bool enableApiLog = bool.fromEnvironment('ENABLE_API_LOG', defaultValue: true);

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
