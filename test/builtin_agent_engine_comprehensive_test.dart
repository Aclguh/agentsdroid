import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/builtin/builtin_agent_engine.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/models/agent_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late KeyVault keyVault;
  late WorkspaceService workspace;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('builtin_engine_test_');
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keyVault = KeyVault(const FlutterSecureStorage(), prefs);
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BuiltinAgentEngine Comprehensive Tests', () {
    test('sendMessage with missing API key emits localized error event', () async {
      const provider = ModelProviderConfig(
        id: 'openai_no_key',
        name: 'OpenAI No Key',
        baseUrl: 'https://api.openai.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'gpt-4o', name: 'GPT 4o')],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('openai_no_key');
      await keyVault.setActiveModel('gpt-4o');

      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
      );

      final events = <AgentEvent>[];
      final sub = engine.eventStream.listen(events.add);

      await engine.startTask('Hello without key');
      await Future.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events.whereType<MessageEvent>().any((m) => m.text.contains('API Key') || m.text.contains('密钥')), isTrue);
      expect(engine.currentState, equals(AgentState.idle));
    });

    test('OpenAI compatible streaming parses reasoning_content and text chunks', () async {
      const provider = ModelProviderConfig(
        id: 'openai_test',
        name: 'OpenAI Test',
        baseUrl: 'https://api.openai.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'gpt-4o', name: 'GPT 4o', supportsThinking: true)],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('openai_test');
      await keyVault.setActiveModel('gpt-4o');
      await keyVault.setApiKeyForProvider('openai_test', 'sk-test-key');

      final sseLines = [
        'data: {"choices":[{"delta":{"reasoning_content":"Thinking about answer..."}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"Hello! How can "}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"I assist you?"}}]}\n\n',
        'data: [DONE]\n\n',
      ];

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(sseLines.map(utf8.encode)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
        httpClient: mockClient,
      );

      final events = <AgentEvent>[];
      final sub = engine.eventStream.listen(events.add);

      await engine.startTask('Hi');
      await sub.cancel();

      expect(events.whereType<ThoughtEvent>().any((t) => t.thought.contains('Thinking about')), isTrue);
      expect(events.whereType<MessageEvent>().any((m) => m.text.contains('I assist you?')), isTrue);
      expect(engine.currentState, equals(AgentState.idle));
    });

    test('Anthropic streaming parses thinking_delta and text_delta', () async {
      const provider = ModelProviderConfig(
        id: 'anthropic_test',
        name: 'Anthropic Test',
        baseUrl: 'https://api.anthropic.com',
        apiType: 'anthropic',
        models: [ModelConfig(id: 'claude-3-7-sonnet', name: 'Claude 3.7 Sonnet', supportsThinking: true)],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('anthropic_test');
      await keyVault.setActiveModel('claude-3-7-sonnet');
      await keyVault.setApiKeyForProvider('anthropic_test', 'sk-ant-key');

      final sseLines = [
        'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me check the repository structure."}}\n\n',
        'event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"The repository looks clean."}}\n\n',
        'event: message_stop\ndata: {"type":"message_stop"}\n\n',
      ];

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(sseLines.map(utf8.encode)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
        httpClient: mockClient,
      );

      final events = <AgentEvent>[];
      final sub = engine.eventStream.listen(events.add);

      await engine.startTask('Check repo');
      await sub.cancel();

      expect(events.whereType<ThoughtEvent>().any((t) => t.thought.contains('repository structure')), isTrue);
      expect(events.whereType<MessageEvent>().any((m) => m.text.contains('looks clean')), isTrue);
      expect(engine.currentState, equals(AgentState.idle));
    });

    test('Tool execution write_file and replace_in_file with approval flow', () async {
      const provider = ModelProviderConfig(
        id: 'openai_tool_test',
        name: 'OpenAI Tool Test',
        baseUrl: 'https://api.openai.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'gpt-4o', name: 'GPT 4o')],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('openai_tool_test');
      await keyVault.setActiveModel('gpt-4o');
      await keyVault.setApiKeyForProvider('openai_tool_test', 'sk-test-key');
      await keyVault.setApprovalMode(ApprovalMode.alwaysAsk);

      int callCount = 0;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          // Model calls write_file
          final sse = [
            'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"write_file","arguments":"{\\"path\\":\\"hello.txt\\",\\"content\\":\\"Hello World\\"}"}}]}}]}\n\n',
            'data: [DONE]\n\n',
          ];
          return http.StreamedResponse(Stream.fromIterable(sse.map(utf8.encode)), 200);
        } else {
          // Model finishes
          final sse = [
            'data: {"choices":[{"delta":{"content":"File written successfully."}}]}\n\n',
            'data: [DONE]\n\n',
          ];
          return http.StreamedResponse(Stream.fromIterable(sse.map(utf8.encode)), 200);
        }
      });

      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
        httpClient: mockClient,
      );

      final events = <AgentEvent>[];
      final sub = engine.eventStream.listen((event) {
        events.add(event);
        if (event is ToolCallEvent && event.status == ToolCallStatus.pending) {
          // Approve tool call asynchronously
          Future.microtask(() => engine.respondApproval(event.toolCallId, true));
        }
      });

      await engine.startTask('Write hello.txt');
      await sub.cancel();

      expect(events.whereType<ToolCallEvent>().any((tc) => tc.toolName == 'write_file'), isTrue);
      expect(await workspace.readFile('hello.txt'), equals('Hello World'));
    });

    test('Denying a tool call marks ToolCallStatus.rejected', () async {
      const provider = ModelProviderConfig(
        id: 'openai_deny_test',
        name: 'OpenAI Deny Test',
        baseUrl: 'https://api.openai.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'gpt-4o', name: 'GPT 4o')],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('openai_deny_test');
      await keyVault.setActiveModel('gpt-4o');
      await keyVault.setApiKeyForProvider('openai_deny_test', 'sk-test-key');
      await keyVault.setApprovalMode(ApprovalMode.alwaysAsk);

      int callCount = 0;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final sse = [
            'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_deny","function":{"name":"write_file","arguments":"{\\"path\\":\\"secret.txt\\",\\"content\\":\\"classified\\"}"}}]}}]}\n\n',
            'data: [DONE]\n\n',
          ];
          return http.StreamedResponse(Stream.fromIterable(sse.map(utf8.encode)), 200);
        } else {
          final sse = [
            'data: {"choices":[{"delta":{"content":"Operation denied by user."}}]}\n\n',
            'data: [DONE]\n\n',
          ];
          return http.StreamedResponse(Stream.fromIterable(sse.map(utf8.encode)), 200);
        }
      });

      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
        httpClient: mockClient,
      );

      final events = <AgentEvent>[];
      final sub = engine.eventStream.listen((event) {
        events.add(event);
        if (event is ToolCallEvent && event.status == ToolCallStatus.pending) {
          Future.microtask(() => engine.respondApproval(event.toolCallId, false));
        }
      });

      await engine.startTask('Write secret.txt');
      await sub.cancel();

      expect(events.whereType<ToolCallEvent>().any((tc) => tc.status == ToolCallStatus.rejected), isTrue);
      expect(File(p.join(workspace.workspaceDir.path, 'secret.txt')).existsSync(), isFalse);
    });

    test('interrupt and resetSession clear active state and histories', () async {
      final engine = BuiltinAgentEngine(
        keyVault,
        workspace,
      );

      await engine.interrupt();
      expect(engine.currentState, equals(AgentState.idle));

      engine.resetSession();
      expect(engine.openaiHistory, isEmpty);
      expect(engine.anthropicHistory, isEmpty);

      await engine.dispose();
    });
  });
}
