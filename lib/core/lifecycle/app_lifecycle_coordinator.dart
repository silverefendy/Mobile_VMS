import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logging/app_logger.dart';

class AppLifecycleCoordinator with WidgetsBindingObserver {
  AppLifecycleCoordinator({
    required FutureOr<void> Function() onResume,
    required FutureOr<void> Function() onPause,
  })  : _onResume = onResume,
        _onPause = onPause;

  final FutureOr<void> Function() _onResume;
  final FutureOr<void> Function() _onPause;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.event('app_lifecycle', payload: {'state': state.name});
    if (state == AppLifecycleState.resumed) {
      unawaited(Future<void>.sync(_onResume).catchError(
        (Object error, StackTrace stackTrace) => AppLogger.error(
          'app_resume_failed',
          error: error,
          stackTrace: stackTrace,
        ),
      ));
    }
    if (state == AppLifecycleState.paused) {
      unawaited(Future<void>.sync(_onPause).catchError(
        (Object error, StackTrace stackTrace) => AppLogger.error(
          'app_pause_failed',
          error: error,
          stackTrace: stackTrace,
        ),
      ));
    }
  }
}
