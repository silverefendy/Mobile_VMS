import 'package:flutter/widgets.dart';

import '../logging/app_logger.dart';

class AppLifecycleCoordinator with WidgetsBindingObserver {
  AppLifecycleCoordinator({required VoidCallback onResume, required VoidCallback onPause})
      : _onResume = onResume,
        _onPause = onPause;

  final VoidCallback _onResume;
  final VoidCallback _onPause;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.event('app_lifecycle', payload: {'state': state.name});
    if (state == AppLifecycleState.resumed) _onResume();
    if (state == AppLifecycleState.paused) _onPause();
  }
}
