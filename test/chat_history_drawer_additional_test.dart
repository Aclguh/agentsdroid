import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/models/chat_session.dart';
import 'package:agentsdroid/ui/chat/widgets/chat_history_drawer.dart';
import 'package:agentsdroid/ui/chat/widgets/conversation_history_modal.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
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
    locale: const Locale('zh'),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late KeyVault keyVault;
  late WorkspaceService workspace;
  late SessionService sessionService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('drawer_additional_test_');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keyVault = KeyVault(const FlutterSecureStorage(), prefs);
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);
    sessionService = SessionService();
    await sessionService.init(baseDir: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ChatHistoryDrawer and ConversationHistoryModal Tests', () {
    testWidgets('Top action buttons invoke callbacks', (tester) async {
      bool newSessionCalled = false;
      bool historyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            drawer: ChatHistoryDrawer(
              workspace: workspace,
              sessionService: sessionService,
              keyVault: keyVault,
              onRefreshTree: () {},
              onNewSession: (_) => newSessionCalled = true,
              onSelectSession: (_) {},
              onRenameSession: (_) {},
              onArchiveSession: (_) {},
              onUnarchiveSession: (_) {},
              onDeleteSession: (_) {},
              onCreateProject: () {},
              onOpenConversationHistory: () => historyCalled = true,
              onOpenWorkspaceFiles: () {},
              onOpenSettings: () {},
            ),
            body: const SizedBox(),
          ),
        ),
      );

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap Conversation History
      await tester.tap(find.text('会话历史'));
      await tester.pumpAndSettle();
      expect(historyCalled, isTrue);

      // Tap New Conversation (which pops drawer)
      await tester.tap(find.text('新建对话'));
      await tester.pumpAndSettle();
      expect(newSessionCalled, isTrue);
    });

    testWidgets('ConversationHistoryModal searches and displays sessions', (tester) async {
      final s1 = await sessionService.createSession(title: 'Alpha Flutter Bug');
      s1.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'alpha'));
      await sessionService.saveSession(s1);

      final s2 = await sessionService.createSession(title: 'Beta Android Native');
      s2.messages.add(ChatMessage(id: 'm2', role: MessageRole.user, content: 'beta'));
      await sessionService.saveSession(s2);

      final s3 = await sessionService.createSession(title: 'Archived Feature');
      s3.messages.add(ChatMessage(id: 'm3', role: MessageRole.user, content: 'archived'));
      await sessionService.saveSession(s3);
      await sessionService.archiveSession(s3.id);

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  final l10n = AppLocalizations.of(context)!;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => ConversationHistoryModal(
                      sessionService: sessionService,
                      currentSessionId: s1.id,
                      onSelectSession: (_) {},
                      onArchiveSession: (_) async {},
                      onUnarchiveSession: (_) async {},
                      onDeleteSession: (_) async {},
                      formatRelativeTime: (dt) => 'now',
                      l10n: l10n,
                    ),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('会话历史'), findsOneWidget);
      expect(find.text('Alpha Flutter Bug'), findsOneWidget);
      expect(find.text('Beta Android Native'), findsOneWidget);

      // Search filter
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Alpha');
      await tester.pumpAndSettle();

      expect(find.text('Alpha Flutter Bug'), findsOneWidget);
      expect(find.text('Beta Android Native'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Switch to Archived tab
      await tester.tap(find.text('已归档会话'));
      await tester.pumpAndSettle();

      expect(find.text('Archived Feature'), findsOneWidget);
    });

    testWidgets('ChatHistoryDrawer renders sessions, bottom shortcuts, and display options', (tester) async {
      bool filesCalled = false;
      bool settingsCalled = false;
      ChatSessionSummary? selectedSession;

      final s1 = await sessionService.createSession(title: 'Tree Session 1');
      s1.messages.add(ChatMessage(id: 'm1', role: MessageRole.user, content: 'msg 1'));
      await sessionService.saveSession(s1);

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            drawer: ChatHistoryDrawer(
              workspace: workspace,
              sessionService: sessionService,
              keyVault: keyVault,
              onRefreshTree: () {},
              onNewSession: (_) {},
              onSelectSession: (s) => selectedSession = s,
              onRenameSession: (_) {},
              onArchiveSession: (_) {},
              onUnarchiveSession: (_) {},
              onDeleteSession: (_) {},
              onCreateProject: () {},
              onOpenConversationHistory: () {},
              onOpenWorkspaceFiles: () => filesCalled = true,
              onOpenSettings: () => settingsCalled = true,
            ),
            body: const SizedBox(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Session rendered in tree
      expect(find.text('Tree Session 1'), findsOneWidget);
      await tester.tap(find.text('Tree Session 1'));
      await tester.pumpAndSettle();
      expect(selectedSession?.title, equals('Tree Session 1'));

      // Re-open drawer to test bottom shortcuts
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap 工作区文件
      await tester.tap(find.text('工作区文件'));
      await tester.pumpAndSettle();
      expect(filesCalled, isTrue);

      // Re-open drawer to test 设置
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(settingsCalled, isTrue);
    });
  });
}
