import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/app_meta.dart';
import 'package:agentsdroid/core/storage/session_service.dart';
import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/ui/chat/widgets/chat_message_bubble.dart';
import 'package:agentsdroid/ui/chat/widgets/conversation_history_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppMeta Tests', () {
    test('verifies core app metadata constants', () {
      expect(AppMeta.appName, 'AgentsDroid');
      expect(AppMeta.version, '1.0.0');
      expect(AppMeta.buildNumber, '1');
      expect(AppMeta.packageName, 'com.agentsdroid.agentsdroid');
      expect(AppMeta.repoUrl, 'https://github.com/Aclguh/agentsdroid');
      expect(AppMeta.license, 'MIT License');
      expect(AppMeta.iconAsset, isNotEmpty);
    });
  });

  group('ChatMessageBubble Tests', () {
    Widget buildBubbleWidget(ChatMessage msg, {void Function(String, bool)? onApproval}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: Scaffold(
          body: ChatMessageBubble(
            message: msg,
            markdownStyleSheet: MarkdownStyleSheet(),
            onApprovalResponse: onApproval,
          ),
        ),
      );
    }

    testWidgets('renders user message correctly', (tester) async {
      final userMsg = ChatMessage(
        id: 'u1',
        role: MessageRole.user,
        content: 'Hello AgentsDroid!',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(buildBubbleWidget(userMsg));
      await tester.pumpAndSettle();

      expect(find.text('Hello AgentsDroid!'), findsOneWidget);
    });

    testWidgets('renders assistant message with thought, tool approval, and diff blocks', (tester) async {
      String? approvedId;
      bool? approvedVal;

      final diff = DiffEvent(
        filePath: 'lib/main.dart',
        originalContent: 'void main() {}',
        newContent: 'void main() {\n  runApp(App());\n}',
        diffLines: [
          DiffLine(type: DiffLineType.unchanged, text: 'void main() {', oldLineNumber: 1, newLineNumber: 1),
          DiffLine(type: DiffLineType.added, text: '  runApp(App());', newLineNumber: 2),
          DiffLine(type: DiffLineType.unchanged, text: '}', oldLineNumber: 2, newLineNumber: 3),
        ],
      );

      final assistantMsg = ChatMessage(
        id: 'a1',
        role: MessageRole.assistant,
        content: 'Here is my response and patch:',
        timestamp: DateTime.now(),
        blocks: [
          ThoughtBlock('Analyzing code structure...'),
          ToolCallBlock(
            ToolCallEvent(
              toolCallId: 'call_123',
              toolName: 'writeFile',
              arguments: {'path': 'test.py', 'content': 'print(1)'},
            ),
          ),
          DiffBlock(diff),
          TextBlock('Code has been prepared successfully.'),
        ],
      );

      await tester.pumpWidget(buildBubbleWidget(assistantMsg, onApproval: (id, val) {
        approvedId = id;
        approvedVal = val;
      }));
      await tester.pumpAndSettle();

      // Verify thought card
      expect(find.textContaining('推理过程'), findsOneWidget);

      // Verify tool approval card header
      expect(find.textContaining('writeFile'), findsOneWidget);

      // Tap ToolApprovalCard to expand it and reveal action buttons
      await tester.tap(find.textContaining('writeFile'));
      await tester.pumpAndSettle();

      expect(find.text('允许'), findsOneWidget);

      // Tap approve
      await tester.tap(find.text('允许'));
      await tester.pumpAndSettle();

      expect(approvedId, equals('call_123'));
      expect(approvedVal, isTrue);

      // Verify Diff card presence
      expect(find.text('lib/main.dart'), findsOneWidget);

      // Tap Diff card opens diff viewer screen
      await tester.tap(find.text('lib/main.dart'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('ConversationHistoryModal Tests', () {
    late Directory tempDir;
    late SessionService sessionService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('history_modal_test_');
      sessionService = SessionService();
      await sessionService.init(baseDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets('renders conversation history modal and interacts with sessions', (tester) async {
      // Create test sessions
      final s1 = await sessionService.createSession(projectName: 'agentsdroid', title: 'First session query');
      s1.messages.add(
        ChatMessage(id: '1', role: MessageRole.user, content: 'First session query', timestamp: DateTime.now()),
      );
      await sessionService.saveSession(s1);

      final s2 = await sessionService.createSession(projectName: 'agentsdroid', title: 'Second session query');
      s2.messages.add(
        ChatMessage(id: '2', role: MessageRole.user, content: 'Second session query', timestamp: DateTime.now()),
      );
      await sessionService.saveSession(s2);
      await sessionService.archiveSession(s2.id);

      String? selectedSessionId;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: ConversationHistoryModal(
                sessionService: sessionService,
                currentSessionId: s1.id,
                l10n: l10n,
                formatRelativeTime: (dt) => '刚刚',
                onSelectSession: (id) => selectedSessionId = id,
                onArchiveSession: (id) async {},
                onUnarchiveSession: (id) async {},
                onDeleteSession: (id) async {},
              ),
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Verify modal elements
      expect(find.text('会话历史'), findsOneWidget);
      expect(find.text('全部会话'), findsOneWidget);
      expect(find.text('已归档会话'), findsOneWidget);

      // Verify sessions listed
      expect(find.text('First session query'), findsOneWidget);

      // Tap archived filter
      await tester.tap(find.text('已归档会话'));
      await tester.pumpAndSettle();
      expect(find.text('Second session query'), findsOneWidget);

      // Select session
      await tester.tap(find.text('Second session query'));
      await tester.pumpAndSettle();
      expect(selectedSessionId, equals(s2.id));
    });
  });
}
