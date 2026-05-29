import 'package:flutter/foundation.dart';

import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../errors/app_exception.dart';
import '../network/api_client.dart';

enum AuthStatus { booting, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required ApiClient apiClient,
  })
      : _authRepository = authRepository,
        _apiClient = apiClient {
    _apiClient.setUnauthorizedHandler(forceLogout);
  }

  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  AuthStatus status = AuthStatus.booting;
  AuthSession? session;
  String? error;
  bool restoring = false;

  Future<void> restoreSession({bool showBooting = true}) async {
    if (restoring) return;
    restoring = true;
    error = null;

    if (showBooting) {
      status = AuthStatus.booting;
      notifyListeners();
    }

    final existing = await _authRepository.restore();
    if (existing == null) {
      await forceLogout();
      restoring = false;
      return;
    }

    session = existing;
    _apiClient.setAuthToken(null);
    _apiClient.setCsrfToken(
      existing.authHeader.isNotEmpty ? existing.authHeader : null,
    );

    try {
      final isValid = await _validateErpNextSession();
      if (!isValid) {
        await forceLogout();
        return;
      }

      status = AuthStatus.authenticated;
      notifyListeners();
    } on AppException catch (e) {
      if (_isInvalidSessionStatus(e.statusCode)) {
        await forceLogout();
        return;
      }

      // Temporary network/server failures are not proof that the ERPNext session
      // is invalid. Keep the restored session and persistent cookies so resume
      // does not wipe the dashboard or force a manual logout/login loop.
      error = 'Tidak dapat memvalidasi sesi saat ini. Mencoba memakai sesi tersimpan.';
      status = AuthStatus.authenticated;
      notifyListeners();
    } finally {
      restoring = false;
    }
  }

  Future<void> restoreSessionOnResume() => restoreSession(showBooting: false);

  Future<bool> login(String username, String password) async {
    error = null;
    notifyListeners();

    try {
      final result = await _authRepository.login(
        username: username,
        password: password,
      );

      session = result;
      _apiClient.setAuthToken(null);
      _apiClient.setCsrfToken(
        result.authHeader.isNotEmpty ? result.authHeader : null,
      );

      status = AuthStatus.authenticated;
      notifyListeners();

      return true;
    } on AppException catch (e) {
      error = e.message;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      error = e.toString();
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _clearRuntimeAuthState();
    notifyListeners();
  }

  Future<void> forceLogout() async {
    await _authRepository.clearLocalAuthState();
    _clearRuntimeAuthState();
    notifyListeners();
  }

  Future<bool> _validateErpNextSession() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/frappe.auth.get_logged_user',
    );

    final user = (response.data?['message'] ?? '').toString().trim();
    return user.isNotEmpty && user != 'Guest';
  }

  bool _isInvalidSessionStatus(int? statusCode) =>
      statusCode == 401 || statusCode == 403;

  void _clearRuntimeAuthState() {
    error = null;
    restoring = false;
    session = null;
    _apiClient.setAuthToken(null);
    _apiClient.setCsrfToken(null);
    status = AuthStatus.unauthenticated;
  }
}
