import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._();
  factory SessionManager() => _instance;
  SessionManager._();

  static const String _sessionIdKey = 'traffic_session_id';
  static const String _sessionStartKey = 'traffic_session_start';
  static const String _firstVisitKey = 'traffic_first_visit';

  String? _sessionId;
  DateTime? _sessionStart;
  DateTime? _firstVisit;

  String? get sessionId => _sessionId;
  DateTime? get sessionStart => _sessionStart;
  DateTime? get firstVisit => _firstVisit;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _firstVisit = _loadDateTime(prefs, _firstVisitKey);
    if (_firstVisit == null) {
      _firstVisit = DateTime.now();
      await _saveDateTime(prefs, _firstVisitKey, _firstVisit!);
    }

    _sessionId = prefs.getString(_sessionIdKey);
    _sessionStart = _loadDateTime(prefs, _sessionStartKey);

    final now = DateTime.now();

    if (_sessionId == null || _isSessionExpired(_sessionStart, now)) {
      await _startNewSession(prefs);
    }
  }

  Future<void> _startNewSession(SharedPreferences prefs) async {
    _sessionId = const Uuid().v4();
    _sessionStart = DateTime.now();
    await prefs.setString(_sessionIdKey, _sessionId!);
    await _saveDateTime(prefs, _sessionStartKey, _sessionStart!);
  }

  bool _isSessionExpired(DateTime? start, DateTime now) {
    if (start == null) return true;
    return now.difference(start).inMinutes > 30;
  }

  Future<void> maybeStartNewSession() async {
    if (_sessionId == null || _isSessionExpired(_sessionStart, DateTime.now())) {
      final prefs = await SharedPreferences.getInstance();
      await _startNewSession(prefs);
    }
  }

  DateTime? _loadDateTime(SharedPreferences prefs, String key) {
    final ms = prefs.getInt(key);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> _saveDateTime(SharedPreferences prefs, String key, DateTime dt) async {
    await prefs.setInt(key, dt.millisecondsSinceEpoch);
  }
}
