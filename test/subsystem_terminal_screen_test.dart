import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/terminal/subsystem_terminal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KeyVault keyVault;
  late PRootManager prootManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);

    prootManager = PRootManager();
  });

  Widget buildTestableWidget({Locale locale = const Locale('zh')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: SubsystemTerminalScreen(
        prootManager: prootManager,
        keyVault: keyVault,
      ),
    );
  }

  testWidgets('SubsystemTerminalScreen renders title, warning banner, and toolchain chips (ZH)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // App bar title
    expect(find.text('Linux 子系统控制台'), findsOneWidget);

    // Initial terminal log greeting
    expect(find.textContaining('AgentsDroid PRoot Subsystem Terminal'), findsOneWidget);
    expect(find.textContaining('Workspace mounted at: /workspace'), findsOneWidget);

    // Not installed warning banner because prootManager is uninstalled initially
    expect(find.textContaining('子系统尚未安装'), findsOneWidget);

    // Toolchain chips exist
    expect(find.text('Node.js'), findsOneWidget);
    expect(find.text('Python'), findsOneWidget);
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Claude CLI'), findsOneWidget);

    // Quick command shortcut chips
    expect(find.text('uname -a'), findsOneWidget);
    expect(find.text('cat /etc/os-release'), findsOneWidget);
    expect(find.text('ls -la /workspace'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    expect(find.text('python3 main.py'), findsOneWidget);

    // Clear logs button
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    // Log greeting should now be cleared
    expect(find.textContaining('AgentsDroid PRoot Subsystem Terminal'), findsNothing);
  });

  testWidgets('SubsystemTerminalScreen renders in English', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Linux Subsystem Console'), findsOneWidget);
    expect(find.textContaining('Linux Subsystem is not installed'), findsOneWidget);
  });
}
