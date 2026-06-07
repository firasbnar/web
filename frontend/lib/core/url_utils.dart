import 'env_config.dart';

String? normalizeRemoteUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  final ngrokPattern = RegExp(r'https?://[^/]*ngrok-(free\.)?(dev|app)', caseSensitive: false);
  if (!ngrokPattern.hasMatch(url)) return url;

  try {
    final uri = Uri.parse(EnvConfig.apiBaseUrl);
    final localBase = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
    return url.replaceFirst(ngrokPattern, localBase);
  } catch (_) {
    return url;
  }
}
