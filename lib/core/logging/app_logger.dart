import 'dart:convert';
import 'dart:developer' as dev;

import '../../config/app_config.dart';

class AppLogger {
  static void info(String message, {Map<String, Object?> context = const {}}) => _log('INFO', message, context: context);

  static void warn(String message, {Map<String, Object?> context = const {}}) => _log('WARN', message, context: context);

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) => _log('ERROR', message, error: error, stackTrace: stackTrace, context: context);

  static void event(String name, {Map<String, Object?> payload = const {}}) => _log('EVENT', name, context: payload);

  static void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    final data = {
      'level': level,
      'env': AppConfig.environment.name,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'message': message,
      if (context.isNotEmpty) 'context': context,
    };
    dev.log(jsonEncode(data), name: 'VMS', error: error, stackTrace: stackTrace);
  }
}
