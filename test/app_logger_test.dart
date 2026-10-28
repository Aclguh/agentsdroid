import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/utils/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clearLogs();
    AppLogger.isConsoleOutputEnabled = false; // silence test output
    AppLogger.minLevel = LogLevel.debug;
  });

  group('AppLogger Unified Logging Framework Tests (CODE-03)', () {
    test('records log entries across all severity levels', () {
      AppLogger.debug('Debug message', tag: 'Test');
      AppLogger.info('Info message', tag: 'Test');
      AppLogger.warn('Warn message', tag: 'Test');
      AppLogger.error('Error message', tag: 'Test');

      final logs = AppLogger.getRecentLogs();
      expect(logs.length, equals(4));
      expect(logs[0].level, equals(LogLevel.debug));
      expect(logs[0].message, equals('Debug message'));
      expect(logs[1].level, equals(LogLevel.info));
      expect(logs[2].level, equals(LogLevel.warn));
      expect(logs[3].level, equals(LogLevel.error));
    });

    test('formats log entry string properly with tag and level', () {
      AppLogger.info('Hello AgentsDroid', tag: 'Subsystem');
      final entry = AppLogger.getRecentLogs().first;

      expect(entry.tag, equals('Subsystem'));
      expect(entry.formattedMessage, contains('[INFO]'));
      expect(entry.formattedMessage, contains('[Subsystem]'));
      expect(entry.formattedMessage, contains('Hello AgentsDroid'));
    });

    test('broadcasts log entries to live logStream', () async {
      final emitted = <LogEntry>[];
      final sub = AppLogger.logStream.listen(emitted.add);

      AppLogger.info('Live streaming log test', tag: 'StreamTest');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emitted.length, equals(1));
      expect(emitted.first.message, equals('Live streaming log test'));
      await sub.cancel();
    });

    test('clears in-memory buffer', () {
      AppLogger.info('Log 1');
      AppLogger.info('Log 2');
      expect(AppLogger.getRecentLogs().length, equals(2));

      AppLogger.clearLogs();
      expect(AppLogger.getRecentLogs(), isEmpty);
    });

    test('enforces circular buffer limit of maxBufferSize', () {
      for (int i = 0; i < 550; i++) {
        AppLogger.debug('Message $i');
      }

      final logs = AppLogger.getRecentLogs();
      expect(logs.length, equals(AppLogger.maxBufferSize));
      // First 50 entries should have been pruned
      expect(logs.first.message, equals('Message 50'));
      expect(logs.last.message, equals('Message 549'));
    });
  });
}
