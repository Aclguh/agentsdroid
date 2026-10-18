import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/models/chat_message.dart';

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
}
