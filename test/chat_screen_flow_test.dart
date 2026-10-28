import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/providers/app_providers.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/ui/chat/chat_screen.dart';

Widget buildTestApp({
  required Widget child,
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late KeyVault keyVault;
  late WorkspaceService workspace;
  late PRootManager prootManager;
  late SessionService sessionService;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    keyVault = KeyVault(const FlutterSecureStorage(), prefs);

    tempDir = await Directory.systemTemp.createTemp('chat_flow_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    prootManager = PRootManager();
    await prootManager.init(appSupportDir: tempDir, workspacePath: workspace.workspacePath);

    sessionService = SessionService();
    await sessionService.init(baseDir: tempDir);

    const initialProvider = ModelProviderConfig(
      id: 'mock_provider',
      name: 'Mock Provider',
      baseUrl: 'https://api.mock.com',
      models: [
        ModelConfig(id: 'mock-model', name: 'Mock Model'),
      ],
    );
    await keyVault.addOrUpdateProvider(initialProvider);
    await keyVault.setActiveProviderId('mock_provider');
    await keyVault.setActiveModel('mock-model');
    await keyVault.setApiKeyForProvider('mock_provider', 'sk-mock-key');

    container = ProviderContainer(
      overrides: [
        keyVaultProvider.overrideWithValue(keyVault),
        workspaceServiceProvider.overrideWithValue(workspace),
        sessionServiceProvider.overrideWithValue(sessionService),
        prootManagerProvider.overrideWithValue(prootManager),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ChatScreen Interactive Flow Tests', () {
    testWidgets('renders existing messages with thought card, tool card, and text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      // Pre-create session with messages
      final session = await sessionService.createSession(title: 'Flow Session');
      session.messages.add(
        ChatMessage(
          id: 'user_1',
          role: MessageRole.user,
          content: 'Please create test.txt',
        ),
      );
      session.messages.add(
        ChatMessage(
          id: 'assistant_1',
          role: MessageRole.assistant,
          thought: 'I will write test.txt using write_file',
          toolCalls: [
            ToolCallEvent(
              toolCallId: 'tc_101',
              toolName: 'write_file',
              arguments: {'path': 'test.txt', 'content': 'Hello'},
              status: ToolCallStatus.pending,
            ),
          ],
          content: 'Done!',
        ),
      );
      await sessionService.saveSession(session);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
            initialSessionId: session.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Please create test.txt'), findsOneWidget);
      expect(find.text('Done!'), findsOneWidget);
      expect(find.text('write_file'), findsOneWidget);

      // Tap approval pill to open approval mode sheet
      await tester.tap(find.text('帮我批准'));
      await tester.pumpAndSettle();

      expect(find.text('应如何批准 Agent 操作？'), findsOneWidget);
      expect(find.text('请求批准'), findsOneWidget);

      // Select '请求批准'
      await tester.tap(find.text('请求批准'));
      await tester.pumpAndSettle();

      expect(keyVault.getApprovalMode(), equals(ApprovalMode.alwaysAsk));
    });

    testWidgets('tapping thinking pill opens thinking intensity bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await keyVault.setThinkingIntensity(ThinkingIntensity.low);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap thinking pill
      await tester.tap(find.textContaining('Mock Model'));
      await tester.pumpAndSettle();

      expect(find.textContaining('思考：'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Tap reset button
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(keyVault.getThinkingIntensity(), equals(ThinkingIntensity.high));
    });

    testWidgets('tapping attachment button opens attachment menu bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap attachment button (Icons.add)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('添加上下文'), findsOneWidget);
      expect(find.text('引用项目文件 (@file)'), findsOneWidget);
      expect(find.text('粘贴剪贴板内容'), findsOneWidget);
    });

    testWidgets('tapping model chip in thinking sheet opens model picker sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap thinking pill
      await tester.tap(find.textContaining('Mock Model'));
      await tester.pumpAndSettle();

      // Tap model switcher chip inside the sheet
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('切换模型'), findsOneWidget);
      expect(find.text('模型与服务商'), findsOneWidget);
      expect(find.text('Mock Model'), findsWidgets);
    });

    testWidgets('entering text and tapping send creates user message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello AgentsDroid');
      await tester.pumpAndSettle();

      // Tap Send button (arrow_upward_rounded)
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // User message should now be rendered (both in bubble and session title)
      expect(find.text('Hello AgentsDroid'), findsWidgets);
    });

    testWidgets('approving tool call card triggers engine approval response', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      final session = await sessionService.createSession(title: 'Tool Session');
      session.messages.add(
        ChatMessage(
          id: 'user_1',
          role: MessageRole.user,
          content: 'Run a tool',
        ),
      );
      session.messages.add(
        ChatMessage(
          id: 'assistant_1',
          role: MessageRole.assistant,
          toolCalls: [
            ToolCallEvent(
              toolCallId: 'tc_999',
              toolName: 'execute_command',
              arguments: {'command': 'ls -la'},
              status: ToolCallStatus.pending,
            ),
          ],
        ),
      );
      await sessionService.saveSession(session);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            sessionService: sessionService,
            prootManager: prootManager,
            initialSessionId: session.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('execute_command'), findsOneWidget);
      expect(find.text('待审批'), findsOneWidget);

      // Tap card to expand it
      await tester.tap(find.text('execute_command'));
      await tester.pumpAndSettle();

      // Find '允许' button on the expanded tool card
      expect(find.text('允许'), findsOneWidget);
      await tester.tap(find.text('允许'));
      await tester.pumpAndSettle();
    });
  });
}
