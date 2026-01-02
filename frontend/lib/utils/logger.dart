import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// SMARTCARE+ Logger Utility
/// Provides structured logging for debugging and monitoring.
class AppLogger {
  static const String _tag = 'SMARTCARE+';
  
  /// Log levels
  static const int _levelDebug = 0;
  static const int _levelInfo = 1;
  static const int _levelWarning = 2;
  static const int _levelError = 3;
  
  /// Current minimum log level (only logs >= this level are shown)
  static int _minLevel = kDebugMode ? _levelDebug : _levelInfo;
  
  /// Enable/disable logging
  static bool enabled = true;
  
  /// Set minimum log level
  static void setLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        _minLevel = _levelDebug;
        break;
      case 'info':
        _minLevel = _levelInfo;
        break;
      case 'warning':
        _minLevel = _levelWarning;
        break;
      case 'error':
        _minLevel = _levelError;
        break;
    }
  }
  
  /// Debug log - for detailed debugging info
  static void debug(String message, {String? tag, Object? data}) {
    _log(_levelDebug, '🔍', message, tag: tag, data: data);
  }
  
  /// Info log - for general information
  static void info(String message, {String? tag, Object? data}) {
    _log(_levelInfo, 'ℹ️', message, tag: tag, data: data);
  }
  
  /// Warning log - for potential issues
  static void warning(String message, {String? tag, Object? data}) {
    _log(_levelWarning, '⚠️', message, tag: tag, data: data);
  }
  
  /// Error log - for errors and exceptions
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelError, '❌', message, tag: tag, data: error);
    if (stackTrace != null && kDebugMode) {
      developer.log('Stack trace:', name: tag ?? _tag);
      developer.log(stackTrace.toString(), name: tag ?? _tag);
    }
  }
  
  /// API log - specifically for API calls
  static void api(String method, String endpoint, {int? statusCode, Object? data, Duration? duration}) {
    final status = statusCode != null 
        ? (statusCode < 400 ? '✅' : '❌') 
        : '➡️';
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    final statusStr = statusCode != null ? ' → $statusCode' : '';
    
    _log(_levelInfo, status, '$method $endpoint$statusStr$durationStr', tag: 'API', data: data);
  }
  
  /// Navigation log - for screen transitions
  static void navigation(String action, String route, {Object? params}) {
    _log(_levelInfo, '🚀', '$action: $route', tag: 'NAV', data: params);
  }
  
  /// Auth log - for authentication events
  static void auth(String event, {String? userId, Object? data}) {
    final userStr = userId != null ? ' (user: ${userId.substring(0, 8)}...)' : '';
    _log(_levelInfo, '🔐', '$event$userStr', tag: 'AUTH', data: data);
  }
  
  /// Connection log - for connection events
  static void connection(String event, {Object? data}) {
    _log(_levelInfo, '🔗', event, tag: 'CONNECT', data: data);
  }
  
  /// Internal log method
  static void _log(int level, String emoji, String message, {String? tag, Object? data}) {
    if (!enabled || level < _minLevel) return;
    
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final tagStr = tag ?? _tag;
    final logMessage = '[$timestamp] $emoji [$tagStr] $message';
    
    // Use developer.log for better DevTools integration
    developer.log(
      logMessage,
      name: _tag,
      level: level * 400, // Mapping to developer.log levels
    );
    
    // Also print for console visibility
    if (kDebugMode) {
      // ignore: avoid_print
      print(logMessage);
      if (data != null) {
        // ignore: avoid_print
        print('    └─ Data: $data');
      }
    }
  }
  
  /// Log a separator line for visual clarity
  static void separator({String? label}) {
    if (!enabled) return;
    final line = label != null 
        ? '═══════════════ $label ═══════════════' 
        : '═══════════════════════════════════════';
    if (kDebugMode) {
      // ignore: avoid_print
      print(line);
    }
  }
}
