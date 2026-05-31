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
  bool get isConfigured => _status == ServerConfigStatus.configured || 
                            _status == ServerConfigStatus.valid || 
                            _status == ServerConfigStatus.validating;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_keyServerUrl);
    _status = _serverUrl != null && _serverUrl!.isNotEmpty
        ? ServerConfigStatus.configured
        : ServerConfigStatus.unconfigured;
    notifyListeners();
  }

  Future<bool> setServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Server URL tidak boleh kosong';
      notifyListeners();
      return false;
    }

    String formattedUrl = trimmed;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    
    // Remove trailing slash
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    _serverUrl = formattedUrl;
    _status = ServerConfigStatus.validating;
    _errorMessage = null;
    notifyListeners();

    return true;
  }

  void setStatus(ServerConfigStatus status, {String? errorMessage}) {
    _status = status;
    _errorMessage = errorMessage;
    notifyListeners();
  }

  Future<void> saveServerUrl() async {
    if (_serverUrl == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, _serverUrl!);
    _status = ServerConfigStatus.configured;
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    _serverUrl = null;
    _status = ServerConfigStatus.unconfigured;
    _errorMessage = null;
    notifyListeners();
  }
}
