import 'dart:async';
import 'package:dio/dio.dart';

class ConnectionService {
  Future<bool> testConnection(String baseUrl) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    try {
      // Try custom health check endpoint first
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile.health_check',
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['status'] == 'ok';
      }
    } on DioException {
      // Fallback: try generic ping endpoint
      try {
        final pingResponse = await dio.get<Map<String, dynamic>>(
          '/api/method/ping',
        );
        return pingResponse.statusCode == 200;
      } on DioException {
        // Fallback: frappe.auth.get_logged_user as health check
        try {
          final fallback = await dio.get<Map<String, dynamic>>(
            '/api/method/frappe.auth.get_logged_user',
          );
          return fallback.statusCode == 200;
        } on DioException {
          return false;
        } catch (_) {
          return false;
        }
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getServerInfo(String baseUrl) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile.health_check',
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
    } catch (_) {}
    
    return null;
  }
}
