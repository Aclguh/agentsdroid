import 'agent_event.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  String? thought;
  final DateTime timestamp;
  final List<ToolCallEvent> toolCalls;
  final List<DiffEvent> diffs;
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.thought,
    DateTime? timestamp,
    List<ToolCallEvent>? toolCalls,
    List<DiffEvent>? diffs,
    this.isStreaming = false,
  })  : timestamp = timestamp ?? DateTime.now(),
        toolCalls = toolCalls ?? [],
        diffs = diffs ?? [];

  ChatMessage copyWith({
    String? content,
    String? thought,
    List<ToolCallEvent>? toolCalls,
    List<DiffEvent>? diffs,
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
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
