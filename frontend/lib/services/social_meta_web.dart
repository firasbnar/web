import 'dart:html' as html;

class SocialMeta {
  static void setStoreMeta({
    String? title,
    String? description,
    String? image,
    String? url,
  }) {
    final doc = html.document;
    if (title != null) doc.title = title;
    _setMeta('og:title', title ?? 'MakeWebsite');
    _setMeta('description', description ?? 'Votre boutique en ligne');
    _setMeta('og:description', description ?? 'Votre boutique en ligne');
    _setMeta('og:image', image ?? '');
    _setMeta('og:url', url ?? '');
    _setMeta('og:type', 'website');
  }

  static void _setMeta(String name, String content) {
    final selector = name.startsWith('og:')
        ? 'meta[property="$name"]'
        : 'meta[name="$name"]';
    var meta = html.document.querySelector(selector) as html.MetaElement?;
    if (meta == null) {
      meta = html.document.createElement('meta') as html.MetaElement;
      if (name.startsWith('og:')) {
        meta.setAttribute('property', name);
      } else {
        meta.setAttribute('name', name);
      }
      html.document.head!.append(meta);
    }
    meta.content = content;
  }
}
