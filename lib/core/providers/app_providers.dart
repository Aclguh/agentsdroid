import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proot/proot_manager.dart';
import '../storage/key_vault.dart';
import '../storage/preferences_service.dart';
import '../storage/session_service.dart';
import '../storage/workspace_service.dart';

/// Core Service Providers (overridden in ProviderScope at app start)
final keyVaultProvider = Provider<KeyVault>((ref) {
  throw UnimplementedError('keyVaultProvider must be overridden');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final keyVault = ref.watch(keyVaultProvider);
  return keyVault.preferences;
});

final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  throw UnimplementedError('workspaceServiceProvider must be overridden');
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  throw UnimplementedError('sessionServiceProvider must be overridden');
});

final prootManagerProvider = Provider<PRootManager>((ref) {
  throw UnimplementedError('prootManagerProvider must be overridden');
});

/// Locale Notifier for reactive internationalization updates
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return Locale(prefs.getLanguage());
  }

  void setLocale(Locale newLocale) {
    state = newLocale;
    ref.read(preferencesServiceProvider).setLanguage(newLocale.languageCode);
  }
}

final appLocaleProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// ThemeMode Notifier for reactive dark/light/system theme updates
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.getThemeMode();
  }

  void setThemeMode(ThemeMode newThemeMode) {
    state = newThemeMode;
    ref.read(preferencesServiceProvider).setThemeMode(newThemeMode);
  }
}

final appThemeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Screen Orientation Notifier for reactive screen auto-rotation preference updates
class ScreenOrientationNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.isAutoRotateEnabled();
  }

  void setScreenOrientation(bool autoRotate) {
    state = autoRotate;
    ref.read(preferencesServiceProvider).setAutoRotateEnabled(autoRotate);
  }
}

final appAutoRotateProvider = NotifierProvider<ScreenOrientationNotifier, bool>(ScreenOrientationNotifier.new);

/// Active Model Provider for reactive model switching
class ActiveModelNotifier extends Notifier<String> {
  @override
  String build() {
    final keyVault = ref.watch(keyVaultProvider);
    return keyVault.getActiveModel();
  }

  void setActiveModel(String modelId) {
    state = modelId;
    ref.read(keyVaultProvider).setActiveModel(modelId);
  }
}

final activeModelProvider = NotifierProvider<ActiveModelNotifier, String>(ActiveModelNotifier.new);

/// Approval Mode Provider for reactive YOLO/alwaysAsk/autoApprove switching
class ApprovalModeNotifier extends Notifier<ApprovalMode> {
  @override
  ApprovalMode build() {
    final keyVault = ref.watch(keyVaultProvider);
    return keyVault.getApprovalMode();
  }

  void setApprovalMode(ApprovalMode mode) {
    state = mode;
    ref.read(keyVaultProvider).setApprovalMode(mode);
  }
}

final approvalModeProvider = NotifierProvider<ApprovalModeNotifier, ApprovalMode>(ApprovalModeNotifier.new);

/// Thinking Intensity Provider for reactive thinking depth switching
class ThinkingIntensityNotifier extends Notifier<ThinkingIntensity> {
  @override
  ThinkingIntensity build() {
    final keyVault = ref.watch(keyVaultProvider);
    return keyVault.getThinkingIntensity();
  }

  void setThinkingIntensity(ThinkingIntensity intensity) {
    state = intensity;
    ref.read(keyVaultProvider).setThinkingIntensity(intensity);
  }
}

final thinkingIntensityProvider = NotifierProvider<ThinkingIntensityNotifier, ThinkingIntensity>(ThinkingIntensityNotifier.new);
