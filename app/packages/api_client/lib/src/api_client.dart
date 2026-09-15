import 'package:api_client/src/interceptors/auth_interceptor.dart';
import 'package:api_client/src/token_provider.dart';
import 'package:dio/dio.dart';

/// {@template api_client}
/// Dio-based HTTP client with automatic authentication headers and token
/// refresh on `401` responses.
/// {@endtemplate}
class ApiClient {
  /// {@macro api_client}
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(AuthInterceptor(tokenProvider: tokenProvider));
  }

  final Dio _dio;

  /// Performs a `GET` request to [path].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  /// Performs a `POST` request to [path] with optional [data].
  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>(path, data: data);
  }

  /// Performs a `PUT` request to [path] with optional [data].
  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _dio.put<T>(path, data: data);
  }

  /// Performs a `PATCH` request to [path] with optional [data].
  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _dio.patch<T>(path, data: data);
  }

  /// Performs a `DELETE` request to [path].
  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}
