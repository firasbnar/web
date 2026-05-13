import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/api_client.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  User? _user;
  bool _loading = false;
  String? _error;
  bool _isAuthenticated = false;
  String? _role;

  User? get user => _user;
  String? get role => _role;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await _api.post('/auth/login', data: {'email': email, 'password': password});
      final data = res['data'];
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      await _api.storage.saveUserRole(_role!);
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) { _loading = false; notifyListeners(); return false; }
      final auth = await account.authentication;
      if (auth.idToken == null) throw Exception('Token Google manquant');
      final res = await _api.post('/auth/google-login', data: {'idToken': auth.idToken});
      final data = res['data'];
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      await _api.storage.saveUserRole(_role!);
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String password, String? phone, String? language) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await _api.post('/auth/register', data: {
        'fullName': fullName, 'email': email, 'password': password,
        'phone': phone, 'language': language ?? 'fr',
      });
      final data = res['data'];
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      await _api.storage.saveUserRole(_role!);
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.storage.clearTokens();
    await _api.storage.saveUserRole('');
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final token = await _api.storage.getAccessToken();
    _isAuthenticated = token != null && token.isNotEmpty;
    if (_isAuthenticated) {
      final uid = await _api.storage.getUserId();
      if (uid != null) {
        _user = User(id: uid, fullName: '', email: '');
      }
      _role = await _api.storage.getUserRole();
    }
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return data['message'] as String;
      }
      if (e.response?.statusCode == 401) return 'Email ou mot de passe incorrect';
    }
    return 'Une erreur est survenue';
  }
}
