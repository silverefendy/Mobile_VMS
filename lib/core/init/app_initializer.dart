import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InitState { uninitialized, initializing, initialized, error }

class AppInitializer extends ChangeNotifier {
  InitState _state = InitState.uninitialized;
  String? _error;

  InitState get state => _state;
  String? get error => _error;
  bool get isInitialized => _state == InitState.initialized;
  bool get isInitializing => _state == InitState.initializing;

  Future<void> initialize() async {
    if (_state != InitState.uninitialized) return;
    
    _state = InitState.initializing;
    _error = null;
    notifyListeners();

    try {
      // Pre-load SharedPreferences to ensure it's ready for other services
      await SharedPreferences.getInstance();
      
      // Small delay to ensure all async init in main() can complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      _state = InitState.initialized;
    } catch (e) {
      _error = e.toString();
      _state = InitState.error;
      debugPrint('[AppInitializer] Initialization error: $e');
    }
    
    notifyListeners();
  }

  void reset() {
    _state = InitState.uninitialized;
    _error = null;
    notifyListeners();
  }
}