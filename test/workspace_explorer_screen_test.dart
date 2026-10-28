import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/ui/explorer/workspace_explorer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WorkspaceService workspace;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('explorer_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    // Seed some test files
    await workspace.writeFile('test.txt', 'Hello World');
    await workspace.createDirectory('src');
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
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
      home: WorkspaceExplorerScreen(workspace: workspace),
    );
  }

  testWidgets('WorkspaceExplorerScreen displays files and directories', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('test.txt'), findsOneWidget);
    expect(find.text('src'), findsOneWidget);
    expect(find.byIcon(Icons.folder), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
  });

  testWidgets('WorkspaceExplorerScreen creates a new file via dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Tap + PopupMenuButton
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Tap 新建文件
    expect(find.text('新建文件'), findsOneWidget);
    await tester.tap(find.text('新建文件'));
    await tester.pumpAndSettle();

    // Dialog appears, enter filename
    await tester.enterText(find.byType(TextField), 'new_script.py');
    await tester.pumpAndSettle();

    // Tap 允许 inside runAsync to allow async file I/O to complete
    await tester.runAsync(() async {
      await tester.tap(find.text('允许'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // File should now appear in the list
    expect(find.text('new_script.py'), findsOneWidget);
  });

  testWidgets('WorkspaceExplorerScreen creates a new folder via dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Tap + PopupMenuButton
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Tap 新建文件夹
    expect(find.text('新建文件夹'), findsOneWidget);
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();

    // Dialog appears, enter folder name
    await tester.enterText(find.byType(TextField), 'subfolder');
    await tester.pumpAndSettle();

    // Tap 允许 inside runAsync to allow async file I/O to complete
    await tester.runAsync(() async {
      await tester.tap(find.text('允许'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Folder should now appear in the list
    expect(find.text('subfolder'), findsOneWidget);
  });

  testWidgets('WorkspaceExplorerScreen opens file viewer modal and copies content', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Tap on test.txt inside runAsync because readFile does disk I/O
    await tester.runAsync(() async {
      await tester.tap(find.text('test.txt'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // File viewer modal should open
    expect(find.text('Hello World'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);

    // Tap copy
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();
    expect(find.text('已复制文件内容到剪贴板'), findsOneWidget);

    // Tap close
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Hello World'), findsNothing);
  });

  testWidgets('WorkspaceExplorerScreen deletes a file with confirmation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Target the delete button inside the ListTile for test.txt
    final fileTile = find.ancestor(of: find.text('test.txt'), matching: find.byType(ListTile));
    final deleteButton = find.descendant(of: fileTile, matching: find.byIcon(Icons.delete_outline));
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('确认删除'), findsOneWidget);

    // Tap delete inside runAsync
    await tester.runAsync(() async {
      await tester.tap(find.text('删除'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // File should be deleted
    expect(find.text('test.txt'), findsNothing);
  });

  testWidgets('WorkspaceExplorerScreen shows not-installed warning when prootManager is null', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Tap clone git icon
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.download_for_offline_outlined));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Linux 子系统尚未安装，请前往「设置」进行安装'), findsOneWidget);
  });

  testWidgets('WorkspaceExplorerScreen renders extension-specific icons and empty state', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() async {
      await workspace.writeFile('main.dart', 'void main() {}');
      await workspace.writeFile('run.py', 'print(1)');
      await workspace.writeFile('index.js', 'console.log(1)');
      await workspace.writeFile('README.md', '# Readme');
      await workspace.writeFile('config.json', '{}');
    });

    await tester.pumpWidget(buildTestableWidget());
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
    expect(find.byIcon(Icons.code), findsOneWidget);
    expect(find.byIcon(Icons.javascript), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.data_object), findsOneWidget);
  });
}
