import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/settings/engine_settings_screen.dart';
import 'package:agentsdroid/ui/settings/language_settings_screen.dart';
import 'package:agentsdroid/ui/settings/model_settings_screen.dart';
import 'package:agentsdroid/ui/settings/safety_settings_screen.dart';
import 'package:agentsdroid/ui/settings/settings_screen.dart';
import 'package:agentsdroid/ui/settings/subsystem_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late KeyVault keyVault;
  late PRootManager prootManager;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);
    prootManager = PRootManager();
  });

  group('KeyVault Multi-Provider and Multi-Model Tests', () {
    test('Default providers are correctly initialized', () {
      final providers = keyVault.getProviders();
      expect(providers.length, equals(4));

      final deepseek = providers.firstWhere((p) => p.id == 'deepseek');
      expect(deepseek.name, equals('DeepSeek'));
      expect(deepseek.baseUrl, equals('https://api.deepseek.com'));
      expect(deepseek.models.length, equals(2));
      expect(deepseek.models.any((m) => m.id == 'deepseek-chat'), isTrue);
      expect(deepseek.models.any((m) => m.id == 'deepseek-reasoner' && m.supportsThinking), isTrue);

      final openai = providers.firstWhere((p) => p.id == 'openai');
      expect(openai.models.any((m) => m.id == 'gpt-4o'), isTrue);
      expect(openai.models.any((m) => m.id == 'o3-mini' && m.supportsThinking), isTrue);

      final anthropic = providers.firstWhere((p) => p.id == 'anthropic');
      expect(anthropic.models.any((m) => m.id == 'claude-3-7-sonnet-20250219' && m.supportsThinking), isTrue);

      final gemini = providers.firstWhere((p) => p.id == 'gemini');
      expect(gemini.models.any((m) => m.id == 'gemini-2.5-flash'), isTrue);
    });

    test('Add custom provider and save API key', () async {
      const customProvider = ModelProviderConfig(
        id: 'custom_siliconflow',
        name: 'SiliconFlow',
        baseUrl: 'https://api.siliconflow.cn/v1',
        apiType: 'openai',
        models: [
          ModelConfig(id: 'deepseek-ai/DeepSeek-V3', name: 'DeepSeek V3'),
          ModelConfig(id: 'deepseek-ai/DeepSeek-R1', name: 'DeepSeek R1', supportsThinking: true),
        ],
        isCustom: true,
      );

      await keyVault.addOrUpdateProvider(customProvider);
      await keyVault.setApiKeyForProvider('custom_siliconflow', 'sk-silicon-12345');

      final providers = keyVault.getProviders();
      expect(providers.length, equals(5));

      final retrieved = keyVault.getProvider('custom_siliconflow');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('SiliconFlow'));
      expect(retrieved.models.length, equals(2));

      final key = await keyVault.getApiKeyForProvider('custom_siliconflow');
      expect(key, equals('sk-silicon-12345'));
    });

    test('Add and remove model from existing provider', () async {
      final initialDeepseek = keyVault.getProvider('deepseek')!;
      expect(initialDeepseek.models.length, equals(2));

      const newModel = ModelConfig(
        id: 'deepseek-coder',
        name: 'DeepSeek Coder V2',
        supportsThinking: false,
      );

      await keyVault.addModelToProvider('deepseek', newModel);

      final updatedDeepseek = keyVault.getProvider('deepseek')!;
      expect(updatedDeepseek.models.length, equals(3));
      expect(updatedDeepseek.models.any((m) => m.id == 'deepseek-coder'), isTrue);

      // Now remove the model
      await keyVault.removeModelFromProvider('deepseek', 'deepseek-coder');
      final afterRemoval = keyVault.getProvider('deepseek')!;
      expect(afterRemoval.models.length, equals(2));
      expect(afterRemoval.models.any((m) => m.id == 'deepseek-coder'), isFalse);
    });

    test('Delete custom provider and cleanup key', () async {
      const customProvider = ModelProviderConfig(
        id: 'custom_ollama',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434/v1',
        models: [
          ModelConfig(id: 'qwen2.5-coder:7b', name: 'Qwen 2.5 Coder 7B'),
        ],
        isCustom: true,
      );

      await keyVault.addOrUpdateProvider(customProvider);
      await keyVault.setApiKeyForProvider('custom_ollama', 'ollama-key');
      expect(keyVault.getProvider('custom_ollama'), isNotNull);

      await keyVault.deleteProvider('custom_ollama');
      expect(keyVault.getProvider('custom_ollama'), isNull);
      final key = await keyVault.getApiKeyForProvider('custom_ollama');
      expect(key, isNull);
    });

    test('Active provider and active model switching persists correctly', () async {
      expect(keyVault.getActiveProviderId(), equals('deepseek'));
      expect(keyVault.getActiveModel(), equals('deepseek-chat'));

      await keyVault.setActiveProviderId('anthropic');
      await keyVault.setActiveModel('claude-3-7-sonnet-20250219');

      expect(keyVault.getActiveProviderId(), equals('anthropic'));
      expect(keyVault.getActiveProvider(), equals(LLMProvider.anthropic));
      expect(keyVault.getActiveModel(), equals('claude-3-7-sonnet-20250219'));
    });
  });

  group('SettingsScreen Modular Navigation Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );
    }

    testWidgets('SettingsScreen displays 5 horizontal summary cards and no detailed forms', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 5 summary cards are present
      expect(find.byType(Card), findsNWidgets(5));
      expect(find.text('模型与服务商'), findsOneWidget);
      expect(find.text('Agent 引擎'), findsOneWidget);
      expect(find.text('执行安全策略'), findsOneWidget);
      expect(find.text('界面语言'), findsOneWidget);
      expect(find.text('嵌入式 Linux 子系统 (PRoot)'), findsOneWidget);

      // Verify no detailed input fields on the main screen
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);
    });

    testWidgets('Tapping Models card navigates to ModelSettingsScreen', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('模型与服务商'));
      await tester.pumpAndSettle();

      // Now inside ModelSettingsScreen
      expect(find.byType(ModelSettingsScreen), findsOneWidget);
      expect(find.text('当前生效模型'), findsOneWidget);
      expect(find.text('已配置的服务商'), findsOneWidget);
      expect(find.text('DeepSeek'), findsWidgets);
      expect(find.text('OpenAI'), findsWidgets);
    });

    testWidgets('ModelSettingsScreen allows switching active model', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ModelSettingsScreen(keyVault: keyVault),
        ),
      );
      await tester.pumpAndSettle();

      expect(keyVault.getActiveModel(), equals('deepseek-chat'));

      // Tap on deepseek-reasoner
      await tester.tap(find.text('DeepSeek Reasoner (R1)'));
      await tester.pumpAndSettle();

      expect(keyVault.getActiveModel(), equals('deepseek-reasoner'));
    });

    testWidgets('Tapping Engine card navigates to EngineSettingsScreen and allows switching', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agent 引擎'));
      await tester.pumpAndSettle();

      expect(find.byType(EngineSettingsScreen), findsOneWidget);
      expect(find.text('内置轻量 Agent'), findsOneWidget);
      expect(find.text('官方 Claude Code CLI'), findsOneWidget);

      await tester.tap(find.text('官方 Claude Code CLI'));
      await tester.pumpAndSettle();

      expect(keyVault.getSelectedEngine(), equals('claudeCode'));
    });

    testWidgets('Tapping Safety card navigates to SafetySettingsScreen and allows changing mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('执行安全策略'));
      await tester.pumpAndSettle();

      expect(find.byType(SafetySettingsScreen), findsOneWidget);
      expect(find.text('帮我批准'), findsOneWidget);
      expect(find.text('完全访问权限'), findsOneWidget);

      await tester.tap(find.text('完全访问权限'));
      await tester.pumpAndSettle();

      expect(keyVault.getApprovalMode(), equals(ApprovalMode.yolo));
    });

    testWidgets('Tapping Language card navigates to LanguageSettingsScreen', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('界面语言'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('Tapping Subsystem card navigates to SubsystemSettingsScreen', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('嵌入式 Linux 子系统 (PRoot)'));
      await tester.pumpAndSettle();

      expect(find.byType(SubsystemSettingsScreen), findsOneWidget);
      expect(find.text('未安装'), findsOneWidget);
      expect(find.text('下载并安装子系统'), findsOneWidget);
    });
  });
}
