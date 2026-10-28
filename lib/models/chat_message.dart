import 'agent_event.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

sealed class MessageBlock {
  Map<String, dynamic> toJson();

  static MessageBlock fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'thought':
        return ThoughtBlock(
          json['thought'] as String? ?? '',
          durationSeconds: json['durationSeconds'] as int?,
        );
      case 'text':
        return TextBlock(json['text'] as String? ?? '');
      case 'tool_call':
        return ToolCallBlock(ToolCallEvent.fromJson(json['toolCall'] as Map<String, dynamic>));
      case 'diff':
        return DiffBlock(DiffEvent.fromJson(json['diff'] as Map<String, dynamic>));
      default:
        return TextBlock(json['text'] as String? ?? '');
    }
  }
}

class ThoughtBlock extends MessageBlock {
  String thought;
  int? durationSeconds;
  ThoughtBlock(this.thought, {this.durationSeconds});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'thought',
    'thought': thought,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };
}

class TextBlock extends MessageBlock {
  String text;
  TextBlock(this.text);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'text',
    'text': text,
  };
}

class ToolCallBlock extends MessageBlock {
  ToolCallEvent toolCall;
  ToolCallBlock(this.toolCall);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tool_call',
    'toolCall': toolCall.toJson(),
  };
}

class DiffBlock extends MessageBlock {
  final DiffEvent diff;
  DiffBlock(this.diff);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'diff',
    'diff': diff.toJson(),
  };
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
    List<MessageBlock> updatedBlocks;
    if (blocks != null) {
      updatedBlocks = List.from(blocks);
    } else {
      updatedBlocks = this.blocks.map((b) {
        if (b is TextBlock) return TextBlock(b.text);
        if (b is ThoughtBlock) return ThoughtBlock(b.thought, durationSeconds: b.durationSeconds);
        if (b is ToolCallBlock) return ToolCallBlock(b.toolCall);
        if (b is DiffBlock) return DiffBlock(b.diff);
        return b;
      }).toList();

      if (content != null) {
        final textIdx = updatedBlocks.indexWhere((b) => b is TextBlock);
        if (textIdx >= 0) {
          (updatedBlocks[textIdx] as TextBlock).text = content;
        } else if (content.isNotEmpty) {
          updatedBlocks.add(TextBlock(content));
        }
      }

      if (thought != null) {
        final thoughtIdx = updatedBlocks.indexWhere((b) => b is ThoughtBlock);
        if (thoughtIdx >= 0) {
          (updatedBlocks[thoughtIdx] as ThoughtBlock).thought = thought;
        } else if (thought.isNotEmpty) {
          updatedBlocks.insert(0, ThoughtBlock(thought));
        }
      }

      if (toolCalls != null) {
        updatedBlocks.removeWhere((b) => b is ToolCallBlock);
        for (final tc in toolCalls) {
          updatedBlocks.add(ToolCallBlock(tc));
        }
      }

      if (diffs != null) {
        updatedBlocks.removeWhere((b) => b is DiffBlock);
        for (final d in diffs) {
          updatedBlocks.add(DiffBlock(d));
        }
      }
    }

    return ChatMessage(
      id: id,
      role: role,
      timestamp: timestamp,
      blocks: updatedBlocks,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'timestamp': timestamp.toIso8601String(),
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'isStreaming': isStreaming,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>?;
    List<MessageBlock> parsedBlocks = [];
    if (rawBlocks != null && rawBlocks.isNotEmpty) {
      parsedBlocks = rawBlocks.map((b) => MessageBlock.fromJson(b as Map<String, dynamic>)).toList();
    } else {
      final content = json['content'] as String? ?? '';
      final thought = json['thought'] as String?;
      if (thought != null && thought.isNotEmpty) {
        parsedBlocks.add(ThoughtBlock(thought));
      }
      if (content.isNotEmpty) {
        parsedBlocks.add(TextBlock(content));
      }
    }

    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.byName(json['role'] as String? ?? 'user'),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      blocks: parsedBlocks,
      isStreaming: json['isStreaming'] as bool? ?? false,
    );
  }
}
