import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/app_meta.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/settings/about_screen.dart';
import 'package:agentsdroid/ui/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardContent;

  setUp(() {
    clipboardContent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments as Map<dynamic, dynamic>;
        clipboardContent = args['text'] as String?;
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget createHost({
    Locale locale = const Locale('zh'),
    Widget? home,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: home ?? const AboutScreen(),
    );
  }

  testWidgets('AboutScreen 渲染应用图标、应用名、版本信息、开源许可与致谢 (中文)', (tester) async {
    await tester.pumpWidget(createHost(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 标题与应用名
    expect(find.text('关于'), findsOneWidget);
    expect(find.text(AppMeta.appName), findsOneWidget);

    // 版本信息
    expect(find.text('版本信息'), findsOneWidget);
    expect(find.text(AppMeta.version), findsOneWidget);
    expect(find.text(AppMeta.buildNumber), findsOneWidget);
    expect(find.text(AppMeta.packageName), findsOneWidget);

    // 仓库
    expect(find.text('开源仓库'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text(AppMeta.repoUrl), findsOneWidget);

    // 许可
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text(AppMeta.license), findsOneWidget);

    // 致谢与版权
    expect(find.text('致谢与技术基石'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('PRoot (Debian)'), findsOneWidget);
    expect(find.text('Claude Code CLI'), findsOneWidget);
    expect(find.textContaining('AgentsDroid © 2026 Aclguh'), findsOneWidget);
  });

  testWidgets('AboutScreen 点击 GitHub 复制仓库地址到剪贴板并弹出 SnackBar 提示', (tester) async {
    await tester.pumpWidget(createHost(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(clipboardContent, equals(AppMeta.repoUrl));
    expect(find.text('仓库地址已复制到剪贴板'), findsOneWidget);
  });

  testWidgets('AboutScreen 在英文环境下正确渲染', (tester) async {
    await tester.pumpWidget(createHost(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text(AppMeta.appName), findsOneWidget);
    expect(find.text('Version Information'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('Package Name'), findsOneWidget);
    expect(find.text('Repository'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
    expect(find.text('Credits & Foundations'), findsOneWidget);

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(clipboardContent, equals(AppMeta.repoUrl));
    expect(find.text('Repository URL copied to clipboard'), findsOneWidget);
  });

  testWidgets('SettingsScreen 列表最后一项为关于卡片，点击可正确导航至 AboutScreen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    final keyVault = KeyVault(secureStorage, prefs);
    final prootManager = PRootManager();

    await tester.pumpWidget(createHost(
      locale: const Locale('zh'),
      home: SettingsScreen(
        keyVault: keyVault,
        prootManager: prootManager,
      ),
    ));
    await tester.pumpAndSettle();

    // 滚动至底部确保关于卡片可见
    final aboutCardFinder = find.text('关于');
    await tester.scrollUntilVisible(aboutCardFinder, 100);
    expect(aboutCardFinder, findsOneWidget);
    expect(find.text('版本、包名与开源信息'), findsOneWidget);

    await tester.tap(aboutCardFinder);
    await tester.pumpAndSettle();

    // 确认已进入 AboutScreen
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text(AppMeta.appName), findsOneWidget);
    expect(find.text(AppMeta.packageName), findsOneWidget);
  });
}
