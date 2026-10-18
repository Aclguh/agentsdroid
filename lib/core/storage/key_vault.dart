import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- API Keys ---
  Future<void> setApiKey(LLMProvider provider, String key) async {
    final storageKey = _getStorageKey(provider);
    if (key.trim().isEmpty) {
      await _secureStorage.delete(key: storageKey);
    } else {
      await _secureStorage.write(key: storageKey, value: key.trim());
    }
  }

  Future<String?> getApiKey(LLMProvider provider) async {
    return await _secureStorage.read(key: _getStorageKey(provider));
  }

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
  LLMProvider getActiveProvider() {
    final name = _prefs.getString(_prefActiveProvider);
    if (name != null) {
      try {
        return LLMProvider.values.firstWhere((e) => e.name == name);
      } catch (_) {}
    }
    return LLMProvider.deepseek; // Default to DeepSeek for cost efficiency
  }

  Future<void> setActiveProvider(LLMProvider provider) async {
    await _prefs.setString(_prefActiveProvider, provider.name);
  }

  String getActiveModel() {
    return _prefs.getString(_prefActiveModel) ?? getActiveProvider().defaultModel;
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
    return _prefs.getString(_prefDeepseekBaseUrl) ?? 'https://api.deepseek.com';
  }

  Future<void> setDeepseekBaseUrl(String url) async {
    await _prefs.setString(_prefDeepseekBaseUrl, url.trim());
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

  // Backward compatibility helpers
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
    return env;
  }
}
