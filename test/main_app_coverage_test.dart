import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/providers/app_providers.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late KeyVault keyVault;
  late WorkspaceService workspaceService;
  late SessionService sessionService;
  late PRootManager prootManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('main_app_test_');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keyVault = KeyVault(const FlutterSecureStorage(), prefs);

    workspaceService = WorkspaceService();
    await workspaceService.init(baseDir: tempDir);

    sessionService = SessionService();
    await sessionService.init(baseDir: tempDir);

    prootManager = PRootManager();
    await prootManager.init(appSupportDir: tempDir, workspacePath: workspaceService.workspacePath);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AgentsDroidApp Widget and Configuration Tests', () {
    testWidgets('pumps AgentsDroidApp, responds to locale, theme, and orientation changes', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          keyVaultProvider.overrideWithValue(keyVault),
          workspaceServiceProvider.overrideWithValue(workspaceService),
          sessionServiceProvider.overrideWithValue(sessionService),
          prootManagerProvider.overrideWithValue(prootManager),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: AgentsDroidApp(
            keyVault: keyVault,
            workspaceService: workspaceService,
            sessionService: sessionService,
            prootManager: prootManager,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);

      final BuildContext context = tester.element(find.byType(MaterialApp));

      // Test setLocale
      AgentsDroidApp.setLocale(context, const Locale('en'));
      await tester.pumpAndSettle();
      expect(container.read(appLocaleProvider).languageCode, equals('en'));

      // Test setThemeMode
      AgentsDroidApp.setThemeMode(context, ThemeMode.light);
      await tester.pumpAndSettle();
      expect(container.read(appThemeModeProvider), equals(ThemeMode.light));

      // Test setScreenOrientation
      AgentsDroidApp.setScreenOrientation(context, false);
      await tester.pumpAndSettle();
      expect(container.read(appAutoRotateProvider), isFalse);

      AgentsDroidApp.setScreenOrientation(context, true);
      await tester.pumpAndSettle();
      expect(container.read(appAutoRotateProvider), isTrue);

      // Direct applyScreenOrientation call
      AgentsDroidApp.applyScreenOrientation(false);
      AgentsDroidApp.applyScreenOrientation(true);
    });
  });
}
