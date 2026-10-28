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

    tempDir = await Directory.systemTemp.createTemp('chat_riverpod_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    prootManager = PRootManager();
    sessionService = SessionService();
    await sessionService.init(baseDir: tempDir);

    const initialProvider = ModelProviderConfig(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      models: [
        ModelConfig(id: 'deepseek-chat', name: 'DeepSeek V3'),
      ],
    );
    await keyVault.addOrUpdateProvider(initialProvider);
    await keyVault.setActiveProviderId('deepseek');
    await keyVault.setActiveModel('deepseek-chat');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('ChatScreen reacts to Riverpod provider updates', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        keyVaultProvider.overrideWithValue(keyVault),
        workspaceServiceProvider.overrideWithValue(workspace),
        sessionServiceProvider.overrideWithValue(sessionService),
        prootManagerProvider.overrideWithValue(prootManager),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('zh'), Locale('en')],
          locale: Locale('zh'),
          home: ChatScreen(), // constructed with no arguments, pulling from ProviderScope
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial values from keyVault (pill displays '<Model> <Thinking>')
    expect(find.textContaining('DeepSeek V3'), findsOneWidget);
    expect(find.textContaining('high'), findsOneWidget);
    expect(find.text('帮我批准'), findsOneWidget);

    // Update approvalMode via Riverpod
    container.read(approvalModeProvider.notifier).setApprovalMode(ApprovalMode.yolo);
    await tester.pumpAndSettle();
    expect(find.text('完全访问权限'), findsOneWidget);

    // Update thinkingIntensity via Riverpod
    container.read(thinkingIntensityProvider.notifier).setThinkingIntensity(ThinkingIntensity.low);
    await tester.pumpAndSettle();
    expect(find.textContaining('low'), findsOneWidget);

    // Update activeModel via Riverpod
    const altModel = ModelConfig(id: 'gpt-4o', name: 'GPT-4o');
    const newProvider = ModelProviderConfig(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com',
      models: [altModel],
    );
    await keyVault.addOrUpdateProvider(newProvider);
    container.read(activeModelProvider.notifier).setActiveModel('gpt-4o');
    await tester.pumpAndSettle();
    expect(find.textContaining('GPT-4o'), findsOneWidget);
  });
}
