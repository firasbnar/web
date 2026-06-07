import '../core/env_config.dart';
import '../core/url_utils.dart';

String? resolveImageUrl(dynamic image) {
  if (image == null) return null;
  final url = image.toString().trim();
  if (url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return normalizeRemoteUrl(url) ?? url;
  }
  final base = EnvConfig.frontendPublicUrl.endsWith('/')
      ? EnvConfig.frontendPublicUrl
      : '${EnvConfig.frontendPublicUrl}/';
  final path = url.startsWith('/') ? url.substring(1) : url;
  return '$base$path';
}

List<String> parseImageUrls(dynamic images) {
  if (images == null) return [];
  if (images is List) {
    return images.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (images is String) {
    final s = images.trim();
    if (s.isEmpty) return [];
    if (s.startsWith('[')) {
      try {
        return s.substring(1, s.length - 1)
            .split(',')
            .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return [images.toString()];
}

String? firstImageUrl(dynamic images) {
  final list = parseImageUrls(images);
  if (list.isEmpty) return null;
  return list.first;
}
