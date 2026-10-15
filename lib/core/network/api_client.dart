import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final path = error.requestOptions.path;
        final isCredentialCheck =
            path.endsWith('/auth/login') || path.endsWith('/auth/change-password');
        if (error.response?.statusCode == 401 && !isCredentialCheck) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  VoidCallback? onUnauthorized;

  Map<String, dynamic> _map(Response r) => r.data is Map
      ? Map<String, dynamic>.from(r.data as Map)
      : <String, dynamic>{};

  Future<Map<String, dynamic>> get(String path,
          {Map<String, dynamic>? params}) async =>
      _map(await dio.get(path, queryParameters: params));

  Future<Map<String, dynamic>> post(String path, [Object? body]) async =>
      _map(await dio.post(path, data: body));

  Future<Map<String, dynamic>> put(String path, [Object? body]) async =>
      _map(await dio.put(path, data: body));

  Future<Map<String, dynamic>> delete(String path,
          {Map<String, dynamic>? params}) async =>
      _map(await dio.delete(path, queryParameters: params));
}

String apiErrorMessage(Object error,
    [String fallback = 'Something went wrong. Please try again.']) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map &&
        data['message'] is String &&
        (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach the server at ${error.requestOptions.uri.origin}. '
          'Make sure the API is running. In a browser, also check the app is on '
          'port 5173 (CORS).';
    }
  }
  return fallback;
}

Map<String, dynamic>? apiErrorData(Object error) {
  if (error is DioException && error.response?.data is Map) {
    return Map<String, dynamic>.from(error.response!.data as Map);
  }
  return null;
}
