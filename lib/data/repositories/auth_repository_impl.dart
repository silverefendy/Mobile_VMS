import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_storage.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient apiClient, required SecureSessionStorage storage})
      : _apiClient = apiClient,
        _storage = storage;

  final ApiClient _apiClient;
  final SecureSessionStorage _storage;

  @override
  Future<AuthSession> login({required String username, required String password}) async {
    await _apiClient.post<Map<String, dynamic>>('/api/method/login', data: {
      'usr': username,
      'pwd': password,
    });

    final userResp = await _apiClient.get<Map<String, dynamic>>('/api/method/frappe.auth.get_logged_user');
    final user = (userResp.data?['message'] ?? '').toString();

    final session = AuthSession(
      userId: user,
      fullName: user,
      authHeader: '',
      roles: const ['Security'],
    );
    await _storage.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    await _apiClient.post('/api/method/logout');
    await _storage.clear();
  }

  @override
  Future<AuthSession?> restore() => _storage.readSession();
}
