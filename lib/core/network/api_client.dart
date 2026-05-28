import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

class ApiClient {
  ApiClient() {
    _cookieJar = CookieJar();

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        // Default content-type untuk request biasa (bukan login)
        // Login menggunakan FormData yang override content-type otomatis
        contentType: Headers.jsonContentType,
      ),
    );

    // Cookie manager — wajib untuk session Frappe
    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Kirim token auth jika ada (untuk API key/token auth)
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = _token;
          }
          // Kirim CSRF token untuk semua POST request ke Frappe
          if (options.method == 'POST' && _csrfToken != null && _csrfToken!.isNotEmpty) {
            options.headers['X-Frappe-CSRF-Token'] = _csrfToken;
          }
          if (AppConfig.enableApiLog) {
            AppLogger.info('api_request',
                context: {'method': options.method, 'path': options.path});
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (AppConfig.enableApiLog) {
            AppLogger.info('api_response',
                context: {'status': response.statusCode, 'path': response.requestOptions.path});
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          if (status == 401) {
            _onUnauthorized?.call();
          }
          if (AppConfig.enableApiLog) {
            AppLogger.error('api_error',
                error: error.message,
                context: {'path': error.requestOptions.path, 'status': status});
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  late final CookieJar _cookieJar;
  String? _token;
  String? _csrfToken;
  VoidCallback? _onUnauthorized;

  void setUnauthorizedHandler(VoidCallback callback) => _onUnauthorized = callback;

  void setAuthToken(String? token) => _token = token;

  void setCsrfToken(String? token) => _csrfToken = token;

  /// Clear semua cookies (dipakai saat logout)
  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.post<T>(path, data: data, queryParameters: queryParameters));

  Future<Response<T>> _execute<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw AppException(
        e.response?.data?['message']?.toString() ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (_) {
      throw AppException('Unexpected error');
    }
  }
}
