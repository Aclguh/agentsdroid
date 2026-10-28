import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3);

  final int priority;
  const LogLevel(this.priority);
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedMessage {
    final timeStr = timestamp.toIso8601String().substring(11, 23);
    final errorStr = error != null ? '\nError: $error' : '';
    final stackStr = stackTrace != null ? '\nStack: $stackTrace' : '';
    return '[$timeStr] [${level.name.toUpperCase()}] [$tag] $message$errorStr$stackStr';
  }

  @override
  String toString() => formattedMessage;
}

/// Unified logging framework with log levels, live stream, and circular buffer dump
class AppLogger {
  static LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;
  static bool isConsoleOutputEnabled = true;
  static const int maxBufferSize = 500;

  static final List<LogEntry> _buffer = [];
  static final StreamController<LogEntry> _controller = StreamController<LogEntry>.broadcast();

  /// Stream of log entries for live UI debug panels and terminal drawers
  static Stream<LogEntry> get logStream => _controller.stream;

  /// Retrieve recent log entries
  static List<LogEntry> getRecentLogs() => List.unmodifiable(_buffer);

  /// Clear in-memory log buffer
  static void clearLogs() {
    _buffer.clear();
  }

  static void log(
    LogLevel level,
    String message, {
    String tag = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    if (_buffer.length >= maxBufferSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(entry);

    if (_controller.hasListener) {
      _controller.add(entry);
    }

    if (level.priority >= minLevel.priority && isConsoleOutputEnabled) {
      debugPrint(entry.formattedMessage);
    }
  }

  static void debug(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void warn(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    log(LogLevel.warn, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
}
