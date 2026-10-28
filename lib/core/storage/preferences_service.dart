import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service dedicated exclusively to general UI preferences, display configuration,
/// and navigation states, separating them from cryptographic secret storage in KeyVault.
class PreferencesService {
  final SharedPreferences _prefs;

  static const _prefLanguage = 'pref_language';
  static const _prefThemeMode = 'pref_theme_mode';
  static const _prefAutoRotate = 'pref_auto_rotate';
  static const _prefExpandedProjects = 'pref_expanded_projects';
  static const _prefProjectsSectionExpanded = 'pref_projects_section_expanded';
  static const _prefConversationsSectionExpanded = 'pref_conversations_section_expanded';

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // --- Localization Language (Default: 'zh') ---
  String getLanguage() {
    return _prefs.getString(_prefLanguage) ?? 'zh';
  }

  Future<void> setLanguage(String langCode) async {
    await _prefs.setString(_prefLanguage, langCode);
  }

  // --- Theme Mode (Default: 'dark') ---
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

  // --- Auto-rotate screen (Default: false - Lock Portrait) ---
  bool isAutoRotateEnabled() {
    return _prefs.getBool(_prefAutoRotate) ?? false;
  }

  Future<void> setAutoRotateEnabled(bool enabled) async {
    await _prefs.setBool(_prefAutoRotate, enabled);
  }

  // --- Expanded Projects Persistence ---
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
}
