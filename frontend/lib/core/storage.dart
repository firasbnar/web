import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userKey = 'user_data';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userKey);
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> saveUserData(String userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userData);
  }

  Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static const _activeBoutiqueKey = 'active_boutique_id';
  static const _userRoleKey = 'user_role';
  static const _subscriptionActiveKey = 'subscription_active';

  static Future<void> saveActiveBoutiqueId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeBoutiqueKey, id);
  }

  static Future<String?> getActiveBoutiqueId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeBoutiqueKey);
  }

  static Future<void> clearActiveBoutiqueId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeBoutiqueKey);
  }

  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<void> saveSubscriptionActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionActiveKey, active);
  }

  static Future<bool> getSubscriptionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionActiveKey) ?? false;
  }

  static Future<void> clearSubscriptionActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscriptionActiveKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userKey);
    await prefs.remove(_activeBoutiqueKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_subscriptionActiveKey);
  }
}
