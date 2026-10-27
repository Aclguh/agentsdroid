import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/providers/app_providers.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KeyVault keyVault;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pref_language': 'zh',
      'pref_theme_mode': 'dark',
      'pref_auto_rotate': true,
      'pref_active_model': 'gemini-2.5-flash',
      'pref_approval_mode': 'alwaysAsk',
      'pref_thinking_intensity': 'medium',
    });
    keyVault = await KeyVault.create();
  });

  test('app_providers initialize and reactively update values', () {
    final container = ProviderContainer(
      overrides: [
        keyVaultProvider.overrideWithValue(keyVault),
      ],
    );
    addTearDown(container.dispose);

    // Initial values
    expect(container.read(appLocaleProvider), const Locale('zh'));
    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(container.read(appAutoRotateProvider), true);
    expect(container.read(activeModelProvider), 'gemini-2.5-flash');
    expect(container.read(approvalModeProvider), ApprovalMode.alwaysAsk);
    expect(container.read(thinkingIntensityProvider), ThinkingIntensity.medium);

    // Update Locale
    container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    expect(container.read(appLocaleProvider), const Locale('en'));
    expect(keyVault.getLanguage(), 'en');

    // Update ThemeMode
    container.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(container.read(appThemeModeProvider), ThemeMode.light);
    expect(keyVault.getThemeMode(), ThemeMode.light);

    // Update Screen Orientation
    container.read(appAutoRotateProvider.notifier).setScreenOrientation(false);
    expect(container.read(appAutoRotateProvider), false);
    expect(keyVault.isAutoRotateEnabled(), false);

    // Update Active Model
    container.read(activeModelProvider.notifier).setActiveModel('claude-3-7-sonnet');
    expect(container.read(activeModelProvider), 'claude-3-7-sonnet');
    expect(keyVault.getActiveModel(), 'claude-3-7-sonnet');

    // Update Approval Mode
    container.read(approvalModeProvider.notifier).setApprovalMode(ApprovalMode.yolo);
    expect(container.read(approvalModeProvider), ApprovalMode.yolo);
    expect(keyVault.getApprovalMode(), ApprovalMode.yolo);

    // Update Thinking Intensity
    container.read(thinkingIntensityProvider.notifier).setThinkingIntensity(ThinkingIntensity.high);
    expect(container.read(thinkingIntensityProvider), ThinkingIntensity.high);
    expect(keyVault.getThinkingIntensity(), ThinkingIntensity.high);
  });
}
