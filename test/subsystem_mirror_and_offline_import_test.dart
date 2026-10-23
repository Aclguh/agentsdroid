import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_installer.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/settings/subsystem_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late KeyVault keyVault;
  late PRootManager prootManager;
  late Directory tempAppDir;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);

    tempAppDir = Directory.systemTemp.createTempSync('agentsdroid_test_proot_');

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempAppDir.path;
    });

    prootManager = PRootManager();
    await prootManager.init(appSupportDir: tempAppDir);
  });

  tearDown(() {
    try {
      if (tempAppDir.existsSync()) {
        tempAppDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PRoot Mirror and Installer Unit Tests', () {
    test('RootfsInstaller mirror URLs are properly configured', () {
      expect(RootfsInstaller.defaultDebianRootfsUrl, contains('github.com'));
      expect(RootfsInstaller.ghproxyDebianRootfsUrl, contains('ghproxy.net'));
    });

    test('scanLocalArchives does not throw even if folders do not exist', () async {
      final archives = await RootfsInstaller.scanLocalArchives();
      expect(archives, isA<List<File>>());
    });

    test('installSubsystemFromArchive reports error when file does not exist', () async {
      final nonExistentFile = File('/non_existent_path/fake_archive.tar.xz');
      final statuses = <PRootStatus>[];
      final sub = prootManager.statusStream.listen((p) => statuses.add(p.status));

      await prootManager.installSubsystemFromArchive(nonExistentFile);
      await pumpEventQueue();

      expect(prootManager.currentStatus, equals(PRootStatus.error));
      expect(statuses, contains(PRootStatus.error));
      await sub.cancel();
    });

    test('uninstallSubsystem resets status to notInstalled', () async {
      await prootManager.uninstallSubsystem();
      expect(prootManager.currentStatus, equals(PRootStatus.notInstalled));
    });
  });

  group('SubsystemSettingsScreen Mirror and Offline Import Widget Tests', () {
    Widget createTestApp(Locale locale) {
      return MaterialApp(
        locale: locale,
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
        home: SubsystemSettingsScreen(
          keyVault: keyVault,
          prootManager: prootManager,
        ),
      );
    }

    testWidgets('Renders installation method tabs (Online and Offline) in Chinese', (tester) async {
      await tester.pumpWidget(createTestApp(const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('安装方式'), findsOneWidget);
      expect(find.text('在线下载'), findsOneWidget);
      expect(find.text('离线导入'), findsOneWidget);

      // Default Online Download view
      expect(find.text('下载镜像源'), findsOneWidget);
      expect(find.text('国内加速镜像 (ghproxy.net - 推荐)'), findsOneWidget);
      expect(find.text('官方源 (GitHub Releases)'), findsOneWidget);
      expect(find.text('自定义下载 URL'), findsOneWidget);
      expect(find.text('下载并安装子系统'), findsOneWidget);
    });

    testWidgets('Switching to Custom URL reveals input field', (tester) async {
      await tester.pumpWidget(createTestApp(const Locale('zh')));
      await tester.pumpAndSettle();

      // Tap Custom URL radio tile
      final customRadio = find.text('自定义下载 URL');
      await tester.tap(customRadio);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Switching to Offline Import tab shows app data directory guide and direct import button', (tester) async {
      await tester.pumpWidget(createTestApp(const Locale('zh')));
      await tester.pumpAndSettle();

      // Tap Offline Import segment
      final offlineTab = find.text('离线导入');
      await tester.tap(offlineTab);
      await tester.pumpAndSettle();

      expect(find.text('应用专属数据目录'), findsOneWidget);
      expect(find.text('重新扫描'), findsOneWidget);
      expect(find.text('开始导入解压'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Renders properly in English locale', (tester) async {
      await tester.pumpWidget(createTestApp(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Installation Method'), findsOneWidget);
      expect(find.text('Online Download'), findsOneWidget);
      expect(find.text('Offline Import'), findsOneWidget);
      expect(find.text('Download Mirror Source'), findsOneWidget);
      expect(find.text('China Accelerator (ghproxy.net - Recommended)'), findsOneWidget);
      expect(find.text('Official Source (GitHub Releases)'), findsOneWidget);
    });
  });
}
