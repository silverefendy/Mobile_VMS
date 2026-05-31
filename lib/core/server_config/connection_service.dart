import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

/// Result of a connection test with detailed diagnostics
class ConnectionTestResult {
  final bool success;
  final String? message;
  final ConnectionStage? failedAt;
  final String? errorDetails;

  const ConnectionTestResult({
    required this.success,
    this.message,
    this.failedAt,
    this.errorDetails,
  });

  factory ConnectionTestResult.success([String? message]) => ConnectionTestResult(
        success: true,
        message: message ?? 'Connection successful',
      );

  factory ConnectionTestResult.failure({
    required ConnectionStage failedAt,
    required String message,
    String? errorDetails,
  }) =>
      ConnectionTestResult(
        success: false,
        failedAt: failedAt,
        message: message,
        errorDetails: errorDetails,
      );
}

/// Stages in the connection test flow
enum ConnectionStage {
  dnsResolution('DNS Resolution'),
  tcpConnection('TCP Connection'),
  sslHandshake('SSL Handshake'),
  healthCheck('Health Check'),
  visitorApiCheck('Visitor API Check');

  final String label;
  const ConnectionStage(this.label);
}

class ConnectionService {
  /// Test connection with detailed diagnostics (returns boolean for backward compatibility)
  Future<bool> testConnection(String baseUrl) async {
    final result = await testConnectionDetailed(baseUrl);
    return result.success;
  }

  /// Test connection with detailed diagnostics for better error reporting
  Future<ConnectionTestResult> testConnectionDetailed(String baseUrl) async {
    AppLogger.info('connection_test_started', context: {'url': baseUrl});

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // STEP 1: Health check (/api/method/ping doesn't require auth)
    try {
      AppLogger.info('connection_stage', context: {
        'stage': ConnectionStage.healthCheck.label,
        'action': 'Testing ping endpoint',
      });

      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/ping',
      );

      if (response.statusCode == 200) {
        AppLogger.info('connection_success', context: {
          'stage': ConnectionStage.healthCheck.label,
          'statusCode': response.statusCode,
        });

        // STEP 2: Try custom health check endpoint (requires Visitor Management)
        try {
          final healthResponse = await dio.get<Map<String, dynamic>>(
            '/api/method/visitor_management.mobile.health_check',
          );
          if (healthResponse.statusCode == 200 && healthResponse.data != null) {
            final data = healthResponse.data as Map<String, dynamic>;
            if (data['status'] == 'ok') {
              return ConnectionTestResult.success(
                  'Visitor Management API connected');
            }
          }
        } catch (_) {
          // Health check failed but server is reachable - this is OK
          AppLogger.warn('connection_visitor_api_not_available', context: {
            'note': 'Visitor Management API not available but server is reachable',
          });
        }

        return ConnectionTestResult.success('Server reachable');
      }
    } on DioException catch (e) {
      final errorInfo = _parseDioError(e, ConnectionStage.healthCheck);
      AppLogger.error('connection_failed', error: e.message, context: {
        'stage': errorInfo.$2.label,
        'errorType': e.type.toString(),
        'url': baseUrl,
      });
      return ConnectionTestResult.failure(
        failedAt: errorInfo.$2,
        message: errorInfo.$1,
        errorDetails: _formatDioError(e),
      );
    }

    return ConnectionTestResult.failure(
      failedAt: ConnectionStage.healthCheck,
      message: 'Unknown error during connection test',
    );
  }

  /// Get detailed server information
  Future<Map<String, dynamic>?> getServerInfo(String baseUrl) async {
    AppLogger.info('get_server_info', context: {'url': baseUrl});

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
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      AppLogger.error('get_server_info_failed', error: e.toString(), context: {
        'url': baseUrl,
      });
    }

    return null;
  }

  /// Parse DioException to user-friendly message
  (String, ConnectionStage) _parseDioError(DioException e, ConnectionStage fallback) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return (
          'Connection timeout. Server tidak merespons dalam 10 detik.',
          ConnectionStage.tcpConnection
        );
      case DioExceptionType.sendTimeout:
        return ('Send timeout. Gagal mengirim data ke server.', fallback);
      case DioExceptionType.receiveTimeout:
        return (
          'Receive timeout. Server terlalu lambat merespons.',
          fallback
        );
      case DioExceptionType.badCertificate:
        return (
          'SSL Certificate error. Pastikan sertifikat valid atau hubungi administrator.',
          ConnectionStage.sslHandshake
        );
      case DioExceptionType.connectionError:
        // Check for common connection error patterns
        final errorMsg = e.message?.toLowerCase() ?? '';
        if (errorMsg.contains('certificate') || errorMsg.contains('ssl')) {
          return (
            'SSL Certificate verification failed. Gunakan HTTP untuk development atau perbaiki sertifikat.',
            ConnectionStage.sslHandshake
          );
        }
        if (errorMsg.contains('connection refused') || errorMsg.contains('socket')) {
          return (
            'Koneksi ditolak. Pastikan server aktif dan port benar.',
            ConnectionStage.tcpConnection
          );
        }
        return (
          'Tidak dapat terhubung ke server. Pastikan URL benar dan server aktif.',
          ConnectionStage.tcpConnection
        );
      case DioExceptionType.unknown:
        final message = e.message ?? '';
        if (message.contains('SocketException') || message.contains('Connection refused')) {
          return (
            'Koneksi ditolak. Pastikan server aktif dan port benar.',
            ConnectionStage.tcpConnection
          );
        }
        if (message.contains('HandshakeException')) {
          return (
            'SSL handshake gagal. Pastikan server menggunakan HTTPS dengan sertifikat valid.',
            ConnectionStage.sslHandshake
          );
        }
        return (
          'Error koneksi: ${message.substring(0, message.length.clamp(0, 100))}',
          fallback
        );
      case DioExceptionType.cancel:
        return ('Request dibatalkan.', fallback);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return (
            'Authentication error. Endpoint memerlukan login.',
            fallback
          );
        }
        if (statusCode == 404) {
          return (
            'Endpoint tidak ditemukan. Visitor Management API mungkin belum terinstall.',
            ConnectionStage.visitorApiCheck
          );
        }
        return (
          'Server merespons dengan error: $statusCode',
          fallback
        );
      default:
        return (
          'Error: ${e.message ?? 'Unknown connection error'}',
          fallback
        );
    }
  }

  /// Format DioException for detailed logging
  String _formatDioError(DioException e) {
    final buffer = StringBuffer();
    buffer.writeln('Type: ${e.type}');
    if (e.response?.statusCode != null) {
      buffer.writeln('Status: ${e.response?.statusCode}');
    }
    if (e.message != null) {
      buffer.writeln('Message: ${e.message}');
    }
    if (e.requestOptions.uri.toString().isNotEmpty) {
      buffer.writeln('URL: ${e.requestOptions.uri}');
    }
    return buffer.toString().trim();
  }
}
