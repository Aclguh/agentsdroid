import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/ui/chat/chat_screen.dart';
import 'package:agentsdroid/ui/chat/widgets/thought_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThoughtCard Widget Tests', () {
    testWidgets('shows thought duration when completed and is collapsed by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('zh'), Locale('en')],
          locale: Locale('zh'),
          home: Scaffold(
            body: ThoughtCard(
              thought: 'Detailed thinking reasoning steps here...',
              durationSeconds: 12,
              isStreaming: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display duration
      expect(find.text('已思考 12 秒'), findsOneWidget);
      // Collapsed by default: text should not be visible
      expect(find.text('Detailed thinking reasoning steps here...'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('已思考 12 秒'));
      await tester.pumpAndSettle();

      // Now expanded: text visible
      expect(find.text('Detailed thinking reasoning steps here...'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('shows streaming status when thinking is in progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('zh'), Locale('en')],
          locale: Locale('zh'),
          home: Scaffold(
            body: ThoughtCard(
              thought: 'Streaming thoughts...',
              isStreaming: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('思考中...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ChatScreen Drawer and Top Bar Project Switcher Tests', () {
    late Directory tempDir;
    late KeyVault keyVault;
    late WorkspaceService workspace;
    late PRootManager prootManager;
    late SessionService sessionService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const secureStorage = FlutterSecureStorage();
      keyVault = KeyVault(secureStorage, prefs);

      tempDir = await Directory.systemTemp.createTemp('drawer_test_');
      workspace = WorkspaceService();
      await workspace.init(baseDir: tempDir);

      prootManager = PRootManager();
      sessionService = SessionService();
      await sessionService.init(baseDir: tempDir);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('Top bar displays No Project for fresh session and opens switch sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            prootManager: prootManager,
            sessionService: sessionService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar displays '无项目'
      expect(find.text('无项目'), findsOneWidget);

      // Tap top bar project selector to open project selection dialog
      await tester.tap(find.byKey(const Key('top_bar_project_selector')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('选择此会话所属的项目'), findsOneWidget);
      expect(find.text('新建项目'), findsOneWidget);
    });

    testWidgets('Drawer allows collapsing and expanding Projects and Conversations sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Create a project first
      await tester.runAsync(() async {
        await workspace.createProject('DemoProject');
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            prootManager: prootManager,
            sessionService: sessionService,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Check sections exist
      expect(find.text('项目'), findsOneWidget);
      expect(find.text('会话'), findsOneWidget);
      expect(find.text('DemoProject'), findsOneWidget);

      // Tap '项目' to collapse section
      await tester.tap(find.text('项目'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Project item should now be hidden
      expect(find.text('DemoProject'), findsNothing);
      expect(keyVault.isProjectsSectionExpanded(), isFalse);

      // Tap '项目' again to expand section
      await tester.tap(find.text('项目'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DemoProject'), findsOneWidget);
      expect(keyVault.isProjectsSectionExpanded(), isTrue);
    });

    testWidgets('archiving a session removes it from drawer and moves it to archived', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      late String sessionId;
      await tester.runAsync(() async {
        final session = await sessionService.createSession(title: 'ToArchive');
        sessionId = session.id;
        session.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'Hi'));
        await sessionService.saveSession(session);
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            prootManager: prootManager,
            sessionService: sessionService,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Check session appears
      expect(find.text('ToArchive'), findsOneWidget);

      // Tap popup menu of session specifically for ToArchive
      final toArchiveRow = find.ancestor(
        of: find.text('ToArchive'),
        matching: find.byType(Row),
      ).first;
      final moreVertFinder = find.descendant(
        of: toArchiveRow,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(moreVertFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 归档
      await tester.tap(find.text('归档'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ToArchive should now be gone from the drawer sessions!
      expect(find.text('ToArchive'), findsNothing);

      // Verify in sessionService
      final archived = await sessionService.listSessions(isArchived: true);
      expect(archived.any((s) => s.id == sessionId), isTrue);
    });

    testWidgets('creating a new session in a project immediately displays in drawer without manual switching', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await workspace.createProject('AppFeature');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: ChatScreen(
            keyVault: keyVault,
            workspace: workspace,
            prootManager: prootManager,
            sessionService: sessionService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // AppFeature should be listed
      expect(find.text('AppFeature'), findsOneWidget);

      // Find the '+' button on AppFeature folder tile and tap it
      final appFeatureRow = find.ancestor(
        of: find.text('AppFeature'),
        matching: find.byType(Row),
      ).first;
      final addSessionBtn = find.descendant(
        of: appFeatureRow,
        matching: find.byIcon(Icons.add),
      );
      expect(addSessionBtn, findsOneWidget);
      await tester.tap(addSessionBtn);
      await tester.pumpAndSettle();

      // The drawer closes and top bar should show AppFeature as project
      expect(find.text('AppFeature'), findsOneWidget);

      // Open drawer again
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // AppFeature should be expanded and the newly created session (title '新会话') should be immediately visible in the drawer!
      expect(keyVault.getExpandedProjects().contains('AppFeature'), isTrue);
      final drawerFinder = find.byType(Drawer);
      expect(
        find.descendant(of: drawerFinder, matching: find.text('新会话')),
        findsOneWidget,
      );
    });
  });
}
