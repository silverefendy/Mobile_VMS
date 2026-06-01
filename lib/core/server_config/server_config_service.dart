import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';

enum ServerConfigStatus { unconfigured, configured, validating, valid, invalid }

class ServerConfigService extends ChangeNotifier {
  static const _keyServerUrl = 'server_url';

  String? _serverUrl;
  ServerConfigStatus _status = ServerConfigStatus.unconfigured;
  String? _errorMessage;

  String? get serverUrl => _serverUrl;
  ServerConfigStatus get status => _status;
  String? get errorMessage => _errorMessage;
  
  /// Returns true ONLY if server URL has been tested AND connection test passed
  /// This is stricter than isConfigured - only 'valid' status returns true
  bool get isConfigured => _status == ServerConfigStatus.valid;
  
  /// Explicit getter for login readiness: URL configured + validated + connection test passed
  bool get isReadyForLogin => isConfigured && (_serverUrl?.isNotEmpty ?? false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_keyServerUrl);
    // Only mark as configured if we have a URL, but don't assume it's valid
    // User must still test connection to reach 'valid' status
    _status = _serverUrl != null && _serverUrl!.isNotEmpty
        ? ServerConfigStatus.configured  // Has URL but not yet validated
        : ServerConfigStatus.unconfigured;
    _debugLog('init', 'serverUrl=$_serverUrl, status=$_status, isConfigured=$isConfigured, isReadyForLogin=$isReadyForLogin');
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
    _debugLog('setServerUrl', 'url=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    notifyListeners();

    return true;
  }

  void setStatus(ServerConfigStatus status, {String? errorMessage}) {
    _status = status;
    _errorMessage = errorMessage;
    _debugLog('setStatus', 'newStatus=$status, errorMessage=$errorMessage, isConfigured=$isConfigured, isReadyForLogin=$isReadyForLogin');
    notifyListeners();
  }

  Future<void> saveServerUrl() async {
    _debugLog('saveServerUrl', 'BEFORE SAVE - serverUrl=$_serverUrl, status=$_status, isConfigured=$isConfigured');
    if (_serverUrl == null) {
      _debugLog('saveServerUrl', 'NULL serverUrl - returning early');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, _serverUrl!);
    // Only mark as configured (ready for login) if status is valid
    if (_status == ServerConfigStatus.valid) {
      _debugLog('saveServerUrl', 'Saving valid config - status=$_status');
    } else {
      _debugLog('saveServerUrl', 'WARNING: Saving with non-valid status=$_status');
    }
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    _serverUrl = null;
    _status = ServerConfigStatus.unconfigured;
    _errorMessage = null;
    _debugLog('clearConfiguration', 'Cleared - status=$_status, isConfigured=$isConfigured');
    notifyListeners();
  }
  
  /// Clear configuration if connection test fails repeatedly
  /// Useful for forcing user back to setup screen
  Future<void> markAsInvalidAndClear({String? reason}) async {
    _status = ServerConfigStatus.invalid;
    _errorMessage = reason ?? 'Connection validation failed';
    notifyListeners();
  }

  void _debugLog(String method, String message) {
    debugPrint('[ServerConfigService.$method] $message');
  }
}