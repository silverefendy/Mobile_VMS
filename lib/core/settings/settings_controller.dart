import 'package:flutter/foundation.dart';

enum AppThemeMode { system, light, dark }

class SettingsController extends ChangeNotifier {
  bool scanSoundEnabled = true;
  bool scanVibrationEnabled = true;
  AppThemeMode themeMode = AppThemeMode.system;

  void setScanSound(bool enabled) {
    scanSoundEnabled = enabled;
    notifyListeners();
  }

  void setScanVibration(bool enabled) {
    scanVibrationEnabled = enabled;
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }
}
