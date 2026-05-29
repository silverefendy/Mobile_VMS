import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String username, required String password});
  Future<AuthSession?> restore();
  Future<void> logout();
  Future<void> clearLocalAuthState();
}
