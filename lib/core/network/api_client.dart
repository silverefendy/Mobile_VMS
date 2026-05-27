import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../auth/auth_controller.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = _token;
          }
          if (AppConfig.enableApiLog) {
            AppLogger.info('api_request', context: {'method': options.method, 'path': options.path});
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (AppConfig.enableApiLog) {
            AppLogger.info('api_response', context: {'status': response.statusCode, 'path': response.requestOptions.path});
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          if (status == 401) {
            _onUnauthorized?.call();
          }
          if (AppConfig.enableApiLog) {
            AppLogger.error('api_error', error: error.message, context: {'path': error.requestOptions.path, 'status': status});
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _token;
  VoidCallback? _onUnauthorized;

  void setUnauthorizedHandler(VoidCallback callback) => _onUnauthorized = callback;
  void setAuthToken(String? token) => _token = token;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.post<T>(path, data: data, queryParameters: queryParameters));

  Future<Response<T>> _execute<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw AppException(e.response?.data?['message']?.toString() ?? e.message ?? 'Network error', statusCode: e.response?.statusCode);
    } catch (_) {
      throw AppException('Unexpected error');
    }
  }
}
