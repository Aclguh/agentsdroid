import 'package:flutter_test/flutter_test.dart';

import 'package:agentsdroid/core/app_meta.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/models/chat_session.dart';

void main() {
  group('AppMeta Tests', () {
    test('verifies static app metadata properties', () {
      expect(AppMeta.appName, equals('AgentsDroid'));
      expect(AppMeta.version, isNotEmpty);
      expect(AppMeta.buildNumber, equals('1'));
      expect(AppMeta.packageName, equals('com.agentsdroid.agentsdroid'));
      expect(AppMeta.repoUrl, contains('agentsdroid'));
      expect(AppMeta.license, contains('MIT'));
      expect(AppMeta.iconAsset, contains('png'));
    });
  });

  group('AgentEvent and Subclasses Tests', () {
    test('StatusEvent captures state and optional message', () {
      final now = DateTime.now();
      final event = StatusEvent(AgentState.thinking, message: 'Processing...', timestamp: now);
      expect(event.state, equals(AgentState.thinking));
      expect(event.message, equals('Processing...'));
      expect(event.timestamp, equals(now));
    });

    test('ThoughtEvent captures thought text and completion state', () {
      final event = ThoughtEvent(thought: 'Step 1: Check files', isComplete: true);
      expect(event.thought, equals('Step 1: Check files'));
      expect(event.isComplete, isTrue);
      expect(event.timestamp, isNotNull);
    });

    test('MessageEvent captures text, isComplete, and isDelta', () {
      final event = MessageEvent(text: 'Hello world', isComplete: true, isDelta: true);
      expect(event.text, equals('Hello world'));
      expect(event.isComplete, isTrue);
      expect(event.isDelta, isTrue);
    });

    test('ToolCallEvent serializes, deserializes, and copies correctly', () {
      final original = ToolCallEvent(
        toolCallId: 'tc_123',
        toolName: 'read_file',
        arguments: {'path': 'lib/main.dart'},
        status: ToolCallStatus.pending,
        autoApproved: false,
      );

      final json = original.toJson();
      expect(json['toolCallId'], equals('tc_123'));
      expect(json['toolName'], equals('read_file'));
      expect(json['status'], equals('pending'));

      final restored = ToolCallEvent.fromJson(json);
      expect(restored.toolCallId, equals('tc_123'));
      expect(restored.toolName, equals('read_file'));
      expect(restored.arguments['path'], equals('lib/main.dart'));
      expect(restored.status, equals(ToolCallStatus.pending));

      final updated = restored.copyWith(
        status: ToolCallStatus.completed,
        autoApproved: true,
        result: 'file content',
        errorMessage: null,
      );
      expect(updated.status, equals(ToolCallStatus.completed));
      expect(updated.autoApproved, isTrue);
      expect(updated.result, equals('file content'));
      expect(updated.errorMessage, isNull);
    });

    test('DiffEvent and DiffLine serialize and deserialize', () {
      final diffLine1 = DiffLine(type: DiffLineType.removed, text: 'old line', oldLineNumber: 1);
      final diffLine2 = DiffLine(type: DiffLineType.added, text: 'new line', newLineNumber: 1);
      final diffLine3 = DiffLine(type: DiffLineType.unchanged, text: 'common line', oldLineNumber: 2, newLineNumber: 2);

      final diffEvent = DiffEvent(
        filePath: 'test.txt',
        originalContent: 'old line\ncommon line',
        newContent: 'new line\ncommon line',
        diffLines: [diffLine1, diffLine2, diffLine3],
      );

      final json = diffEvent.toJson();
      expect(json['filePath'], equals('test.txt'));
      expect(json['diffLines'], hasLength(3));

      final restored = DiffEvent.fromJson(json);
      expect(restored.filePath, equals('test.txt'));
      expect(restored.originalContent, equals('old line\ncommon line'));
      expect(restored.newContent, equals('new line\ncommon line'));
      expect(restored.diffLines, hasLength(3));
      expect(restored.diffLines[0].type, equals(DiffLineType.removed));
      expect(restored.diffLines[1].type, equals(DiffLineType.added));
      expect(restored.diffLines[2].type, equals(DiffLineType.unchanged));
    });
  });

  group('ChatMessage and MessageBlock Tests', () {
    test('MessageBlock.fromJson parses all block types and unknown fallback', () {
      final thoughtBlock = MessageBlock.fromJson({
        'type': 'thought',
        'thought': 'Thinking...',
        'durationSeconds': 5,
      }) as ThoughtBlock;
      expect(thoughtBlock.thought, equals('Thinking...'));
      expect(thoughtBlock.durationSeconds, equals(5));
      expect(thoughtBlock.toJson()['type'], equals('thought'));

      final textBlock = MessageBlock.fromJson({
        'type': 'text',
        'text': 'Some text',
      }) as TextBlock;
      expect(textBlock.text, equals('Some text'));
      expect(textBlock.toJson()['type'], equals('text'));

      final tcBlock = MessageBlock.fromJson({
        'type': 'tool_call',
        'toolCall': {
          'toolCallId': 'tc_9',
          'toolName': 'ls',
          'arguments': <String, dynamic>{},
          'status': 'pending',
        },
      }) as ToolCallBlock;
      expect(tcBlock.toolCall.toolName, equals('ls'));
      expect(tcBlock.toJson()['type'], equals('tool_call'));

      final diffBlock = MessageBlock.fromJson({
        'type': 'diff',
        'diff': {
          'filePath': 'a.txt',
          'diffLines': <dynamic>[],
        },
      }) as DiffBlock;
      expect(diffBlock.diff.filePath, equals('a.txt'));
      expect(diffBlock.toJson()['type'], equals('diff'));

      final unknownBlock = MessageBlock.fromJson({
        'type': 'custom_unknown',
        'text': 'fallback text',
      }) as TextBlock;
      expect(unknownBlock.text, equals('fallback text'));
    });

    test('ChatMessage initializes blocks from content, thought, toolCalls, diffs', () {
      final tc = ToolCallEvent(
        toolCallId: 'tc_1',
        toolName: 'exec',
        arguments: {},
      );
      final diff = DiffEvent(
        filePath: 'f.dart',
        originalContent: '',
        newContent: '',
        diffLines: [],
      );

      final msg = ChatMessage(
        id: 'msg_1',
        role: MessageRole.assistant,
        thought: 'initial thought',
        content: 'initial content',
        toolCalls: [tc],
        diffs: [diff],
        isStreaming: true,
      );

      expect(msg.role, equals(MessageRole.assistant));
      expect(msg.thought, equals('initial thought'));
      expect(msg.content, equals('initial content'));
      expect(msg.toolCalls, hasLength(1));
      expect(msg.diffs, hasLength(1));
      expect(msg.isStreaming, isTrue);

      // Test thought getter and setter
      msg.thought = 'updated thought';
      expect(msg.thought, equals('updated thought'));

      // Test content getter and setter
      msg.content = 'updated content';
      expect(msg.content, equals('updated content'));

      // Test copyWith
      final copied = msg.copyWith(content: 'copied content', isStreaming: false);
      expect(copied.content, equals('copied content'));
      expect(copied.isStreaming, isFalse);
      expect(copied.thought, equals('updated thought'));

      // Test serialization & deserialization with blocks
      final json = msg.toJson();
      final fromJsonMsg = ChatMessage.fromJson(json);
      expect(fromJsonMsg.id, equals('msg_1'));
      expect(fromJsonMsg.thought, equals('updated thought'));
      expect(fromJsonMsg.content, equals('updated content'));
      expect(fromJsonMsg.toolCalls, hasLength(1));
    });

    test('ChatMessage.fromJson parses legacy format without blocks', () {
      final legacyJson = {
        'id': 'legacy_1',
        'role': 'user',
        'content': 'legacy text',
        'thought': 'legacy thought',
      };

      final msg = ChatMessage.fromJson(legacyJson);
      expect(msg.id, equals('legacy_1'));
      expect(msg.role, equals(MessageRole.user));
      expect(msg.content, equals('legacy text'));
      expect(msg.thought, equals('legacy thought'));
    });

    test('ChatMessage thought and content setters handle empty initial states', () {
      final emptyMsg = ChatMessage(id: 'empty', role: MessageRole.user);
      expect(emptyMsg.content, isEmpty);
      expect(emptyMsg.thought, isNull);

      emptyMsg.thought = 'now has thought';
      expect(emptyMsg.thought, equals('now has thought'));

      emptyMsg.content = 'now has content';
      expect(emptyMsg.content, equals('now has content'));

      // Setting null thought does nothing
      emptyMsg.thought = null;
      expect(emptyMsg.thought, equals('now has thought'));
    });
  });

  group('ChatSession and ChatSessionSummary Tests', () {
    test('ChatSessionSummary properties and json mapping', () {
      final now = DateTime.now();
      final summary = ChatSessionSummary(
        id: 'sess_1',
        title: 'Session 1',
        projectName: 'agentsdroid',
        messageCount: 5,
        createdAt: now,
        updatedAt: now,
      );

      final json = summary.toJson();
      expect(json['id'], equals('sess_1'));
      expect(json['title'], equals('Session 1'));
      expect(json['projectName'], equals('agentsdroid'));
      expect(json['messageCount'], equals(5));

      final restored = ChatSessionSummary.fromJson(json);
      expect(restored.id, equals('sess_1'));
      expect(restored.title, equals('Session 1'));
      expect(restored.projectName, equals('agentsdroid'));
      expect(restored.messageCount, equals(5));
    });

    test('ChatSession toJson, fromJson, and toSummary', () {
      final msg = ChatMessage(id: 'm1', role: MessageRole.user, content: 'hi');
      final session = ChatSession(
        id: 'sess_100',
        title: 'Full Session',
        projectName: 'default',
        messages: [msg],
      );

      expect(session.messages, hasLength(1));
      final summary = session.toSummary();
      expect(summary.id, equals('sess_100'));
      expect(summary.title, equals('Full Session'));
      expect(summary.messageCount, equals(1));

      final json = session.toJson();
      final restored = ChatSession.fromJson(json);
      expect(restored.id, equals('sess_100'));
      expect(restored.title, equals('Full Session'));
      expect(restored.messages, hasLength(1));
      expect(restored.messages.first.content, equals('hi'));
    });
  });
}
