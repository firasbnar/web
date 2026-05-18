import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import './storage.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8080/api';
  late final Dio _dio;
  final AppStorage _storage = AppStorage();
  AppStorage get storage => _storage;

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
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              return firstError.first.toString();
            }
            return firstError.toString();
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
      if (error.response?.statusCode == 400) return 'Requête invalide';
      if (error.response?.statusCode == 401) return 'Session expirée';
      if (error.response?.statusCode == 403) return 'Accès refusé';
      if (error.response?.statusCode == 404) return 'Introuvable';
      if (error.response?.statusCode == 413) return 'Fichier trop volumineux';
      if (error.response?.statusCode == 422) return 'Données invalides';
      if (error.response?.statusCode == 500) return 'Erreur serveur';
      return 'Erreur de communication';
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
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
          print('  Status: ${error.response?.statusCode}');
          // ignore: avoid_print
          print('  Method: ${error.requestOptions.method}');
          if (error.requestOptions.headers.isNotEmpty) {
            // ignore: avoid_print
            print('  Headers: ${_safeHeaders(error.requestOptions.headers)}');
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
          final refreshToken = await _storage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final response = await Dio(BaseOptions(baseUrl: baseUrl))
                  .post('/auth/refresh', data: {'refreshToken': refreshToken});
              final newAccess = response.data['data']['accessToken'];
              final newRefresh = response.data['data']['refreshToken'];
              await _storage.saveTokens(newAccess, newRefresh);
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccess';
              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (_) {
              await _storage.clearTokens();
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

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
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    _guardPath(path);
    _validateRequestData('POST', path, data);
    final response =
        await _dio.post(path, data: data, queryParameters: queryParameters);
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
