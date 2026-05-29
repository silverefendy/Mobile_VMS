import 'package:flutter/foundation.dart';

import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../network/api_client.dart';

enum AuthStatus { booting, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository, required ApiClient apiClient})
      : _authRepository = authRepository,
        _apiClient = apiClient {
    _apiClient.setUnauthorizedHandler(forceLogout);
  }

  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  AuthStatus status = AuthStatus.booting;
  AuthSession? session;
  String? error;

  Future<void> restoreSession({bool showBooting = true}) async {
    if (showBooting) {
      status = AuthStatus.booting;
      notifyListeners();
    }

    final existing = await _authRepository.restore();
    if (existing == null) {
      await forceLogout();
      return;
    }

    session = existing;

    // Restore CSRF token dari session tersimpan
    if (existing.authHeader.isNotEmpty) {
      _apiClient.setCsrfToken(existing.authHeader);
    }

    _apiClient.setAuthToken(null);

    // Validasi session ke server.
    // Jika Android membunuh app dan cookie hilang,
    // user otomatis kembali ke login dengan bersih.
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/frappe.auth.get_logged_user',
      );

      final user = (response.data?['message'] ?? '').toString().trim();

      if (user.isEmpty || user == 'Guest') {
        await forceLogout();
        return;
      }
    } catch (_) {
      await forceLogout();
      return;
    }

    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> restoreSessionOnResume() => restoreSession(showBooting: false);

  Future<bool> login(String username, String password) async {
    error = null;
    notifyListeners();

    try {
      final result = await _authRepository.login(username: username, password: password);

      session = result;
      _apiClient.setAuthToken(null);

      status = AuthStatus.authenticated;
      notifyListeners();

      return true;
    } catch (e) {
      error = e.toString().replaceFirst('AppException: ', '');
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    await forceLogout();
  }

  Future<void> forceLogout() async {
    error = null;
    session = null;
    _apiClient.setAuthToken(null);
    _apiClient.setCsrfToken(null);
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
