import 'dart:developer' as dev;

class AppLogger {
  static void info(String message, {Object? data}) => dev.log(message, name: 'VMS', error: data);
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      dev.log(message, name: 'VMS', error: error, stackTrace: stackTrace);
}
