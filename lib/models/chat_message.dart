import 'agent_event.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

sealed class MessageBlock {}

class ThoughtBlock extends MessageBlock {
  String thought;
  ThoughtBlock(this.thought);
}

class TextBlock extends MessageBlock {
  String text;
  TextBlock(this.text);
}

class ToolCallBlock extends MessageBlock {
  ToolCallEvent toolCall;
  ToolCallBlock(this.toolCall);
}

class DiffBlock extends MessageBlock {
  final DiffEvent diff;
  DiffBlock(this.diff);
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final DateTime timestamp;
  final List<MessageBlock> blocks;
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.role,
    String content = '',
    String? thought,
    DateTime? timestamp,
    List<ToolCallEvent>? toolCalls,
    List<DiffEvent>? diffs,
    List<MessageBlock>? blocks,
    this.isStreaming = false,
  })  : timestamp = timestamp ?? DateTime.now(),
        blocks = blocks ?? [] {
    if (this.blocks.isEmpty) {
      if (thought != null && thought.isNotEmpty) {
        this.blocks.add(ThoughtBlock(thought));
      }
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          this.blocks.add(ToolCallBlock(tc));
        }
      }
      if (content.isNotEmpty) {
        this.blocks.add(TextBlock(content));
      }
      if (diffs != null) {
        for (final d in diffs) {
          this.blocks.add(DiffBlock(d));
        }
      }
    }
  }

  String get content {
    final textBlocks = blocks.whereType<TextBlock>();
    if (textBlocks.isEmpty) return '';
    return textBlocks.map((b) => b.text).join('\n\n');
  }

  set content(String val) {
    final textBlocks = blocks.whereType<TextBlock>();
    if (textBlocks.isNotEmpty) {
      textBlocks.last.text = val;
    } else if (val.isNotEmpty) {
      blocks.add(TextBlock(val));
    }
  }

  String? get thought {
    final thoughtBlock = blocks.whereType<ThoughtBlock>().lastOrNull;
    return thoughtBlock?.thought;
  }

  set thought(String? val) {
    if (val == null) return;
    final thoughtBlock = blocks.whereType<ThoughtBlock>().lastOrNull;
    if (thoughtBlock != null) {
      thoughtBlock.thought = val;
    } else {
      blocks.insert(0, ThoughtBlock(val));
    }
  }

  List<ToolCallEvent> get toolCalls {
    return blocks.whereType<ToolCallBlock>().map((b) => b.toolCall).toList();
  }

  List<DiffEvent> get diffs {
    return blocks.whereType<DiffBlock>().map((b) => b.diff).toList();
  }

  ChatMessage copyWith({
    String? content,
    String? thought,
    List<ToolCallEvent>? toolCalls,
    List<DiffEvent>? diffs,
    List<MessageBlock>? blocks,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      thought: thought ?? this.thought,
      timestamp: timestamp,
      toolCalls: toolCalls ?? List.from(this.toolCalls),
      diffs: diffs ?? List.from(this.diffs),
      blocks: blocks ?? List.from(this.blocks),
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
