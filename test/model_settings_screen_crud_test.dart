import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/settings/model_settings_screen.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('zh'),
      Locale('en'),
    ],
    locale: const Locale('zh'),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late KeyVault keyVault;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keyVault = KeyVault(const FlutterSecureStorage(), prefs);
  });

  group('ModelSettingsScreen Dialogs and CRUD Tests', () {
    testWidgets('Adds a new custom provider via _showAddProviderDialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(ModelSettingsScreen(keyVault: keyVault)));
      await tester.pumpAndSettle();

      // Tap + button in AppBar
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5)); // name, baseUrl, apiKey, modelId, modelName

      await tester.enterText(textFields.at(0), 'Ollama Local');
      await tester.enterText(textFields.at(1), 'http://127.0.0.1:11434/v1');
      await tester.enterText(textFields.at(2), 'ollama-key');
      await tester.enterText(textFields.at(3), 'llama3.2');
      await tester.enterText(textFields.at(4), 'Llama 3.2 3B');

      // Toggle supports thinking switch
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify provider was saved
      final providers = keyVault.getProviders();
      expect(providers, hasLength(1));
      expect(providers.first.name, equals('Ollama Local'));
      expect(providers.first.models.first.id, equals('llama3.2'));
      expect(providers.first.models.first.supportsThinking, isTrue);

      final key = await keyVault.getApiKeyForProvider(providers.first.id);
      expect(key, equals('ollama-key'));
    });

    testWidgets('Edits an existing provider via _showEditProviderDialog', (tester) async {
      const customProvider = ModelProviderConfig(
        id: 'provider_edit_test',
        name: 'Original Provider',
        baseUrl: 'https://api.original.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'model-a', name: 'Model A')],
        isCustom: true,
      );
      await keyVault.addOrUpdateProvider(customProvider);
      await keyVault.setApiKeyForProvider('provider_edit_test', 'orig-key');

      await tester.pumpWidget(buildTestApp(ModelSettingsScreen(keyVault: keyVault)));
      await tester.pumpAndSettle();

      // Tap edit provider button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('编辑服务商 - Original Provider'), findsOneWidget);

      // Change name and base URL
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Updated Provider');
      await tester.enterText(textFields.at(1), 'https://api.updated.com/v1');
      await tester.enterText(textFields.at(2), 'updated-key');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final updated = keyVault.getProvider('provider_edit_test')!;
      expect(updated.name, equals('Updated Provider'));
      expect(updated.baseUrl, equals('https://api.updated.com/v1'));
      expect(await keyVault.getApiKeyForProvider('provider_edit_test'), equals('updated-key'));
    });

    testWidgets('Adds a new model via _showAddModelDialog', (tester) async {
      const customProvider = ModelProviderConfig(
        id: 'provider_add_model',
        name: 'My Provider',
        baseUrl: 'https://api.test.com/v1',
        apiType: 'openai',
        models: [ModelConfig(id: 'm1', name: 'M1')],
        isCustom: true,
      );
      await keyVault.addOrUpdateProvider(customProvider);

      await tester.pumpWidget(buildTestApp(ModelSettingsScreen(keyVault: keyVault)));
      await tester.pumpAndSettle();

      // Tap "添加模型" button (chip or icon button)
      final addModelButton = find.text('添加模型');
      expect(addModelButton, findsOneWidget);
      await tester.tap(addModelButton);
      await tester.pumpAndSettle();

      expect(find.text('添加模型 (My Provider)'), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'm2-deepseek');
      await tester.enterText(textFields.at(1), 'DeepSeek V3');

      // Tap Add Model in dialog
      await tester.tap(find.widgetWithText(FilledButton, '添加模型'));
      await tester.pumpAndSettle();

      final updated = keyVault.getProvider('provider_add_model')!;
      expect(updated.models, hasLength(2));
      expect(updated.models.last.id, equals('m2-deepseek'));
      expect(updated.models.last.name, equals('DeepSeek V3'));
    });

    testWidgets('Deletes a model and deletes a provider with confirmation dialogs', (tester) async {
      const customProvider = ModelProviderConfig(
        id: 'provider_delete_test',
        name: 'Provider To Delete',
        baseUrl: 'https://api.delete.com/v1',
        apiType: 'openai',
        models: [
          ModelConfig(id: 'm_del_1', name: 'Model 1'),
          ModelConfig(id: 'm_del_2', name: 'Model 2'),
        ],
        isCustom: true,
      );
      await keyVault.addOrUpdateProvider(customProvider);

      await tester.pumpWidget(buildTestApp(ModelSettingsScreen(keyVault: keyVault)));
      await tester.pumpAndSettle();

      // Delete model 1
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsNWidgets(2));
      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      expect(find.text('删除模型'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      var current = keyVault.getProvider('provider_delete_test')!;
      expect(current.models, hasLength(1));
      expect(current.models.first.id, equals('m_del_2'));

      // Delete provider
      final deleteProviderIcon = find.byIcon(Icons.delete_outline);
      expect(deleteProviderIcon, findsOneWidget);
      await tester.tap(deleteProviderIcon);
      await tester.pumpAndSettle();

      expect(find.text('删除服务商'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(keyVault.getProvider('provider_delete_test'), isNull);
    });
  });
}
