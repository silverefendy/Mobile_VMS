import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ServerConfigStatus { unconfigured, configured, validating, valid, invalid }

class ServerConfigService extends ChangeNotifier {
  static const _keyServerUrl = 'server_url';

  String? _serverUrl;
  ServerConfigStatus _status = ServerConfigStatus.unconfigured;
  String? _errorMessage;

  String? get serverUrl => _serverUrl;
  ServerConfigStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// isConfigured = true hanya jika URL sudah tersimpan DAN status valid/configured.
  /// Status 'validating' TIDAK dianggap configured agar router tidak bingung
  /// saat user sedang di tengah proses test koneksi.
  bool get isConfigured =>
      (_status == ServerConfigStatus.configured ||
          _status == ServerConfigStatus.valid) &&
      _serverUrl != null &&
      _serverUrl!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_keyServerUrl);
    _status = _serverUrl != null && _serverUrl!.isNotEmpty
        ? ServerConfigStatus.configured
        : ServerConfigStatus.unconfigured;
    _debugLog('init',
        'serverUrl=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    notifyListeners();
  }

  Future<bool> setServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Server URL tidak boleh kosong';
      _debugLog('setServerUrl', 'EMPTY URL - error=$_errorMessage');
      notifyListeners();
      return false;
    }

    String formattedUrl = trimmed;
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }

    // Hapus trailing slash
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    _serverUrl = formattedUrl;
    // Gunakan 'validating' — BUKAN configured, agar isConfigured tetap false
    // selama user belum benar-benar menekan Save setelah test berhasil
    _status = ServerConfigStatus.validating;
    _errorMessage = null;
    _debugLog('setServerUrl',
        'url=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    notifyListeners();

    return true;
  }

  void setStatus(ServerConfigStatus status, {String? errorMessage}) {
    _status = status;
    _errorMessage = errorMessage;
    _debugLog('setStatus',
        'newStatus=$status, errorMessage=$errorMessage, isConfigured=$isConfigured');
    notifyListeners();
  }

  Future<void> saveServerUrl() async {
    _debugLog('saveServerUrl',
        'BEFORE SAVE - serverUrl=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    if (_serverUrl == null) {
      _debugLog('saveServerUrl', 'NULL serverUrl - returning early');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, _serverUrl!);
    _status = ServerConfigStatus.configured;
    _debugLog('saveServerUrl',
        'AFTER SAVE - serverUrl=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    _serverUrl = null;
    _status = ServerConfigStatus.unconfigured;
    _errorMessage = null;
    _debugLog('clearConfiguration',
        'Cleared - status=$_status, isConfigured=$isConfigured');
    notifyListeners();
  }

  void _debugLog(String method, String message) {
    debugPrint('[ServerConfigService.$method] $message');
  }
}
