import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/builtin/builtin_agent_engine.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuiltinAgentEngine History Sync Tests', () {
    late Directory docDir;
    late KeyVault keyVault;
    late WorkspaceService workspace;
    late BuiltinAgentEngine engine;

    setUp(() async {
      docDir = await Directory.systemTemp.createTemp('agentsdroid_history_test_');
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      const secureStorage = FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      keyVault = KeyVault(secureStorage, prefs);
      workspace = WorkspaceService();
      await workspace.init(baseDir: docDir);
      engine = BuiltinAgentEngine(keyVault, workspace);
    });

    tearDown(() async {
      if (await docDir.exists()) {
        await docDir.delete(recursive: true);
      }
    });

    test('syncSessionHistory with empty messages sets up initial system prompt', () {
      engine.syncSessionHistory([]);

      expect(engine.openaiHistory.length, equals(1));
      expect(engine.openaiHistory.first['role'], equals('system'));
      expect(engine.anthropicHistory.isEmpty, isTrue);
    });

    test('syncSessionHistory restores plain user and assistant conversation', () {
      final prior = [
        ChatMessage(
          id: '1',
          role: MessageRole.user,
          content: 'Hello, what can you do?',
        ),
        ChatMessage(
          id: '2',
          role: MessageRole.assistant,
          content: 'I am your Android coding assistant.',
        ),
      ];

      engine.syncSessionHistory(prior);

      // OpenAI history: system prompt + user + assistant
      expect(engine.openaiHistory.length, equals(3));
      expect(engine.openaiHistory[0]['role'], equals('system'));
      expect(engine.openaiHistory[1]['role'], equals('user'));
      expect(engine.openaiHistory[1]['content'], equals('Hello, what can you do?'));
      expect(engine.openaiHistory[2]['role'], equals('assistant'));
      expect(engine.openaiHistory[2]['content'], equals('I am your Android coding assistant.'));

      // Anthropic history: user + assistant (system prompt passed via top-level param)
      expect(engine.anthropicHistory.length, equals(2));
      expect(engine.anthropicHistory[0]['role'], equals('user'));
      expect(engine.anthropicHistory[0]['content'], equals('Hello, what can you do?'));
      expect(engine.anthropicHistory[1]['role'], equals('assistant'));
      expect(engine.anthropicHistory[1]['content'], equals('I am your Android coding assistant.'));
    });

    test('syncSessionHistory properly reconstructs tool calls and execution results', () {
      final toolCall = ToolCallEvent(
        toolCallId: 'call_abc_123',
        toolName: 'read_file',
        arguments: {'path': 'pubspec.yaml'},
        status: ToolCallStatus.approved,
        result: 'name: test_project',
      );

      final prior = [
        ChatMessage(
          id: '1',
          role: MessageRole.user,
          content: 'Check pubspec.yaml',
        ),
        ChatMessage(
          id: '2',
          role: MessageRole.assistant,
          blocks: [
            ToolCallBlock(toolCall),
            TextBlock('The project name is test_project.'),
          ],
        ),
      ];

      engine.syncSessionHistory(prior);

      // OpenAI history verification
      // 0: system
      // 1: user ('Check pubspec.yaml')
      // 2: assistant (tool_calls)
      // 3: tool (call_abc_123 result)
      // 4: assistant ('The project name is test_project.')
      expect(engine.openaiHistory.length, equals(5));
      expect(engine.openaiHistory[1]['role'], equals('user'));
      expect(engine.openaiHistory[2]['role'], equals('assistant'));
      expect(engine.openaiHistory[2]['tool_calls'], isNotNull);
      final toolCalls = engine.openaiHistory[2]['tool_calls'] as List;
      expect(toolCalls.first['id'], equals('call_abc_123'));
      expect(engine.openaiHistory[3]['role'], equals('tool'));
      expect(engine.openaiHistory[3]['tool_call_id'], equals('call_abc_123'));
      expect(engine.openaiHistory[3]['content'], equals('name: test_project'));
      expect(engine.openaiHistory[4]['role'], equals('assistant'));
      expect(engine.openaiHistory[4]['content'], equals('The project name is test_project.'));

      // Anthropic history verification
      // 0: user ('Check pubspec.yaml')
      // 1: assistant (tool_use block)
      // 2: user (tool_result block)
      // 3: assistant ('The project name is test_project.')
      expect(engine.anthropicHistory.length, equals(4));
      expect(engine.anthropicHistory[0]['role'], equals('user'));
      expect(engine.anthropicHistory[1]['role'], equals('assistant'));
      final anthropicUses = engine.anthropicHistory[1]['content'] as List;
      expect(anthropicUses.first['type'], equals('tool_use'));
      expect(anthropicUses.first['id'], equals('call_abc_123'));
      expect(engine.anthropicHistory[2]['role'], equals('user'));
      final anthropicResults = engine.anthropicHistory[2]['content'] as List;
      expect(anthropicResults.first['type'], equals('tool_result'));
      expect(anthropicResults.first['tool_use_id'], equals('call_abc_123'));
      expect(anthropicResults.first['content'], equals('name: test_project'));
      expect(engine.anthropicHistory[3]['role'], equals('assistant'));
      expect(engine.anthropicHistory[3]['content'], equals('The project name is test_project.'));
    });

    test('syncSessionHistory enforces Anthropic alternating role invariant', () {
      final prior = [
        ChatMessage(
          id: '1',
          role: MessageRole.user,
          content: 'First query',
        ),
        ChatMessage(
          id: '2',
          role: MessageRole.user,
          content: 'Second query without assistant reply in between',
        ),
        ChatMessage(
          id: '3',
          role: MessageRole.assistant,
          content: 'Part 1 response',
        ),
        ChatMessage(
          id: '4',
          role: MessageRole.assistant,
          content: 'Part 2 response',
        ),
      ];

      engine.syncSessionHistory(prior);

      // In Anthropic history, consecutive user messages and assistant messages should be merged
      expect(engine.anthropicHistory.length, equals(2));
      expect(engine.anthropicHistory[0]['role'], equals('user'));
      expect(engine.anthropicHistory[0]['content'], contains('First query'));
      expect(engine.anthropicHistory[0]['content'], contains('Second query'));
      expect(engine.anthropicHistory[1]['role'], equals('assistant'));
      expect(engine.anthropicHistory[1]['content'], contains('Part 1 response'));
      expect(engine.anthropicHistory[1]['content'], contains('Part 2 response'));
    });

    test('resetSession clears history completely', () {
      final prior = [
        ChatMessage(
          id: '1',
          role: MessageRole.user,
          content: 'Hello',
        ),
      ];
      engine.syncSessionHistory(prior);
      expect(engine.openaiHistory.isNotEmpty, isTrue);
      expect(engine.anthropicHistory.isNotEmpty, isTrue);

      engine.resetSession();
      expect(engine.openaiHistory.isEmpty, isTrue);
      expect(engine.anthropicHistory.isEmpty, isTrue);
    });
  });
}
