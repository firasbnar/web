import '../core/api_client.dart';
import 'session_manager.dart';

class TrafficTracker {
  static String? _lastTrackedRoute;

  static final ApiClient _api = ApiClient();
  static final SessionManager _session = SessionManager();

  static Future<void> trackStoreVisit({
    required String boutiqueId,
    required String slug,
    required String route,
  }) async {
    if (_lastTrackedRoute == route) return;
    _lastTrackedRoute = route;

    await _session.init();

    try {
      await _api.post('/traffic/track', data: {
        'boutiqueId': boutiqueId,
        'boutiqueSlug': slug,
        'page': route,
        'sessionId': _session.sessionId,
        'platform': 'Web',
      });
    } catch (_) {}
  }
}
