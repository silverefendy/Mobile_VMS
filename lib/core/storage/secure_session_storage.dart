import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_session.dart';

class SecureSessionStorage {
  static const _key = 'mobile_vms_auth_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
