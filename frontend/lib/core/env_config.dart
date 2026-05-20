class EnvConfig {
  EnvConfig._();

  /// Override at build time: --dart-define=ENV=ngrok
  static const String env = String.fromEnvironment('ENV', defaultValue: 'local');

  /// Override at build time: --dart-define=API_BASE_URL=https://my-ngrok.ngrok-free.dev/api
  /// Default is localhost:8080/api — stable for local development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:'http://localhost:8080/api',
  );

  /// Override at build time: --dart-define=WS_URL=wss://my-ngrok.ngrok-free.dev/ws
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://localhost:8080/ws',
  );

  /// Override at build time: --dart-define=FRONTEND_PUBLIC_URL=https://my-ngrok.ngrok-free.dev
  static const String frontendPublicUrl = String.fromEnvironment(
    'FRONTEND_PUBLIC_URL',
    defaultValue: 'http://localhost:59179',
  );

  static bool get isNgrok => env == 'ngrok';
  static bool get isProduction => env == 'production';
  static bool get isLocal => env == 'local';
}
