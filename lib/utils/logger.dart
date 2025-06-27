import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// A simple logging utility for the Cobra App.
/// 
/// This class provides static methods for logging messages with different
/// severity levels. In production, logs will be filtered based on importance.
class Logger {
  /// Log a debug message. Only shown in debug mode.
  static void debug(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'DEBUG');
    }
  }

  /// Log an info message. Only shown in debug mode.
  static void info(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'INFO');
    }
  }

  /// Log a warning message.
  static void warning(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'WARNING');
    } else {
      // In production, log warnings to a service or file if needed
      developer.log(message, name: 'WARNING');
    }
  }

  /// Log an error message.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    // Always log errors, even in production
    if (error != null) {
      developer.log('$message\n$error', name: 'ERROR', error: error, stackTrace: stackTrace ?? StackTrace.current);
    } else {
      developer.log(message, name: 'ERROR');
    }
  }
}
