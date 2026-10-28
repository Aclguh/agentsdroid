import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KeyVault keyVault;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);
  });

  group('KeyVault Environment Export Principle of Least Privilege (SEC-04)', () {
    test('exports only active provider key by default', () async {
      await keyVault.setApiKey(LLMProvider.anthropic, 'sk-ant-test');
      await keyVault.setApiKey(LLMProvider.openai, 'sk-openai-test');
      await keyVault.setApiKey(LLMProvider.deepseek, 'sk-deepseek-test');
      await keyVault.setApiKey(LLMProvider.gemini, 'sk-gemini-test');

      // Set active provider to Anthropic
      await keyVault.addOrUpdateProvider(
        ModelProviderConfig(
          id: LLMProvider.anthropic.name,
          name: LLMProvider.anthropic.displayName,
          baseUrl: 'https://api.anthropic.com/v1',
          models: [],
        ),
      );
      await keyVault.setActiveProvider(LLMProvider.anthropic);

      final env = await keyVault.exportEnvironmentVariables();

      expect(env['ANTHROPIC_API_KEY'], equals('sk-ant-test'));
      // Other keys must NOT be leaked
      expect(env.containsKey('OPENAI_API_KEY'), isFalse);
      expect(env.containsKey('DEEPSEEK_API_KEY'), isFalse);
      expect(env.containsKey('GEMINI_API_KEY'), isFalse);
    });

    test('exports deepseek key and compat baseUrl when active', () async {
      await keyVault.setApiKey(LLMProvider.anthropic, 'sk-ant-test');
      await keyVault.setApiKey(LLMProvider.deepseek, 'sk-deepseek-test');

      await keyVault.addOrUpdateProvider(
        ModelProviderConfig(
          id: LLMProvider.deepseek.name,
          name: LLMProvider.deepseek.displayName,
          baseUrl: 'https://api.deepseek.com',
          models: [],
        ),
      );
      await keyVault.setActiveProvider(LLMProvider.deepseek);

      final env = await keyVault.exportEnvironmentVariables();

      expect(env['DEEPSEEK_API_KEY'], equals('sk-deepseek-test'));
      expect(env['OPENAI_API_KEY'], equals('sk-deepseek-test'));
      expect(env.containsKey('ANTHROPIC_API_KEY'), isFalse);
    });

    test('exports all keys when onlyActiveProvider is false', () async {
      await keyVault.setApiKey(LLMProvider.anthropic, 'sk-ant-test');
      await keyVault.setApiKey(LLMProvider.openai, 'sk-openai-test');
      await keyVault.setApiKey(LLMProvider.deepseek, 'sk-deepseek-test');

      final env = await keyVault.exportEnvironmentVariables(onlyActiveProvider: false);

      expect(env['ANTHROPIC_API_KEY'], equals('sk-ant-test'));
      expect(env['OPENAI_API_KEY'], equals('sk-openai-test'));
      expect(env['DEEPSEEK_API_KEY'], equals('sk-deepseek-test'));
    });

    test('returns empty map when no active provider or key configured', () async {
      final env = await keyVault.exportEnvironmentVariables();
      expect(env, isEmpty);
    });
  });
}
