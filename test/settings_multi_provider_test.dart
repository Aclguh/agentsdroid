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
import 'package:agentsdroid/ui/settings/screen_rotation_settings_screen.dart';
import 'package:agentsdroid/ui/settings/settings_screen.dart';
import 'package:agentsdroid/ui/settings/subsystem_settings_screen.dart';
import 'package:agentsdroid/ui/settings/theme_settings_screen.dart';

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
    test('Default providers are empty by default (zero built-in)', () {
      final providers = keyVault.getProviders();
      expect(providers, isEmpty);
      expect(keyVault.getActiveProviderId(), isEmpty);
      expect(keyVault.getActiveModel(), isEmpty);
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
      expect(providers.length, equals(1));

      final retrieved = keyVault.getProvider('custom_siliconflow');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('SiliconFlow'));
      expect(retrieved.models.length, equals(2));

      final key = await keyVault.getApiKeyForProvider('custom_siliconflow');
      expect(key, equals('sk-silicon-12345'));
    });

    test('Add and remove model from existing provider, including the last model', () async {
      const provider = ModelProviderConfig(
        id: 'test_provider',
        name: 'Test Provider',
        baseUrl: 'https://api.test.com',
        models: [
          ModelConfig(id: 'model-a', name: 'Model A'),
        ],
      );

      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('test_provider');
      await keyVault.setActiveModel('model-a');

      expect(keyVault.getProvider('test_provider')!.models.length, equals(1));
      expect(keyVault.getActiveModel(), equals('model-a'));

      // Add second model
      const newModel = ModelConfig(
        id: 'model-b',
        name: 'Model B',
        supportsThinking: false,
      );
      await keyVault.addModelToProvider('test_provider', newModel);
      expect(keyVault.getProvider('test_provider')!.models.length, equals(2));

      // Remove model-a
      await keyVault.removeModelFromProvider('test_provider', 'model-a');
      final afterFirst = keyVault.getProvider('test_provider')!;
      expect(afterFirst.models.length, equals(1));
      expect(afterFirst.models.first.id, equals('model-b'));
      expect(keyVault.getActiveModel(), equals('model-b'));

      // Now remove the very last model (model-b)
      await keyVault.removeModelFromProvider('test_provider', 'model-b');
      final afterLast = keyVault.getProvider('test_provider')!;
      expect(afterLast.models, isEmpty);
      expect(keyVault.getActiveModel(), isEmpty);
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
      const provider = ModelProviderConfig(
        id: 'anthropic',
        name: 'Anthropic',
        baseUrl: 'https://api.anthropic.com',
        models: [
          ModelConfig(id: 'claude-3-7-sonnet-20250219', name: 'Claude 3.7 Sonnet'),
        ],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('anthropic');
      await keyVault.setActiveModel('claude-3-7-sonnet-20250219');

      expect(keyVault.getActiveProviderId(), equals('anthropic'));
      expect(keyVault.getActiveProvider(), equals(LLMProvider.anthropic));
      expect(keyVault.getActiveModel(), equals('claude-3-7-sonnet-20250219'));
    });

    test('ThemeMode defaults to dark and can be updated', () async {
      expect(keyVault.getThemeMode(), equals(ThemeMode.dark));
      await keyVault.setThemeMode(ThemeMode.light);
      expect(keyVault.getThemeMode(), equals(ThemeMode.light));
      await keyVault.setThemeMode(ThemeMode.system);
      expect(keyVault.getThemeMode(), equals(ThemeMode.system));
    });

    test('AutoRotate defaults to false and can be updated', () async {
      expect(keyVault.isAutoRotateEnabled(), isFalse);
      await keyVault.setAutoRotateEnabled(true);
      expect(keyVault.isAutoRotateEnabled(), isTrue);
      await keyVault.setAutoRotateEnabled(false);
      expect(keyVault.isAutoRotateEnabled(), isFalse);
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

    testWidgets('SettingsScreen displays 8 horizontal summary cards and no detailed forms', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 8 summary cards are present
      expect(find.byType(Card), findsNWidgets(8));
      expect(find.text('模型与服务商'), findsOneWidget);
      expect(find.text('Agent 引擎'), findsOneWidget);
      expect(find.text('执行安全策略'), findsOneWidget);
      expect(find.text('外观主题'), findsOneWidget);
      expect(find.text('屏幕旋转'), findsOneWidget);
      expect(find.text('界面语言'), findsOneWidget);
      expect(find.text('嵌入式 Linux 子系统 (PRoot)'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);

      // Verify no detailed input fields on the main screen
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);

      // Verify no icons on summary cards (user requested no icons)
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.bolt_outlined), findsNothing);
      expect(find.byIcon(Icons.security_outlined), findsNothing);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.screen_rotation_outlined), findsNothing);
      expect(find.byIcon(Icons.translate_outlined), findsNothing);
      expect(find.byIcon(Icons.terminal_outlined), findsNothing);
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

      // Now inside ModelSettingsScreen with zero built-in providers
      expect(find.byType(ModelSettingsScreen), findsOneWidget);
      expect(find.text('当前生效模型'), findsOneWidget);
      expect(find.text('未配置模型'), findsOneWidget);
      expect(find.text('已配置的服务商'), findsOneWidget);
      expect(find.text('暂无已配置的服务商'), findsOneWidget);
    });

    testWidgets('ModelSettingsScreen allows switching active model and deleting last model', (tester) async {
      const provider = ModelProviderConfig(
        id: 'my_provider',
        name: 'My AI',
        baseUrl: 'https://api.myai.com',
        models: [
          ModelConfig(id: 'model-1', name: 'Model 1'),
          ModelConfig(id: 'model-2', name: 'Model 2'),
        ],
      );
      await keyVault.addOrUpdateProvider(provider);
      await keyVault.setActiveProviderId('my_provider');
      await keyVault.setActiveModel('model-1');

      await tester.pumpWidget(
        buildTestApp(
          ModelSettingsScreen(keyVault: keyVault),
        ),
      );
      await tester.pumpAndSettle();

      expect(keyVault.getActiveModel(), equals('model-1'));

      // Tap on model-2 to activate
      await tester.tap(find.text('Model 2'));
      await tester.pumpAndSettle();

      expect(keyVault.getActiveModel(), equals('model-2'));

      // Verify delete buttons exist for each model
      expect(find.byIcon(Icons.close), findsNWidgets(2));
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
      expect(find.text('Recommended'), findsNothing);

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

    testWidgets('Tapping Theme card navigates to ThemeSettingsScreen and allows switching theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('外观主题'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeSettingsScreen), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色模式'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);

      await tester.tap(find.text('浅色模式'));
      await tester.pumpAndSettle();

      expect(keyVault.getThemeMode(), equals(ThemeMode.light));
    });

    testWidgets('Tapping Screen Rotation card navigates to ScreenRotationSettingsScreen and allows switching', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            keyVault: keyVault,
            prootManager: prootManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('屏幕旋转'));
      await tester.pumpAndSettle();

      expect(find.byType(ScreenRotationSettingsScreen), findsOneWidget);
      expect(find.text('随重力感应旋转'), findsOneWidget);
      expect(find.text('锁定竖屏'), findsOneWidget);

      await tester.tap(find.text('随重力感应旋转'));
      await tester.pumpAndSettle();

      expect(keyVault.isAutoRotateEnabled(), isTrue);

      await tester.tap(find.text('锁定竖屏'));
      await tester.pumpAndSettle();

      expect(keyVault.isAutoRotateEnabled(), isFalse);
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
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
