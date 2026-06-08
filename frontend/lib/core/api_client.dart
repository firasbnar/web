import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import './storage.dart';
import 'env_config.dart';

class ApiClient {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  late final Dio _dio;
  final AppStorage _storage = AppStorage();
  AppStorage get storage => _storage;
  Future<bool>? _refreshFuture;

  /// Called when token refresh fails and session is expired.
  /// Set by AuthProvider to clear auth state globally.
  void Function()? onSessionExpired;

  /// Extracts a user-friendly error message from a DioException.
  /// For 400 responses, it parses Spring Boot validation errors
  /// from the response body and returns the first meaningful message.
  static String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      try {
        final data = error.response?.data;
        if (data is Map) {
          // Spring Boot standard error body
          final message = data['message'];
          if (message != null && message.toString().isNotEmpty) {
            return message.toString();
          }
          // Field-level validation errors
          final errors = data['errors'];
          if (errors is Map && errors.isNotEmpty) {
            return errors.entries
                .map((entry) {
                  final value = entry.value;
                  if (value is List) return value.join(', ');
                  return value.toString();
                })
                .where((msg) => msg.trim().isNotEmpty)
                .join('\n');
          }
          if (errors is List && errors.isNotEmpty) {
            return errors.join(', ');
          }
          // Spring Boot default error wrapper
          final errorStr = data['error'];
          if (errorStr is String && errorStr.isNotEmpty) {
            return errorStr;
          }
        }
      } catch (_) {}
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.response == null) {
        return tr('errors.server_unreachable');
      }
      if (error.response?.statusCode == 400) return tr('errors.bad_request');
      if (error.response?.statusCode == 401) return tr('errors.session_expired');
      if (error.response?.statusCode == 403) return tr('errors.access_denied');
      if (error.response?.statusCode == 404) return tr('errors.not_found');
      if (error.response?.statusCode == 413) return tr('errors.file_too_large');
      if (error.response?.statusCode == 422) return tr('errors.invalid_data');
      if (error.response?.statusCode == 500) return tr('errors.server_error');
      return tr('errors.communication_error');
    }
    return error.toString();
  }

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          final locale = await _storage.getLocaleCode();
          if (locale != null && locale.isNotEmpty) {
            options.headers['Accept-Language'] = locale;
          } else {
            options.headers.remove('Accept-Language');
          }
          if (options.data != null &&
              options.data is! FormData &&
              options.headers['Content-Type'] == null) {
            options.headers['Content-Type'] = 'application/json';
          }

          // -- Log outgoing request --
          // ignore: avoid_print
          print('[API >>>] ${options.method} ${options.uri}');
          if (options.headers.isNotEmpty) {
            // ignore: avoid_print
            print('  Headers: ${_safeHeaders(options.headers)}');
          }
          if (options.queryParameters.isNotEmpty) {
            // ignore: avoid_print
            print('  Query: ${options.queryParameters}');
          }
          if (options.data != null && options.data is! FormData) {
            // ignore: avoid_print
            print('  Body: ${_truncate('${options.data}', 2000)}');
          } else if (options.data is FormData) {
            final fd = options.data as FormData;
            // ignore: avoid_print
            print('  Body: <FormData>');
            for (final field in fd.fields) {
              // ignore: avoid_print
              print('    field: ${field.key} = ${field.value}');
            }
          }
        } catch (_) {}
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        // -- Log successful response --
        try {
          // ignore: avoid_print
          print('[API <<<] ${response.statusCode} ${response.requestOptions.uri}');
          if (response.data != null) {
            // ignore: avoid_print
            print('  Body: ${_truncate('${response.data}', 2000)}');
          }
        } catch (_) {}
        return handler.next(response);
      },
      onError: (error, handler) async {
        // -- Log error details --
        try {
          // ignore: avoid_print
          print('[API ERROR] ${error.requestOptions.uri}');
          // ignore: avoid_print
          print('  Exception Type: ${error.type}');
          // ignore: avoid_print
          print('  URL: ${error.requestOptions.uri}');
          // ignore: avoid_print
          print('  Status: ${error.response?.statusCode}');
          // ignore: avoid_print
          print('  Method: ${error.requestOptions.method}');
          // Log the actual error message
          if (error.message != null) {
            // ignore: avoid_print
            print('  Error Message: ${error.message}');
          }
          if (error.error != null) {
            // ignore: avoid_print
            print('  Error Object: ${error.error} (${error.error.runtimeType})');
          }
          if (error.requestOptions.headers.isNotEmpty) {
            // ignore: avoid_print
            print('  Request Headers: ${_safeHeaders(error.requestOptions.headers)}');
          }
          if (error.response?.headers.map.isNotEmpty == true) {
            // ignore: avoid_print
            print('  Response Headers: ${error.response?.headers.map}');
          }
          if (error.requestOptions.queryParameters.isNotEmpty) {
            // ignore: avoid_print
            print('  Query: ${error.requestOptions.queryParameters}');
          }
          if (error.requestOptions.data != null &&
              error.requestOptions.data is! FormData) {
            // ignore: avoid_print
            print('  Request Body: ${_truncate('${error.requestOptions.data}', 2000)}');
          }
          if (error.response?.data != null) {
            // ignore: avoid_print
            print('  Response Body: ${_truncate('${error.response?.data}', 2000)}');
          }
          // For 400 errors, print full backend response for debugging
          if (error.response?.statusCode == 400) {
            // ignore: avoid_print
            print('  [400 DEBUG] Full response: ${error.response?.data}');
          }
        } catch (_) {}

        // Token refresh logic for 401 — skip for auth endpoints (login/register can't be fixed by retrying)
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          if (path.startsWith('/auth/') || path.startsWith('/register') || path.startsWith('/login')) {
            return handler.next(error);
          }
          final refreshed = await refreshAccessToken(logPrefix: '[API]');
          if (refreshed) {
            final reloaded = await reloadAuthorizationHeaderFromStorage();
            if (reloaded) {
              final newAccess = await _storage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            }
            final retryResponse = await _dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } else {
            onSessionExpired?.call();
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  Future<bool> reloadAuthorizationHeaderFromStorage() async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      return true;
    }
    _dio.options.headers.remove('Authorization');
    return false;
  }

  Future<void> reloadDefaultHeadersFromStorage() async {
    await reloadAuthorizationHeaderFromStorage();
    final locale = await _storage.getLocaleCode();
    if (locale != null && locale.isNotEmpty) {
      _dio.options.headers['Accept-Language'] = locale;
    } else {
      _dio.options.headers.remove('Accept-Language');
    }
  }

  Future<bool> ensureFreshToken({String logPrefix = '[API]'}) async {
    await reloadDefaultHeadersFromStorage();
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;

    if (!hasRefreshToken) {
      // ignore: avoid_print
      print('$logPrefix refresh token unavailable');
      return false;
    }

    if (hasAccessToken && !_isJwtExpired(accessToken)) {
      // ignore: avoid_print
      print('$logPrefix access token still valid');
      return false;
    }

    return refreshAccessToken(logPrefix: logPrefix);
  }

  Future<bool> refreshAccessToken({String logPrefix = '[API]'}) async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final completer = _refreshAccessTokenInternal(logPrefix: logPrefix);
    _refreshFuture = completer;
    try {
      return await completer;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _refreshAccessTokenInternal({String logPrefix = '[API]'}) async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // ignore: avoid_print
      print('$logPrefix refresh token missing');
      return false;
    }

    try {
      // ignore: avoid_print
      print('$logPrefix refreshing access token');
      final response = await Dio(BaseOptions(baseUrl: baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final newAccess = data['accessToken']?.toString();
      final newRefresh = data['refreshToken']?.toString();
      if (newAccess == null ||
          newAccess.isEmpty ||
          newRefresh == null ||
          newRefresh.isEmpty) {
        throw Exception('Refresh response missing tokens');
      }
      await _storage.saveTokens(newAccess, newRefresh);
      await reloadDefaultHeadersFromStorage();
      // ignore: avoid_print
      print('$logPrefix refresh succeeded');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('$logPrefix refresh failed: $e');
      await _storage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
  }

  // ---------- Helper: safe header logging (hide tokens) ----------

  Map<String, String> _safeHeaders(Map<String, dynamic> headers) {
    final safe = <String, String>{};
    headers.forEach((k, v) {
      if (k.toLowerCase() == 'authorization') {
        final val = v?.toString() ?? '';
        safe[k] = 'Bearer ${val.length > 20 ? '...${val.substring(val.length - 8)}' : val}';
      } else {
        safe[k] = v?.toString() ?? '';
      }
    });
    return safe;
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}... (${s.length - maxLen} more chars)';
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
      final exp = payloadMap['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return DateTime.now().toUtc().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  // ---------- Public convenience methods ----------

  String _guardPath(String path) {
    if (path.isEmpty || path == '/') {
      // ignore: avoid_print
      print('[API ERROR] Refusing to send request to "$path" — would go to "$baseUrl$path"');
      throw Exception('Requête invalide vers "$path"');
    }
    return path;
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    _guardPath(path);
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path,
      {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    _guardPath(path);
    _validateRequestData('POST', path, data);
    final response =
        await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    _guardPath(path);
    _validateRequestData('PUT', path, data);
    final response = await _dio.put(path, data: data, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? queryParameters}) async {
    _guardPath(path);
    final response =
        await _dio.delete(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadFile(String path, XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    // Verify multipart field name matches backend expectation
    // Backend expects: @RequestParam("file") MultipartFile file
    final response = await _dio.post(path, data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final fullUrl = '$baseUrl/auth/forgot-password';
    // ignore: avoid_print
    print('[ForgotPassword] URL=$fullUrl timeout: connect=15s receive=30s');
    return post('/auth/forgot-password',
        data: {'email': email},
        options: Options(receiveTimeout: const Duration(seconds: 30)));
  }

  Future<Map<String, dynamic>> resetPassword(String token, String newPassword, String confirmPassword) async {
    return post('/auth/reset-password', data: {
      'token': token,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  static Future<String> uploadImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final name = image.name;
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: name),
    });
    final token = await AppStorage().getAccessToken();
    final response = await Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    )).post('/upload/image',
        data: formData,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )).timeout(const Duration(seconds: 30));
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] as String? ?? 'Échec de l\'upload');
    }
    return data['data']['url'] as String;
  }

  // ---------- Defensive pre-flight validation ----------

  void _validateRequestData(String method, String path, dynamic data) {
    if (data == null) return;

    // FormData-specific checks
    if (data is FormData) {
      if (data.fields.isNotEmpty) {
        // ignore: avoid_print
        print('[API WARN] $method $path: sending FormData fields: '
            '${data.fields.map((f) => f.key).join(', ')}');
      }
      return;
    }

    // Map-specific checks
    if (data is! Map) return;

    // Check for null/empty required fields BEFORE hitting the network
    final missingFields = <String>[];
    data.forEach((key, value) {
      // boutiqueId, customerId, productId etc. should not be null
      if (key.endsWith('Id') && value == null) {
        missingFields.add(key);
      }
    });

    if (missingFields.isNotEmpty) {
      // ignore: avoid_print
      print(
          '[API WARN] $method $path: null ID fields detected: $missingFields');
    }
  }
}
