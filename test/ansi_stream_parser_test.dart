import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/cli/ansi_stream_parser.dart';
import 'package:agentsdroid/models/agent_event.dart';

void main() {
  group('AnsiStreamParser Tests', () {
    test('stripAnsi cleans colors, styles, and OSC sequences', () {
      const coloredText = '\x1B[31mError:\x1B[0m \x1B[1mFile not found\x1B[0m';
      expect(AnsiStreamParser.stripAnsi(coloredText), equals('Error: File not found'));

      const oscText = '\x1B]0;Terminal Title\x07Hello from terminal';
      expect(AnsiStreamParser.stripAnsi(oscText), equals('Hello from terminal'));
    });

    test('parses thinking stream', () async {
      final parser = AnsiStreamParser();
      final events = <AgentEvent>[];
      final sub = parser.eventStream.listen(events.add);

      parser.feedChunk('Claude is thinking: Analyzing the project architecture...\n');
      parser.flush();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.any((e) => e is StatusEvent && e.state == AgentState.thinking), isTrue);
      expect(events.any((e) => e is ThoughtEvent && e.thought.contains('Analyzing the project')), isTrue);

      await sub.cancel();
      parser.dispose();
    });

    test('parses tool call command', () async {
      final parser = AnsiStreamParser();
      final events = <AgentEvent>[];
      final sub = parser.eventStream.listen(events.add);

      parser.feedChunk('\x1B[32mRunning: flutter pub get\x1B[0m\n');
      parser.flush();
      await Future.delayed(const Duration(milliseconds: 10));

      final toolEvent = events.whereType<ToolCallEvent>().firstOrNull;
      expect(toolEvent, isNotNull);
      expect(toolEvent!.toolName, equals('run_command'));
      expect(toolEvent.arguments['command'], equals('flutter pub get'));

      await sub.cancel();
      parser.dispose();
    });

    test('detects interactive approval prompt', () async {
      final parser = AnsiStreamParser();
      final events = <AgentEvent>[];
      final sub = parser.eventStream.listen(events.add);

      parser.feedChunk('Allow Claude to run: rm -rf build/ [y/n]');
      await Future.delayed(const Duration(milliseconds: 10));

      final statusEvent = events.whereType<StatusEvent>().firstOrNull;
      expect(statusEvent, isNotNull);
      expect(statusEvent!.state, equals(AgentState.waitingApproval));

      final approvalEvent = events.whereType<ToolCallEvent>().firstOrNull;
      expect(approvalEvent, isNotNull);
      expect(approvalEvent!.status, equals(ToolCallStatus.pending));
      expect(approvalEvent.autoApproved, isFalse);

      await sub.cancel();
      parser.dispose();
    });

    test('parses unified diff output into DiffEvent', () async {
      final parser = AnsiStreamParser();
      final events = <AgentEvent>[];
      final sub = parser.eventStream.listen(events.add);

      const diffChunk = '''
--- a/lib/example.dart
+++ b/lib/example.dart
@@ -1,3 +1,3 @@
 void main() {
-  print("old");
+  print("new");
 }
''';

      parser.feedChunk(diffChunk);
      parser.flush();
      await Future.delayed(const Duration(milliseconds: 10));

      final diffEvent = events.whereType<DiffEvent>().firstOrNull;
      expect(diffEvent, isNotNull);
      expect(diffEvent!.filePath, equals('lib/example.dart'));
      expect(diffEvent.diffLines.length, equals(4));
      expect(diffEvent.diffLines[1].type, equals(DiffLineType.removed));
      expect(diffEvent.diffLines[2].type, equals(DiffLineType.added));

      await sub.cancel();
      parser.dispose();
    });
  });
}
