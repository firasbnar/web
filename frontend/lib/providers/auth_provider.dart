import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:google_sign_in/google_sign_in.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  User? _user;
  bool _loading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _initialized = false;
  String? _role;
  bool _emailVerificationRequired = false;
  bool _mustChangePassword = false;
  String? _pendingEmail;
  bool _subscriptionActive = false;
  bool _subscriptionChecking = false;
  bool _googleInitialized = false;

  // Callback for clearing boutique provider state on logout
  VoidCallback? onLogout;

  User? get user => _user;
  String? get role => _role;
  bool get loading => _loading;
  bool get isInitialized => _initialized;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get emailVerificationRequired => _emailVerificationRequired;
  bool get mustChangePassword => _mustChangePassword;
  String? get pendingEmail => _pendingEmail;
  bool get subscriptionActive => _subscriptionActive;
  bool get isSubscriptionChecking => _subscriptionChecking;
  bool get isTeamMember {
    final normalized = _role?.toUpperCase();
    return normalized == 'TEAM_MEMBER' ||
        normalized == 'STAFF' ||
        normalized == 'MANAGER' ||
        normalized == 'CAISSIER';
  }
  bool get canCreateBoutique {
    final normalized = _role?.toUpperCase();
    return normalized == 'OWNER' || normalized == 'ADMIN';
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    _emailVerificationRequired = false;
    _mustChangePassword = false;
    notifyListeners();
    try {
      // Clear stale session before logging in
      await AppStorage.clearActiveBoutiqueId();
      final res = await _api.post('/auth/login', data: {'email': email, 'password': password});
      final data = res['data'];
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      _mustChangePassword = data['mustChangePassword'] == true;
      _subscriptionActive = data['subscriptionActive'] == true;
      await AppStorage.saveSubscriptionActive(_subscriptionActive);
      await _api.storage.saveUserRole(_role!);
      await _api.storage.saveUserData(jsonEncode(_user!.toJson()));
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      if (_role == 'SUPER_ADMIN' || isTeamMember) {
        _subscriptionActive = true;
        await AppStorage.saveSubscriptionActive(true);
      } else {
        await hasActiveSubscription();
      }
      developer.log('[AUTH] Login success: role=$_role userId=${_user!.id} subActive=$_subscriptionActive');
      return true;
    } on DioException catch (e) {
      _error = _extractLoginErrorMessage(e);
      return false;
    } catch (e) {
      _error = _extractError(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    _loading = true; _error = null; notifyListeners();
    print('GOOGLE BUTTON CLICKED');
    try {
      print('START ANDROID GOOGLE LOGIN');
      await AppStorage.clearActiveBoutiqueId();
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleInitialized) {
        print('ANDROID GOOGLE INIT');
        await googleSignIn.initialize(
          serverClientId:
              '31472972692-e4b34vte5c446ss2tkott3hnmqphrokk.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }
      print('ANDROID AUTHENTICATE');
      final account = await googleSignIn.authenticate();
      final auth = account.authentication;
      print('ID TOKEN RECEIVED: ${auth.idToken?.substring(0, 20)}...');
      if (auth.idToken == null) throw Exception('Token Google manquant');
      return _exchangeToken(auth.idToken!);
    } on GoogleSignInException catch (e) {
      print('GOOGLE SIGN IN EXCEPTION: code=${e.code} description=${e.description} details=${e.details}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        developer.log('[AUTH] Google login cancelled by user');
        _loading = false; notifyListeners();
        return false;
      }
      _error = 'GoogleSignInException: ${e.description ?? e.code.name}';
      _loading = false; notifyListeners();
      return false;
    } catch (e, stack) {
      print('UNEXPECTED ERROR: $e');
      print(stack);
      _error = e.toString();
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogleWeb({required String idToken}) async {
    if (_loading) return false;
    print('WEB GOOGLE LOGIN');
    return _exchangeToken(idToken);
  }

  Future<bool> _exchangeToken(String idToken) async {
    try {
      print('CALLING BACKEND /api/auth/google');
      final res = await _api.post('/auth/google', data: {'idToken': idToken});
      final data = res['data'];
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      _mustChangePassword = data['mustChangePassword'] == true;
      _subscriptionActive = data['subscriptionActive'] == true;
      await AppStorage.saveSubscriptionActive(_subscriptionActive);
      await _api.storage.saveUserRole(_role!);
      await _api.storage.saveUserData(jsonEncode(_user!.toJson()));
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      if (_role == 'SUPER_ADMIN' || isTeamMember) {
        _subscriptionActive = true;
        await AppStorage.saveSubscriptionActive(true);
      } else {
        await hasActiveSubscription();
      }
      _loading = false; notifyListeners();
      developer.log('[AUTH] Google login success: role=$_role userId=${_user!.id} subActive=$_subscriptionActive');
      return true;
    } catch (e, stack) {
      print('GOOGLE TOKEN EXCHANGE ERROR: $e');
      print(stack);
      _error = e.toString();
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String password, String? phone, String? language) async {
    _loading = true;
    _error = null;
    _emailVerificationRequired = false;
    _pendingEmail = null;
    notifyListeners();
    try {
      await AppStorage.clearActiveBoutiqueId();
      final res = await _api.post('/auth/register', data: {
        'fullName': fullName, 'email': email, 'password': password,
        'phone': phone, 'language': language ?? 'fr',
      });
      final data = res['data'];
      final requiresVerification = data['emailVerificationRequired'] == true;
      if (requiresVerification) {
        _pendingEmail = email;
        _emailVerificationRequired = true;
        developer.log('[AUTH] Register requires email verification: $email');
        return true;
      }
      _user = User.fromJson(data['user']);
      _role = data['user']['role'] ?? 'OWNER';
      await _api.storage.saveUserRole(_role!);
      await _api.storage.saveUserData(jsonEncode(_user!.toJson()));
      _isAuthenticated = true;
      await _api.storage.saveTokens(data['accessToken'], data['refreshToken']);
      await _api.storage.saveUserId(_user!.id);
      developer.log('[AUTH] Register success: role=$_role userId=${_user!.id}');
      return true;
    } on DioException catch (e) {
      _error = _extractRegisterErrorMessage(e);
      return false;
    } catch (e) {
      _error = _extractError(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      await _api.post('/auth/resend-verification', data: {'email': email});
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/auth/profile', data: data);
      _user = User.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      await _api.put('/auth/change-password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  void updateAvatar(String url) {
    if (_user != null) {
      _user = _user!.copyWith(avatarUrl: url);
      _api.storage.saveUserData(jsonEncode(_user!.toJson()));
      notifyListeners();
    }
  }

  void setSubscriptionActive(bool active) {
    _subscriptionActive = active;
    AppStorage.saveSubscriptionActive(active);
    notifyListeners();
  }

  Future<bool> hasActiveSubscription() async {
    if (isTeamMember) {
      _subscriptionActive = true;
      await AppStorage.saveSubscriptionActive(true);
      notifyListeners();
      return true;
    }
    try {
      final res = await _api.get('/subscriptions/mine');
      _subscriptionActive = _isSubscriptionActive(res['data']);
      await AppStorage.saveSubscriptionActive(_subscriptionActive);
      return _subscriptionActive;
    } catch (_) {
      // Preserve current value on network error to avoid false redirect to /plans
      return _subscriptionActive;
    } finally {
      notifyListeners();
    }
  }

  /// Used during [init] — loads cached subscription from storage first,
  /// then attempts a live API check. The cached value is preserved on failure
  /// so that a transient network error does not cause a false redirect to /plans.
  Future<void> _syncSubscription() async {
    _subscriptionActive = await AppStorage.getSubscriptionActive();
    try {
      final res = await _api.get('/subscriptions/mine');
      _subscriptionActive = _isSubscriptionActive(res['data']);
    } catch (e) {
      developer.log('[Startup] subscription fetch error: $e, using cached _subscriptionActive=$_subscriptionActive');
    }
    await AppStorage.saveSubscriptionActive(_subscriptionActive);
  }

  bool _isSubscriptionActive(dynamic raw) {
    if (raw is! Map) return false;
    final status = raw['status']?.toString().toUpperCase();
    if (status != 'ACTIVE') return false;
    final expiresAt = _parseDateTime(raw['expiresAt']);
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is List && value.length >= 3) {
      final parts = value.map((v) => v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0).toList();
      return DateTime(
        parts[0],
        parts[1],
        parts[2],
        parts.length > 3 ? parts[3] : 0,
        parts.length > 4 ? parts[4] : 0,
        parts.length > 5 ? parts[5] : 0,
      );
    }
    return null;
  }

  Future<bool> reloadSessionFromStorage({bool notify = true}) async {
    _api.onSessionExpired = _onSessionExpired;
    final tokenLoaded = await _api.reloadAuthorizationHeaderFromStorage();

    if (!tokenLoaded) {
      _user = null;
      _isAuthenticated = false;
      _role = null;
      _subscriptionActive = false;
      if (notify) {
        notifyListeners();
      }
      return false;
    }

    final uid = await _api.storage.getUserId();
    final userDataStr = await _api.storage.getUserData();

    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final userMap = jsonDecode(userDataStr) as Map<String, dynamic>;
        _user = User.fromJson(userMap);
      } catch (e) {
        developer.log('[AUTH] Failed to restore user data from storage: $e');
        if (uid != null && uid.isNotEmpty) {
          _user = User(id: uid, fullName: '', email: '');
        }
      }
    } else if (uid != null && uid.isNotEmpty) {
      _user = User(id: uid, fullName: '', email: '');
    }

    _role = await _api.storage.getUserRole();
    _isAuthenticated = true;
    _subscriptionActive = await AppStorage.getSubscriptionActive();
    developer.log('[AUTH] reloadSessionFromStorage: restored subActive=$_subscriptionActive role=$_role');

    if (notify) {
      notifyListeners();
    }
    return true;
  }

  Future<bool> deleteAccount() async {
    try {
      await _api.delete('/security/account');
      await logout();
      return true;
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    developer.log('[AUTH] Logout');
    await AppStorage.clearAll();
    _user = null;
    _isAuthenticated = false;
    _role = null;
    _subscriptionActive = false;
    _subscriptionChecking = false;
    await AppStorage.clearSubscriptionActive();
    _emailVerificationRequired = false;
    _pendingEmail = null;
    onLogout?.call();
    notifyListeners();
  }

  /// Called by ApiClient interceptor when token refresh fails.
  void _onSessionExpired() {
    developer.log('[AUTH] Session expired (refresh failed), clearing auth state');
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Initialize auth state from persistent storage.
  /// Called once on app startup (from SplashScreen).
  /// Always completes with _initialized=true in finally block.
  Future<void> init() async {
    developer.log('[AUTH INIT] === START ===');
    _api.onSessionExpired = _onSessionExpired;
    try {
      final tokenLoaded = await reloadSessionFromStorage(notify: false);
      developer.log('[AUTH INIT] Access token found: $tokenLoaded');

      if (tokenLoaded) {
        developer.log('[AUTH INIT] User data restored: id=${_user?.id} email=${_user?.email}');
        if (_role == 'SUPER_ADMIN' || isTeamMember) {
          _subscriptionActive = true;
          _subscriptionChecking = false;
        } else {
          _subscriptionChecking = true;
          notifyListeners();
          await _syncSubscription();
          _subscriptionChecking = false;
        }
        developer.log('[AUTH INIT] State restored: isAuthenticated=true role=$_role userId=${_user?.id} subActive=$_subscriptionActive');
      } else {
        _isAuthenticated = false;
        _subscriptionChecking = false;
        developer.log('[AUTH INIT] No valid token, user not authenticated');
      }
    } catch (e) {
      developer.log('[AUTH INIT] Error during init: $e');
      _isAuthenticated = false;
      _user = null;
      _role = null;
      _subscriptionChecking = false;
    } finally {
      _initialized = true;
      notifyListeners();
      developer.log('[AUTH INIT] === END === initialized=true isAuthenticated=$_isAuthenticated role=$_role');
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
      if (e.response?.statusCode == 401) return 'Email ou mot de passe incorrect';
      if (e.response?.statusCode == 403) return 'Compte non vérifié';
    }
    return 'Une erreur est survenue';
  }

  String _extractLoginErrorMessage(DioException e) {
    if (e.response == null) return 'Serveur inaccessible';
    final message = ApiClient.extractErrorMessage(e);
    if (message.trim().isNotEmpty &&
        message != 'Erreur de communication' &&
        !message.toLowerCase().contains('session')) {
      return message;
    }
    return 'Email ou mot de passe incorrect';
  }

  String _extractRegisterErrorMessage(DioException e) {
    if (e.response == null) return 'Serveur inaccessible';
    final message = ApiClient.extractErrorMessage(e);
    if (message.trim().isNotEmpty && message != 'Erreur de communication') {
      return message;
    }
    return 'Impossible de créer le compte';
  }
}
