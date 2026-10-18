import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/builtin/builtin_agent_engine.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/ui/chat/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late KeyVault keyVault;
  late WorkspaceService workspace;
  late PRootManager prootManager;
  late SessionService sessionService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);

    tempDir = await Directory.systemTemp.createTemp('bottom_bar_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    prootManager = PRootManager();
    sessionService = SessionService();
    await sessionService.init(baseDir: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ApprovalMode & ThinkingIntensity in KeyVault', () {
    test('ApprovalMode defaults to autoApprove and persists properly', () async {
      expect(keyVault.getApprovalMode(), equals(ApprovalMode.autoApprove));
      expect(keyVault.isYoloMode(), isFalse);

      await keyVault.setApprovalMode(ApprovalMode.alwaysAsk);
      expect(keyVault.getApprovalMode(), equals(ApprovalMode.alwaysAsk));
      expect(keyVault.isYoloMode(), isFalse);

      await keyVault.setApprovalMode(ApprovalMode.yolo);
      expect(keyVault.getApprovalMode(), equals(ApprovalMode.yolo));
      expect(keyVault.isYoloMode(), isTrue);

      // setYoloMode backwards compatibility
      await keyVault.setYoloMode(false);
      expect(keyVault.getApprovalMode(), equals(ApprovalMode.autoApprove));
      expect(keyVault.isYoloMode(), isFalse);

      await keyVault.setYoloMode(true);
      expect(keyVault.getApprovalMode(), equals(ApprovalMode.yolo));
      expect(keyVault.isYoloMode(), isTrue);
    });

    test('ThinkingIntensity defaults to high and persists properly', () async {
      expect(keyVault.getThinkingIntensity(), equals(ThinkingIntensity.high));

      for (final intensity in ThinkingIntensity.values) {
        await keyVault.setThinkingIntensity(intensity);
        expect(keyVault.getThinkingIntensity(), equals(intensity));
      }
    });
  });

  group('BuiltinAgentEngine Approval Execution', () {
    test('ApprovalMode.alwaysAsk requires approval even for read_file', () async {
      await keyVault.setApprovalMode(ApprovalMode.alwaysAsk);
      final engine = BuiltinAgentEngine(keyVault, workspace);

      await workspace.writeFile('test.txt', 'hello');

      final events = <AgentEvent>[];
      engine.eventStream.listen(events.add);

      // Trigger read_file approval check
      bool completed = false;
      engine.handleToolExecutionForTesting(
        callId: 'call_read_1',
        toolName: 'read_file',
        arguments: {'path': 'test.txt'},
        onResult: (_) => completed = true,
      );

      // Allow event dispatch
      await Future.delayed(const Duration(milliseconds: 50));

      final pendingEvent = events.whereType<ToolCallEvent>().firstWhere(
            (e) => e.toolCallId == 'call_read_1',
          );
      expect(pendingEvent.status, equals(ToolCallStatus.pending));
      expect(pendingEvent.autoApproved, isFalse);
      expect(completed, isFalse);

      // Now approve it
      engine.respondApproval('call_read_1', true);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(completed, isTrue);

      engine.dispose();
    });

    test('ApprovalMode.autoApprove auto-approves read_file but asks for write_file', () async {
      await keyVault.setApprovalMode(ApprovalMode.autoApprove);
      final engine = BuiltinAgentEngine(keyVault, workspace);

      await workspace.writeFile('test.txt', 'hello');

      final events = <AgentEvent>[];
      engine.eventStream.listen(events.add);

      // 1. read_file should auto approve immediately
      bool readCompleted = false;
      await engine.handleToolExecutionForTesting(
        callId: 'call_read_2',
        toolName: 'read_file',
        arguments: {'path': 'test.txt'},
        onResult: (_) => readCompleted = true,
      );
      expect(readCompleted, isTrue);

      // 2. write_file should require approval
      bool writeCompleted = false;
      engine.handleToolExecutionForTesting(
        callId: 'call_write_1',
        toolName: 'write_file',
        arguments: {'path': 'test2.txt', 'content': 'world'},
        onResult: (_) => writeCompleted = true,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      final writeEvent = events.whereType<ToolCallEvent>().firstWhere(
            (e) => e.toolCallId == 'call_write_1',
          );
      expect(writeEvent.status, equals(ToolCallStatus.pending));
      expect(writeCompleted, isFalse);

      engine.respondApproval('call_write_1', true);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(writeCompleted, isTrue);

      engine.dispose();
    });

    test('ApprovalMode.yolo auto-approves all operations without asking', () async {
      await keyVault.setApprovalMode(ApprovalMode.yolo);
      final engine = BuiltinAgentEngine(keyVault, workspace);

      bool writeCompleted = false;
      await engine.handleToolExecutionForTesting(
        callId: 'call_write_yolo',
        toolName: 'write_file',
        arguments: {'path': 'yolo.txt', 'content': 'speed'},
        onResult: (_) => writeCompleted = true,
      );
      expect(writeCompleted, isTrue);

      final content = await workspace.readFile('yolo.txt');
      expect(content, equals('speed'));

      engine.dispose();
    });
  });

  group('ChatScreen Bottom Input Bar Widget Tests', () {
    testWidgets('renders capsule input bar with attachment, approval pill, model thinking pill and send button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            prootManager: prootManager,
            sessionService: sessionService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Multiline text field with hint
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('问问任何问题或提需求...'), findsOneWidget);

      // 2. Attachment '+' button
      expect(find.byIcon(Icons.add), findsWidgets);

      // 3. Approval mode pill (default: 帮我批准)
      expect(find.text('帮我批准'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // 4. Model & Thinking pill
      expect(find.textContaining('思考 · 高'), findsOneWidget);

      // 5. Send circular button
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Test tapping Approval pill opens modal sheet
      await tester.tap(find.text('帮我批准'));
      await tester.pumpAndSettle();

      expect(find.text('应如何批准 Agent 操作？'), findsOneWidget);
      expect(find.text('请求批准'), findsOneWidget);
      expect(find.text('帮我批准'), findsWidgets);
      expect(find.text('完全访问权限'), findsOneWidget);

      // Switch to '请求批准'
      await tester.tap(find.text('请求批准'));
      await tester.pumpAndSettle();

      expect(keyVault.getApprovalMode(), equals(ApprovalMode.alwaysAsk));
      expect(find.text('请求批准'), findsOneWidget);
      expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);

      // Test tapping Model & Thinking pill opens intensity sheet
      await tester.tap(find.textContaining('思考 · 高'));
      await tester.pumpAndSettle();

      expect(find.text('思考：高'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Close modal
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });
  });
}
