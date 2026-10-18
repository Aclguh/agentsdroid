import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';
import 'package:agentsdroid/ui/chat/widgets/tool_approval_card.dart';

void main() {
  test('ChatMessage and ToolCallEvent model test', () {
    final toolCall = ToolCallEvent(
      toolCallId: 'call_123',
      toolName: 'read_file',
      arguments: {'path': 'main.py'},
      status: ToolCallStatus.pending,
    );

    final message = ChatMessage(
      id: 'msg_1',
      role: MessageRole.assistant,
      content: 'I will read main.py',
      toolCalls: [toolCall],
    );

    expect(message.role, equals(MessageRole.assistant));
    expect(message.toolCalls.length, equals(1));
    expect(message.toolCalls.first.toolName, equals('read_file'));
    expect(message.toolCalls.first.status, equals(ToolCallStatus.pending));
  });

  test('ChatMessage sequential blocks preserve order', () {
    final msg = ChatMessage(id: 'msg_seq', role: MessageRole.assistant);
    msg.blocks.add(ThoughtBlock('Thinking step 1...'));
    msg.blocks.add(TextBlock('I will now inspect the directory.'));
    msg.blocks.add(ToolCallBlock(ToolCallEvent(
      toolCallId: 'call_1',
      toolName: 'list_directory',
      arguments: {'path': '.'},
      status: ToolCallStatus.approved,
    )));
    msg.blocks.add(TextBlock('The directory contains main.dart.'));

    expect(msg.blocks.length, equals(4));
    expect(msg.blocks[0], isA<ThoughtBlock>());
    expect(msg.blocks[1], isA<TextBlock>());
    expect(msg.blocks[2], isA<ToolCallBlock>());
    expect(msg.blocks[3], isA<TextBlock>());

    expect((msg.blocks[0] as ThoughtBlock).thought, equals('Thinking step 1...'));
    expect((msg.blocks[1] as TextBlock).text, equals('I will now inspect the directory.'));
    expect((msg.blocks[2] as ToolCallBlock).toolCall.toolName, equals('list_directory'));
    expect((msg.blocks[3] as TextBlock).text, equals('The directory contains main.dart.'));
    expect(msg.content, contains('I will now inspect the directory.'));
    expect(msg.content, contains('The directory contains main.dart.'));
  });

  test('DiffEvent model test', () {
    final diff = DiffEvent(
      filePath: 'main.py',
      originalContent: 'print("hello")',
      newContent: 'print("hello world")',
      diffLines: [
        DiffLine(type: DiffLineType.removed, text: 'print("hello")', oldLineNumber: 1),
        DiffLine(type: DiffLineType.added, text: 'print("hello world")', newLineNumber: 1),
      ],
    );

    expect(diff.filePath, equals('main.py'));
    expect(diff.diffLines.length, equals(2));
    expect(diff.diffLines.first.type, equals(DiffLineType.removed));
    expect(diff.diffLines.last.type, equals(DiffLineType.added));
  });

  test('ToolchainStatus model test', () {
    final status = ToolchainStatus(
      nodeVersion: 'v20.18.0',
      pythonVersion: 'Python 3.11.2',
      gitVersion: 'git version 2.39.5',
      claudeCodeVersion: '0.2.29',
    );

    expect(status.hasNode, isTrue);
    expect(status.hasPython, isTrue);
    expect(status.hasGit, isTrue);
    expect(status.hasClaudeCode, isTrue);
    expect(status.nodeVersion, equals('v20.18.0'));
  });

  test('PRootProgress model test', () {
    final progress = PRootProgress(
      status: PRootStatus.downloading,
      progress: 0.5,
      message: 'Downloading rootfs...',
      downloadedBytes: 20000000,
      totalBytes: 40000000,
    );

    expect(progress.status, equals(PRootStatus.downloading));
    expect(progress.progress, equals(0.5));
    expect(progress.downloadedBytes, equals(20000000));
  });

  testWidgets('ToolApprovalCard is collapsed by default and expands on tap', (tester) async {
    final toolCall = ToolCallEvent(
      toolCallId: 'call_cmd',
      toolName: 'run_command',
      arguments: {'command': 'git status'},
      status: ToolCallStatus.completed,
      result: 'On branch master\nnothing to commit',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToolApprovalCard(toolCall: toolCall),
        ),
      ),
    );

    // Collapsed by default: chevron expand_more should be visible
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    // Result output should not be displayed while collapsed
    expect(find.text('On branch master\nnothing to commit'), findsNothing);
    // Header summary is visible
    expect(find.text(r'$ git status'), findsOneWidget);

    // Tap the card header to expand
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Expanded: chevron expand_less should be visible
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    // Full result output is now visible
    expect(find.text('On branch master\nnothing to commit'), findsOneWidget);

    // Tap again to collapse
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('On branch master\nnothing to commit'), findsNothing);
  });
}
