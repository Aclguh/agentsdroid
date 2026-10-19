import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelConfig {
  final String id;
  final String name;
  final bool supportsThinking;

  const ModelConfig({
    required this.id,
    required this.name,
    this.supportsThinking = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'supportsThinking': supportsThinking,
  };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    supportsThinking: json['supportsThinking'] as bool? ?? false,
  );
}

class ModelProviderConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiType; // 'openai' or 'anthropic'
  final List<ModelConfig> models;
  final bool isCustom;

  const ModelProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiType = 'openai',
    required this.models,
    this.isCustom = false,
  });

  ModelProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiType,
    List<ModelConfig>? models,
    bool? isCustom,
  }) {
    return ModelProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiType: apiType ?? this.apiType,
      models: models ?? this.models,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'apiType': apiType,
    'models': models.map((m) => m.toJson()).toList(),
    'isCustom': isCustom,
  };

  factory ModelProviderConfig.fromJson(Map<String, dynamic> json) => ModelProviderConfig(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    baseUrl: json['baseUrl'] as String? ?? '',
    apiType: json['apiType'] as String? ?? 'openai',
    models: (json['models'] as List<dynamic>?)
            ?.map((m) => ModelConfig.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    isCustom: json['isCustom'] as bool? ?? false,
  );
}

enum LLMProvider {
  anthropic('Anthropic Claude', 'claude-3-7-sonnet-20250219'),
  deepseek('DeepSeek', 'deepseek-chat'),
  openai('OpenAI', 'gpt-4o'),
  gemini('Google Gemini', 'gemini-2.5-flash'),
  custom('Custom (OpenAI-compatible)', 'default');

  final String displayName;
  final String defaultModel;
  const LLMProvider(this.displayName, this.defaultModel);
}

enum ApprovalMode {
  alwaysAsk,
  autoApprove,
  yolo,
}

enum ThinkingIntensity {
  off(0),
  low(1),
  medium(2),
  high(3),
  veryHigh(4);

  final int level;
  const ThinkingIntensity(this.level);
}

class KeyVault {
  static const _anthropicKey = 'key_anthropic';
  static const _openaiKey = 'key_openai';
  static const _deepseekKey = 'key_deepseek';
  static const _geminiKey = 'key_gemini';
  static const _customKey = 'key_custom';

  static const _prefActiveProvider = 'pref_active_provider';
  static const _prefActiveModel = 'pref_active_model';
  static const _prefCustomBaseUrl = 'pref_custom_base_url';
  static const _prefDeepseekBaseUrl = 'pref_deepseek_base_url';
  static const _prefYoloMode = 'pref_yolo_mode';
  static const _prefApprovalMode = 'pref_approval_mode';
  static const _prefThinkingIntensity = 'pref_thinking_intensity';
  static const _prefLanguage = 'pref_language';
  static const _prefSelectedEngine = 'pref_selected_engine';
  static const _prefProvidersConfigJson = 'pref_providers_config_json';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  KeyVault(this._secureStorage, this._prefs);

  static Future<KeyVault> create() async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
    );
    final prefs = await SharedPreferences.getInstance();
    return KeyVault(secureStorage, prefs);
  }

  // --- Predefined Default Providers ---
  static List<ModelProviderConfig> getDefaultProviders() {
    return const [];
  }

  // --- Provider Management ---
  List<ModelProviderConfig> getProviders() {
    final raw = _prefs.getString(_prefProvidersConfigJson);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((item) => ModelProviderConfig.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return List<ModelProviderConfig>.from(getDefaultProviders());
  }

  Future<void> saveProviders(List<ModelProviderConfig> providers) async {
    final jsonStr = jsonEncode(providers.map((p) => p.toJson()).toList());
    await _prefs.setString(_prefProvidersConfigJson, jsonStr);
  }

  ModelProviderConfig? getProvider(String providerId) {
    if (providerId.isEmpty) return null;
    final providers = getProviders();
    try {
      return providers.firstWhere((p) => p.id == providerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addOrUpdateProvider(ModelProviderConfig provider) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      providers[index] = provider;
    } else {
      providers.add(provider);
    }
    await saveProviders(providers);
  }

  Future<void> deleteProvider(String providerId) async {
    final providers = getProviders();
    providers.removeWhere((p) => p.id == providerId);
    await saveProviders(providers);
    await deleteApiKeyForProvider(providerId);

    if (getActiveProviderId() == providerId) {
      if (providers.isNotEmpty) {
        await setActiveProviderId(providers.first.id);
        if (providers.first.models.isNotEmpty) {
          await setActiveModel(providers.first.models.first.id);
        } else {
          await setActiveModel('');
        }
      } else {
        await setActiveProviderId('');
        await setActiveModel('');
      }
    }
  }

  Future<void> addModelToProvider(String providerId, ModelConfig model) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      final existing = providers[index];
      final models = List<ModelConfig>.from(existing.models);
      final mIndex = models.indexWhere((m) => m.id == model.id);
      if (mIndex >= 0) {
        models[mIndex] = model;
      } else {
        models.add(model);
      }
      providers[index] = existing.copyWith(models: models);
      await saveProviders(providers);
    }
  }

  Future<void> removeModelFromProvider(String providerId, String modelId) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      final existing = providers[index];
      final models = List<ModelConfig>.from(existing.models);
      models.removeWhere((m) => m.id == modelId);
      providers[index] = existing.copyWith(models: models);
      await saveProviders(providers);

      if (getActiveModel() == modelId) {
        if (models.isNotEmpty) {
          await setActiveModel(models.first.id);
        } else {
          await setActiveModel('');
        }
      }
    }
  }

  ModelConfig? getModel(String modelId) {
    if (modelId.isEmpty) return null;
    for (final p in getProviders()) {
      for (final m in p.models) {
        if (m.id == modelId) return m;
      }
    }
    return null;
  }

  // --- API Keys ---
  Future<void> setApiKeyForProvider(String providerId, String key) async {
    final storageKey = 'key_provider_$providerId';
    if (key.trim().isEmpty) {
      await _secureStorage.delete(key: storageKey);
    } else {
      await _secureStorage.write(key: storageKey, value: key.trim());
    }

    // Maintain backward compatibility for built-in enum keys
    try {
      final enumVal = LLMProvider.values.firstWhere((e) => e.name == providerId);
      final legacyKey = _getStorageKey(enumVal);
      if (key.trim().isEmpty) {
        await _secureStorage.delete(key: legacyKey);
      } else {
        await _secureStorage.write(key: legacyKey, value: key.trim());
      }
    } catch (_) {}
  }

  Future<String?> getApiKeyForProvider(String providerId) async {
    final val = await _secureStorage.read(key: 'key_provider_$providerId');
    if (val != null && val.isNotEmpty) return val;

    // Fallback to legacy key
    try {
      final enumVal = LLMProvider.values.firstWhere((e) => e.name == providerId);
      return await _secureStorage.read(key: _getStorageKey(enumVal));
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteApiKeyForProvider(String providerId) async {
    await _secureStorage.delete(key: 'key_provider_$providerId');
    try {
      final enumVal = LLMProvider.values.firstWhere((e) => e.name == providerId);
      await _secureStorage.delete(key: _getStorageKey(enumVal));
    } catch (_) {}
  }

  Future<void> setApiKey(LLMProvider provider, String key) =>
      setApiKeyForProvider(provider.name, key);

  Future<String?> getApiKey(LLMProvider provider) =>
      getApiKeyForProvider(provider.name);

  Future<String?> getAnthropicApiKey() => getApiKey(LLMProvider.anthropic);
  Future<String?> getOpenAiApiKey() => getApiKey(LLMProvider.openai);

  String getSelectedEngine() {
    return _prefs.getString(_prefSelectedEngine) ?? 'builtin';
  }

  Future<void> setSelectedEngine(String engine) async {
    await _prefs.setString(_prefSelectedEngine, engine);
  }

  String _getStorageKey(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.anthropic:
        return _anthropicKey;
      case LLMProvider.openai:
        return _openaiKey;
      case LLMProvider.deepseek:
        return _deepseekKey;
      case LLMProvider.gemini:
        return _geminiKey;
      case LLMProvider.custom:
        return _customKey;
    }
  }

  // --- Active Provider & Model ---
  String getActiveProviderId() {
    final saved = _prefs.getString(_prefActiveProvider);
    if (saved != null && saved.isNotEmpty) return saved;
    final providers = getProviders();
    if (providers.isNotEmpty) return providers.first.id;
    return '';
  }

  Future<void> setActiveProviderId(String providerId) async {
    await _prefs.setString(_prefActiveProvider, providerId);
  }

  LLMProvider getActiveProvider() {
    final name = getActiveProviderId();
    try {
      return LLMProvider.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return LLMProvider.custom;
    }
  }

  Future<void> setActiveProvider(LLMProvider provider) async {
    await setActiveProviderId(provider.name);
  }

  String getActiveModel() {
    final saved = _prefs.getString(_prefActiveModel);
    if (saved != null && saved.isNotEmpty) return saved;
    final provider = getProvider(getActiveProviderId());
    if (provider != null && provider.models.isNotEmpty) {
      return provider.models.first.id;
    }
    return '';
  }

  Future<void> setActiveModel(String model) async {
    await _prefs.setString(_prefActiveModel, model.trim());
  }

  // --- Base URLs ---
  String getCustomBaseUrl() {
    return _prefs.getString(_prefCustomBaseUrl) ?? 'https://api.openai.com/v1';
  }

  Future<void> setCustomBaseUrl(String url) async {
    await _prefs.setString(_prefCustomBaseUrl, url.trim());
  }

  String getDeepseekBaseUrl() {
    final p = getProvider('deepseek');
    if (p != null && p.baseUrl.isNotEmpty) return p.baseUrl;
    return _prefs.getString(_prefDeepseekBaseUrl) ?? 'https://api.deepseek.com';
  }

  Future<void> setDeepseekBaseUrl(String url) async {
    await _prefs.setString(_prefDeepseekBaseUrl, url.trim());
    final p = getProvider('deepseek');
    if (p != null) {
      await addOrUpdateProvider(p.copyWith(baseUrl: url.trim()));
    }
  }

  // --- Approval Mode ---
  ApprovalMode getApprovalMode() {
    final name = _prefs.getString(_prefApprovalMode);
    if (name != null) {
      try {
        return ApprovalMode.values.byName(name);
      } catch (_) {}
    }
    // Backward compatibility with legacy YOLO toggle
    if (_prefs.getBool(_prefYoloMode) == true) {
      return ApprovalMode.yolo;
    }
    return ApprovalMode.autoApprove;
  }

  Future<void> setApprovalMode(ApprovalMode mode) async {
    await _prefs.setString(_prefApprovalMode, mode.name);
    await _prefs.setBool(_prefYoloMode, mode == ApprovalMode.yolo);
  }

  bool isYoloMode() {
    return getApprovalMode() == ApprovalMode.yolo;
  }

  Future<void> setYoloMode(bool enabled) async {
    await setApprovalMode(enabled ? ApprovalMode.yolo : ApprovalMode.autoApprove);
  }

  // --- Thinking Intensity ---
  ThinkingIntensity getThinkingIntensity() {
    final name = _prefs.getString(_prefThinkingIntensity);
    if (name != null) {
      try {
        return ThinkingIntensity.values.byName(name);
      } catch (_) {}
    }
    return ThinkingIntensity.high;
  }

  Future<void> setThinkingIntensity(ThinkingIntensity intensity) async {
    await _prefs.setString(_prefThinkingIntensity, intensity.name);
  }

  // --- Localization Language (Default: 'zh') ---
  String getLanguage() {
    return _prefs.getString(_prefLanguage) ?? 'zh';
  }

  Future<void> setLanguage(String langCode) async {
    await _prefs.setString(_prefLanguage, langCode);
  }

  // --- Theme Mode (Default: 'dark') ---
  static const _prefThemeMode = 'pref_theme_mode';

  ThemeMode getThemeMode() {
    final mode = _prefs.getString(_prefThemeMode);
    switch (mode) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_prefThemeMode, mode.name);
  }

  // --- Auto-rotate screen (Default: true) ---
  static const _prefAutoRotate = 'pref_auto_rotate';

  bool isAutoRotateEnabled() {
    return _prefs.getBool(_prefAutoRotate) ?? true;
  }

  Future<void> setAutoRotateEnabled(bool enabled) async {
    await _prefs.setBool(_prefAutoRotate, enabled);
  }

  // --- Expanded Projects Persistence ---
  static const _prefExpandedProjects = 'pref_expanded_projects';

  Set<String> getExpandedProjects() {
    final list = _prefs.getStringList(_prefExpandedProjects);
    if (list != null) {
      return list.toSet();
    }
    return {'agentsdroid'};
  }

  Future<void> setExpandedProjects(Set<String> projects) async {
    await _prefs.setStringList(_prefExpandedProjects, projects.toList());
  }

  // --- Section Expansion Persistence in Drawer ---
  static const _prefProjectsSectionExpanded = 'pref_projects_section_expanded';
  static const _prefConversationsSectionExpanded = 'pref_conversations_section_expanded';

  bool isProjectsSectionExpanded() {
    return _prefs.getBool(_prefProjectsSectionExpanded) ?? true;
  }

  Future<void> setProjectsSectionExpanded(bool expanded) async {
    await _prefs.setBool(_prefProjectsSectionExpanded, expanded);
  }

  bool isConversationsSectionExpanded() {
    return _prefs.getBool(_prefConversationsSectionExpanded) ?? true;
  }

  Future<void> setConversationsSectionExpanded(bool expanded) async {
    await _prefs.setBool(_prefConversationsSectionExpanded, expanded);
  }

  // Export environment variables map for PRoot Linux environment injection
  Future<Map<String, String>> exportEnvironmentVariables() async {
    final env = <String, String>{};
    final anthropicKey = await getApiKey(LLMProvider.anthropic);
    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      env['ANTHROPIC_API_KEY'] = anthropicKey;
    }
    final openaiKey = await getApiKey(LLMProvider.openai);
    if (openaiKey != null && openaiKey.isNotEmpty) {
      env['OPENAI_API_KEY'] = openaiKey;
    }
    final deepseekKey = await getApiKey(LLMProvider.deepseek);
    if (deepseekKey != null && deepseekKey.isNotEmpty) {
      env['DEEPSEEK_API_KEY'] = deepseekKey;
    }
    final geminiKey = await getApiKey(LLMProvider.gemini);
    if (geminiKey != null && geminiKey.isNotEmpty) {
      env['GEMINI_API_KEY'] = geminiKey;
    }

    final activeProvider = getProvider(getActiveProviderId());
    if (activeProvider != null && activeProvider.isCustom) {
      final customKey = await getApiKeyForProvider(activeProvider.id);
      if (customKey != null && customKey.isNotEmpty) {
        env['OPENAI_API_KEY'] = customKey;
        env['OPENAI_BASE_URL'] = activeProvider.baseUrl;
      }
    }
    return env;
  }
}
