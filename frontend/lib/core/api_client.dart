import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import './storage.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8080/api';
  late final Dio _dio;
  final AppStorage _storage = AppStorage();
  AppStorage get storage => _storage;

  static String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      try {
        final data = error.response?.data;
        if (data is Map) {
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            return data['message'].toString();
          }
          final errors = data['errors'];
          if (errors is List && errors.isNotEmpty) {
            return errors.join(', ');
          }
        }
      } catch (_) {}
      if (error.response?.statusCode == 400) return 'Requête invalide';
      if (error.response?.statusCode == 401) return 'Session expirée';
      if (error.response?.statusCode == 403) return 'Accès refusé';
      if (error.response?.statusCode == 404) return 'Introuvable';
      if (error.response?.statusCode == 413) return 'Fichier trop volumineux';
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
        } catch (_) {}
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
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

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.delete(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadFile(String path, XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
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
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    )).post('/upload/image',
        data: formData,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ));
    final data = response.data as Map<String, dynamic>;
    return data['data']['url'] as String;
  }
}
