import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pref_language': 'en',
      'pref_theme_mode': 'light',
      'pref_auto_rotate': true,
      'pref_expanded_projects': ['project_a', 'project_b'],
      'pref_projects_section_expanded': false,
      'pref_conversations_section_expanded': false,
    });
    service = await PreferencesService.create();
  });

  test('PreferencesService reads and writes all UI preferences correctly', () async {
    // Initial reads
    expect(service.getLanguage(), 'en');
    expect(service.getThemeMode(), ThemeMode.light);
    expect(service.isAutoRotateEnabled(), isTrue);
    expect(service.getExpandedProjects(), {'project_a', 'project_b'});
    expect(service.isProjectsSectionExpanded(), isFalse);
    expect(service.isConversationsSectionExpanded(), isFalse);

    // Updates
    await service.setLanguage('zh');
    expect(service.getLanguage(), 'zh');

    await service.setThemeMode(ThemeMode.dark);
    expect(service.getThemeMode(), ThemeMode.dark);

    await service.setAutoRotateEnabled(false);
    expect(service.isAutoRotateEnabled(), isFalse);

    await service.setExpandedProjects({'new_project'});
    expect(service.getExpandedProjects(), {'new_project'});

    await service.setProjectsSectionExpanded(true);
    expect(service.isProjectsSectionExpanded(), isTrue);

    await service.setConversationsSectionExpanded(true);
    expect(service.isConversationsSectionExpanded(), isTrue);
  });
}
