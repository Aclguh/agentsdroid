import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';

void main() {
  group('SessionService Tests', () {
    late Directory tempDir;
    late SessionService sessionService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('agentsdroid_session_test_');
      sessionService = SessionService();
      await sessionService.init(baseDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates, saves, loads and lists sessions with messages', () async {
      final session = await sessionService.createSession(title: '测试会话 1');
      expect(session.id, isNotEmpty);
      expect(session.title, equals('测试会话 1'));

      // Empty session is not listed in history
      expect(await sessionService.listSessions(), isEmpty);

      // Add messages to session
      final toolCall = ToolCallEvent(
        toolCallId: 'cmd_1',
        toolName: 'run_command',
        arguments: {'command': 'ls -la'},
        status: ToolCallStatus.completed,
        result: 'total 0',
      );

      final msg = ChatMessage(
        id: 'msg_1',
        role: MessageRole.assistant,
        blocks: [
          ThoughtBlock('Thinking about directory...'),
          TextBlock('Let me check files.'),
          ToolCallBlock(toolCall),
        ],
      );

      session.messages.add(msg);
      await sessionService.saveSession(session);

      // List sessions now includes it
      final list = await sessionService.listSessions();
      expect(list.length, equals(1));
      expect(list.first.id, equals(session.id));
      expect(list.first.title, equals('测试会话 1'));
      expect(list.first.messageCount, equals(1));

      // Reload full session
      final loaded = await sessionService.getSession(session.id);
      expect(loaded, isNotNull);
      expect(loaded!.messages.length, equals(1));
      expect(loaded.messages.first.blocks.length, equals(3));
      expect(loaded.messages.first.blocks[0], isA<ThoughtBlock>());
      expect((loaded.messages.first.blocks[0] as ThoughtBlock).thought, equals('Thinking about directory...'));
      expect(loaded.messages.first.blocks[2], isA<ToolCallBlock>());
      expect((loaded.messages.first.blocks[2] as ToolCallBlock).toolCall.toolName, equals('run_command'));
    });

    test('renames and deletes sessions', () async {
      final s1 = await sessionService.createSession(title: '会话 A');
      s1.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'msg 1'));
      await sessionService.saveSession(s1);

      final s2 = await sessionService.createSession(title: '会话 B');
      s2.messages.add(ChatMessage(id: 'm2', role: MessageRole.user, content: 'msg 2'));
      await sessionService.saveSession(s2);

      var list = await sessionService.listSessions();
      expect(list.length, equals(2));

      // Rename s1
      await sessionService.renameSession(s1.id, '重命名的会话 A');
      final renamed = await sessionService.getSession(s1.id);
      expect(renamed?.title, equals('重命名的会话 A'));

      // Delete s2
      await sessionService.deleteSession(s2.id);
      list = await sessionService.listSessions();
      expect(list.length, equals(1));
      expect(list.first.id, equals(s1.id));

      final deleted = await sessionService.getSession(s2.id);
      expect(deleted, isNull);
    });

    test('empty sessions are not retained in history or disk', () async {
      final emptySession = await sessionService.createSession(title: '空对话');
      // Calling saveSession on empty session will not persist or will delete file
      await sessionService.saveSession(emptySession);

      final list = await sessionService.listSessions();
      expect(list, isEmpty);
      expect(await sessionService.getSession(emptySession.id), isNull);
    });

    test('getOrCreateLatestSession returns latest with messages or creates default', () async {
      // First call when no sessions exist with messages
      final s1 = await sessionService.getOrCreateLatestSession(defaultTitle: '首个会话');
      expect(s1.title, equals('首个会话'));
      expect(s1.messages, isEmpty);

      // Add message and save s1
      s1.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'test'));
      await sessionService.saveSession(s1);

      // Second call: returns existing latest
      final s2 = await sessionService.getOrCreateLatestSession(defaultTitle: '新默认会话');
      expect(s2.id, equals(s1.id));
      expect(s2.title, equals('首个会话'));
    });
  });
}
