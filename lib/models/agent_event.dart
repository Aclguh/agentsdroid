import 'package:flutter/foundation.dart';

enum AgentState {
  idle,
  thinking,
  executingTool,
  waitingApproval,
  completed,
  error,
}

enum ToolCallStatus {
  pending,
  approved,
  rejected,
  executing,
  completed,
  failed,
}

@immutable
abstract class AgentEvent {
  final DateTime timestamp;
  AgentEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class StatusEvent extends AgentEvent {
  final AgentState state;
  final String? message;

  StatusEvent(this.state, {this.message, super.timestamp});
}

class ThoughtEvent extends AgentEvent {
  final String thought;
  final bool isComplete;

  ThoughtEvent({
    required this.thought,
    this.isComplete = false,
    super.timestamp,
  });
}

class MessageEvent extends AgentEvent {
  final String text;
  final bool isComplete;

  MessageEvent({
    required this.text,
    this.isComplete = false,
    super.timestamp,
  });
}

class ToolCallEvent extends AgentEvent {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final bool autoApproved;
  final dynamic result;
  final String? errorMessage;

  ToolCallEvent({
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
    this.status = ToolCallStatus.pending,
    this.autoApproved = false,
    this.result,
    this.errorMessage,
    super.timestamp,
  });

  ToolCallEvent copyWith({
    ToolCallStatus? status,
    bool? autoApproved,
    dynamic result,
    String? errorMessage,
  }) {
    return ToolCallEvent(
      toolCallId: toolCallId,
      toolName: toolName,
      arguments: arguments,
      status: status ?? this.status,
      autoApproved: autoApproved ?? this.autoApproved,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp,
    );
  }
}

class DiffEvent extends AgentEvent {
  final String filePath;
  final String originalContent;
  final String newContent;
  final List<DiffLine> diffLines;

  DiffEvent({
    required this.filePath,
    required this.originalContent,
    required this.newContent,
    required this.diffLines,
    super.timestamp,
  });
}

enum DiffLineType { unchanged, added, removed }

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;

  DiffLine({
    required this.type,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });
}
