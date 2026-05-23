class EnvConfig {
  EnvConfig._();

  /// Override at build time: --dart-define=ENV=ngrok
  static const String env = String.fromEnvironment('ENV', defaultValue: 'local');

  /// Override at build time: --dart-define=API_BASE_URL=https://votre-serveur.com/api
  /// Default targets Android emulator (10.0.2.2 = host machine).
  /// For iOS simulator: http://localhost:8080/api
  /// For real device: http://192.168.x.x:8080/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  /// Override at build time: --dart-define=WS_URL=wss://votre-serveur.com/ws
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://10.0.2.2:8080/ws',
  );

  /// Override at build time: --dart-define=FRONTEND_PUBLIC_URL=https://votre-serveur.com
  static const String frontendPublicUrl = String.fromEnvironment(
    'FRONTEND_PUBLIC_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
