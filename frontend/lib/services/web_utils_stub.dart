class WebUtils {
  static String get currentUrl => '';
  static String get userAgent => '';
  static void requestGeolocation({
    required void Function(double lat, double lng) onSuccess,
    required void Function() onError,
  }) {
    onError();
  }
}
