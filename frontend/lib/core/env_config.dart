class EnvConfig {
  EnvConfig._();

  /// Override at build time: --dart-define=ENV=ngrok
  static const String env = String.fromEnvironment('ENV', defaultValue: 'local');

  /// Override at build time: --dart-define=API_BASE_URL=https://my-ngrok.ngrok-free.dev/api
  /// Default `/api` — all API calls go to the same origin as the frontend.
  /// The reverse proxy (nginx) forwards `/api/*` to the Spring Boot backend.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',
  );

  /// Override at build time: --dart-define=WS_URL=wss://my-ngrok.ngrok-free.dev/ws
  /// Default targets Android emulator (10.0.2.2); override for other environments.
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://10.0.2.2:8080/ws',
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
