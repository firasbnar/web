import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebUtils {
  static String get currentUrl => html.window.location.href;
  static String get userAgent => html.window.navigator.userAgent;

  static void requestGeolocation({
    required void Function(double lat, double lng) onSuccess,
    required void Function() onError,
  }) {
    js_util.callMethod(
      html.window.navigator.geolocation,
      'getCurrentPosition',
      [
        (position) {
          final coords = js_util.getProperty(position, 'coords');
          final lat = (js_util.getProperty(coords, 'latitude') as num).toDouble();
          final lng = (js_util.getProperty(coords, 'longitude') as num).toDouble();
          onSuccess(lat, lng);
        },
        (_) => onError(),
        {'enableHighAccuracy': false, 'timeout': 10000},
      ],
    );
  }
}
