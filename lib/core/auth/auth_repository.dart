import '../../domain/repositories/auth_repository.dart';
export '../../domain/repositories/auth_repository.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_storage.dart';
import '../../domain/models/auth_session.dart';
import '../../core/errors/app_exception.dart';
import 'package:flutter/foundation.dart';

/// Concrete implementation of AuthRepository, also acts as ChangeNotifier
/// so it can be used with ChangeNotifierProvider.
class AuthRepositoryImpl extends ChangeNotifier implements AuthRepository {
  AuthRepositoryImpl({required ApiClient apiClient, required SecureSessionStorage storage})
      : _apiClient = apiClient,
        _storage = storage;

  final ApiClient _apiClient;
  final SecureSessionStorage _storage;

  @override
  Future<AuthSession> login({required String username, required String password}) async {
    late final dynamic loginData;
    try {
      final loginResp = await _apiClient.postForm<Map<String, dynamic>>(
        '/api/method/login',
        fields: {'usr': username, 'pwd': password},
      );
      loginData = loginResp.data;
    } catch (e) {
      throw AppException(
        'Username atau password salah. Pastikan akun aktif di ERPNext.',
      );
    }

    if (loginData == null || loginData['home_page'] == null) {
      throw AppException('Login gagal: respons server tidak valid.');
    }

    final userResp = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/frappe.auth.get_logged_user',
    );
    final userId = (userResp.data?['message'] ?? '').toString().trim();
    if (userId.isEmpty || userId == 'Guest') {
      throw AppException('Login gagal: sesi tidak valid. Coba lagi.');
    }

    String csrfToken = '';
    try {
      final csrfResp = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.visitor_management.api.get_csrf_token',
      );
      csrfToken = csrfResp.data?['message']?.toString() ?? '';
    } catch (_) {
      try {
        final csrfResp = await _apiClient.get<Map<String, dynamic>>(
          '/api/method/frappe.utils.csrf_token.get_token',
        );
        csrfToken = csrfResp.data?['message']?.toString() ?? '';
      } catch (_) {}
    }
    _apiClient.setCsrfToken(csrfToken);

    String fullName = userId;
    List<String> roles = ['Employee'];
    try {
      final profileResp = await _apiClient.get<Map<String, dynamic>>(
        '/api/resource/User/$userId',
      );
      final userData = profileResp.data?['data'] as Map<String, dynamic>?;
      fullName = userData?['full_name']?.toString() ?? userId;
      final rolesList = userData?['roles'] as List<dynamic>?;
      if (rolesList != null && rolesList.isNotEmpty) {
        roles = rolesList
            .map((r) => (r as Map<String, dynamic>)['role']?.toString() ?? '')
            .where((r) => r.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    final session = AuthSession(
      userId: userId,
      fullName: fullName,
      authHeader: csrfToken,
      roles: roles,
    );
    await _storage.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/method/logout');
    } catch (_) {}
    await clearLocalAuthState();
  }

  @override
  Future<void> clearLocalAuthState() async {
    await _apiClient.clearCookies();
    await _storage.clear();
  }

  @override
  Future<AuthSession?> restore() => _storage.readSession();
}
