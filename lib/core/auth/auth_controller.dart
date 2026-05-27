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

  Future<void> restoreSession() async {
    status = AuthStatus.booting;
    notifyListeners();
    final existing = await _authRepository.restore();
    if (existing == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    session = existing;
    _apiClient.setAuthToken(existing.authHeader.isEmpty ? null : existing.authHeader);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    error = null;
    notifyListeners();
    try {
      final result = await _authRepository.login(username: username, password: password);
      session = result;
      _apiClient.setAuthToken(result.authHeader.isEmpty ? null : result.authHeader);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
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
    session = null;
    _apiClient.setAuthToken(null);
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
