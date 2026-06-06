import 'dart:convert';
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

/// Resolves a potentially relative image URL to an absolute URL.
/// Relative paths (e.g. `/uploads/images/uuid.jpg`) are prepended with
/// the backend base (scheme + host + port from [EnvConfig.apiBaseUrl]).
/// Absolute URLs are returned as-is. Null/empty inputs return null.
String? resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final t = url.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  try {
    final apiUri = Uri.parse(EnvConfig.apiBaseUrl);
    final base = Uri(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.hasPort ? apiUri.port : null);
    return base.resolve(t).toString();
  } catch (_) {
    return t;
  }
}

/// Parses the `images` field from a backend product response.
/// Accepts a JSON string array (`["url1","url2"]`), a single URL string,
/// or a Dart List. Returns a non-null list of image URLs.
List<String> parseImageUrls(dynamic images) {
  if (images == null) return [];
  if (images is List) {
    return images.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (images is String) {
    final t = images.trim();
    if (t.isEmpty || t == '[]') return [];
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
    return [t];
  }
  return [];
}

/// Returns the first image URL from [images] or null.
String? firstImageUrl(dynamic images) {
  final list = parseImageUrls(images);
  return list.isNotEmpty ? list.first : null;
}
