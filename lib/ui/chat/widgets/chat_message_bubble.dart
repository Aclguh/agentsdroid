import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_message.dart';
import '../../diff/diff_viewer_screen.dart';
import 'thought_card.dart';
import 'tool_approval_card.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final MarkdownStyleSheet markdownStyleSheet;
  final void Function(String toolCallId, bool approve)? onApprovalResponse;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.markdownStyleSheet,
    this.onApprovalResponse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (message.role == MessageRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(2)),
          ),
          child: Text(
            message.content,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    // Assistant message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final block in message.blocks) ...[
              if (block is ThoughtBlock && block.thought.isNotEmpty)
                ThoughtCard(
                  thought: block.thought,
                  isStreaming: message.isStreaming,
                  durationSeconds: block.durationSeconds,
                ),

              if (block is ToolCallBlock)
                ToolApprovalCard(
                  toolCall: block.toolCall,
                  onApprove: onApprovalResponse != null
                      ? () => onApprovalResponse!(block.toolCall.toolCallId, true)
                      : null,
                  onReject: onApprovalResponse != null
                      ? () => onApprovalResponse!(block.toolCall.toolCallId, false)
                      : null,
                  onViewDiff: message.diffs.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DiffViewerScreen(diff: message.diffs.last),
                            ),
                          );
                        }
                      : null,
                ),

              if (block is TextBlock && block.text.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MarkdownBody(
                    data: block.text,
                    selectable: true,
                    styleSheet: markdownStyleSheet,
                  ),
                ),

              if (block is DiffBlock)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    leading: const Icon(Icons.difference_outlined, color: Colors.greenAccent),
                    title: Text(block.diff.filePath, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                    subtitle: Text(
                      '${l10n.diffGenerated} (${block.diff.diffLines.length} lines)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiffViewerScreen(diff: block.diff),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
