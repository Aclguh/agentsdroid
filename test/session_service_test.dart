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

    test('archives and unarchives sessions', () async {
      final s = await sessionService.createSession(title: '归档测试会话');
      s.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'test'));
      await sessionService.saveSession(s);

      // Initially not archived
      var activeList = await sessionService.listSessions(isArchived: false);
      var archivedList = await sessionService.listSessions(isArchived: true);
      expect(activeList.length, equals(1));
      expect(archivedList, isEmpty);

      // Archive session
      await sessionService.archiveSession(s.id);
      activeList = await sessionService.listSessions(isArchived: false);
      archivedList = await sessionService.listSessions(isArchived: true);
      expect(activeList, isEmpty);
      expect(archivedList.length, equals(1));
      expect(archivedList.first.id, equals(s.id));
      expect(archivedList.first.isArchived, isTrue);

      // Unarchive session
      await sessionService.unarchiveSession(s.id);
      activeList = await sessionService.listSessions(isArchived: false);
      archivedList = await sessionService.listSessions(isArchived: true);
      expect(activeList.length, equals(1));
      expect(archivedList, isEmpty);
      expect(activeList.first.isArchived, isFalse);
    });

    test('supports session project association', () async {
      final s = await sessionService.createSession(
        title: '项目内部会话',
        projectName: 'agentsdroid',
      );
      s.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'hello in project'));
      await sessionService.saveSession(s);

      final list = await sessionService.listSessions();
      expect(list.length, equals(1));
      expect(list.first.projectName, equals('agentsdroid'));

      final loaded = await sessionService.getSession(s.id);
      expect(loaded?.projectName, equals('agentsdroid'));
    });

    test('persists sessions_index.json and reloads directly from index cache', () async {
      final s = await sessionService.createSession(title: '索引测试会话');
      s.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'index content'));
      await sessionService.saveSession(s);

      // Verify sessions_index.json exists on disk
      final indexFile = File('${tempDir.path}/sessions/sessions_index.json');
      expect(await indexFile.exists(), isTrue);

      // Re-initialize a brand new SessionService instance on the same directory
      final service2 = SessionService();
      await service2.init(baseDir: tempDir);

      final list = await service2.listSessions();
      expect(list.length, equals(1));
      expect(list.first.id, equals(s.id));
      expect(list.first.title, equals('索引测试会话'));
    });

    test('corrupted sessions_index.json recovers by directory scan and purges empty files', () async {
      final s = await sessionService.createSession(title: '正常会话');
      s.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: '正常内容'));
      await sessionService.saveSession(s);

      // Create an empty session json on disk that should be purged during rebuild
      final emptyFile = File('${tempDir.path}/sessions/empty_session.json');
      await emptyFile.writeAsString('{"id":"empty_session","title":"空","messages":[]}');

      // Corrupt the sessions_index.json
      final indexFile = File('${tempDir.path}/sessions/sessions_index.json');
      await indexFile.writeAsString('MALFORMED_JSON_CONTENT{{{');

      // Re-initialize SessionService
      final service2 = SessionService();
      await service2.init(baseDir: tempDir);

      final list = await service2.listSessions();
      expect(list.length, equals(1));
      expect(list.first.id, equals(s.id));
      expect(list.first.title, equals('正常会话'));
      expect(await emptyFile.exists(), isFalse);
    });

    test('renameSession, archiveSession, and unarchiveSession throw FileSystemException when session does not exist', () async {
      expect(
        () => sessionService.renameSession('non_existent', 'New Title'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        () => sessionService.archiveSession('non_existent'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        () => sessionService.unarchiveSession('non_existent'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('getSession on empty cached session purges file and returns null', () async {
      final s = await sessionService.createSession(title: '空缓存会话');
      // Session has empty messages
      final loaded = await sessionService.getSession(s.id);
      expect(loaded, isNull);
    });
  });
}
