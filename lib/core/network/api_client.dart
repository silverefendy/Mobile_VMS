import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../../config/app_config.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

class ApiClient {
  ApiClient({CookieJar? cookieJar}) {
    _cookieJar = cookieJar ?? CookieJar();

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl.isNotEmpty ? AppConfig.baseUrl : 'http://localhost',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        // PENTING: Jangan set contentType di sini secara global.
        // Login Frappe butuh form-encoded, endpoint lain butuh JSON.
        // Content-type diatur per-request.
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final currentBase = AppConfig.baseUrl;
          if (currentBase.isNotEmpty) {
            options.baseUrl = currentBase;
          }

          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = _token;
          }
          // Set CSRF token untuk semua POST — kecuali login (tidak ada token saat itu)
          if (options.method == 'POST' &&
              _csrfToken != null &&
              _csrfToken!.isNotEmpty) {
            options.headers['X-Frappe-CSRF-Token'] = _csrfToken;
          }
          if (AppConfig.enableApiLog) {
            AppLogger.info('api_request',
                context: {'method': options.method, 'path': options.path, 'base': options.baseUrl});
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
          if (status == 401 || status == 403) {
            final logout = _onUnauthorized;
            if (logout != null) {
              unawaited(logout());
            }
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
  Future<void> Function()? _onUnauthorized;

  void setUnauthorizedHandler(Future<void> Function() callback) =>
      _onUnauthorized = callback;

  void setAuthToken(String? token) => _token = token;

  void setCsrfToken(String? token) => _csrfToken = token;

  void updateBaseUrl(String url) {
    AppConfig.baseUrl = url;
    _dio.options.baseUrl = url;
    if (AppConfig.enableApiLog) {
      AppLogger.info('api_base_url_updated', context: {'url': url});
    }
  }

  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _execute(() => _dio.post<T>(path, data: data, queryParameters: queryParameters));

  /// POST khusus login dengan content-type form-encoded
  /// Frappe WAJIB menerima form-encoded untuk /api/method/login
  Future<Response<T>> postForm<T>(String path,
      {required Map<String, String> fields}) =>
      _execute(() => _dio.post<T>(
            path,
            data: fields.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
            ),
          ));

  Future<Response<T>> _execute<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final data = e.response?.data;
      String? serverMessage;
      if (data is Map<String, dynamic>) {
        serverMessage = data['message']?.toString();
      }
      throw AppException(
        serverMessage ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (_) {
      throw AppException('Unexpected error');
    }
  }
}
