import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_storage.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/errors/app_exception.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient apiClient, required SecureSessionStorage storage})
      : _apiClient = apiClient,
        _storage = storage;

  final ApiClient _apiClient;
  final SecureSessionStorage _storage;

  @override
  Future<AuthSession> login({required String username, required String password}) async {
    // Frappe login HARUS pakai form-encoded, bukan JSON
    final formData = FormData.fromMap({
      'usr': username,
      'pwd': password,
    });

    Response<Map<String, dynamic>> loginResp;
    try {
      loginResp = await _apiClient.post<Map<String, dynamic>>(
        '/api/method/login',
        data: formData,
      );
    } catch (e) {
      // Frappe mengembalikan 401 saat password salah
      throw AppException('Username atau password salah. Pastikan akun aktif di ERPNext.');
    }

    // Verifikasi login berhasil — Frappe mengembalikan home_page saat sukses
    final loginData = loginResp.data;
    if (loginData == null || loginData['home_page'] == null) {
      throw AppException('Login gagal: respons server tidak valid.');
    }

    // Ambil user yang sedang login
    final userResp = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/frappe.auth.get_logged_user',
    );
    final userId = (userResp.data?['message'] ?? '').toString().trim();
    if (userId.isEmpty || userId == 'Guest') {
      throw AppException('Login gagal: sesi tidak valid. Coba lagi.');
    }

    // Ambil CSRF token — diperlukan untuk semua POST request berikutnya
    String csrfToken = '';
    try {
      final csrfResp = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.visitor_management.api.get_csrf_token',
      );
      csrfToken = csrfResp.data?['message']?.toString() ?? '';
    } catch (_) {
      // Fallback: coba ambil dari endpoint Frappe bawaan
      try {
        final csrfResp = await _apiClient.get<Map<String, dynamic>>(
          '/api/method/frappe.utils.csrf_token.get_token',
        );
        csrfToken = csrfResp.data?['message']?.toString() ?? '';
      } catch (_) {}
    }

    // Set CSRF token ke ApiClient agar dipakai di semua request berikutnya
    _apiClient.setCsrfToken(csrfToken);

    // Ambil nama lengkap user
    String fullName = userId;
    try {
      final profileResp = await _apiClient.get<Map<String, dynamic>>(
        '/api/resource/User/$userId',
      );
      final userData = profileResp.data?['data'] as Map<String, dynamic>?;
      fullName = userData?['full_name']?.toString() ?? userId;
    } catch (_) {}

    // Ambil roles user dari Frappe
    List<String> roles = ['Employee'];
    try {
      final rolesResp = await _apiClient.get<Map<String, dynamic>>(
        '/api/resource/User/$userId',
      );
      final userData = rolesResp.data?['data'] as Map<String, dynamic>?;
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
      authHeader: csrfToken, // simpan CSRF token untuk di-restore saat restart app
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
    // Hapus cookie sesi Frappe dan state auth lokal agar app tidak pernah
    // tersangkut dalam kondisi dashboard authenticated palsu.
    await _apiClient.clearCookies();
    await _storage.clear();
  }

  @override
  Future<AuthSession?> restore() => _storage.readSession();
}
