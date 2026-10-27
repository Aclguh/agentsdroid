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
  final bool isDelta;

  MessageEvent({
    required this.text,
    this.isComplete = false,
    this.isDelta = false,
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

  Map<String, dynamic> toJson() => {
    'toolCallId': toolCallId,
    'toolName': toolName,
    'arguments': arguments,
    'status': status.name,
    'autoApproved': autoApproved,
    'result': result,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ToolCallEvent.fromJson(Map<String, dynamic> json) => ToolCallEvent(
    toolCallId: json['toolCallId'] as String,
    toolName: json['toolName'] as String,
    arguments: (json['arguments'] as Map<String, dynamic>?) ?? {},
    status: ToolCallStatus.values.byName(json['status'] as String? ?? 'pending'),
    autoApproved: json['autoApproved'] as bool? ?? false,
    result: json['result'],
    errorMessage: json['errorMessage'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
  );
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

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'originalContent': originalContent,
    'newContent': newContent,
    'diffLines': diffLines.map((e) => e.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory DiffEvent.fromJson(Map<String, dynamic> json) => DiffEvent(
    filePath: json['filePath'] as String,
    originalContent: json['originalContent'] as String? ?? '',
    newContent: json['newContent'] as String? ?? '',
    diffLines: (json['diffLines'] as List<dynamic>?)
            ?.map((e) => DiffLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
  );
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

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'text': text,
    'oldLineNumber': oldLineNumber,
    'newLineNumber': newLineNumber,
  };

  factory DiffLine.fromJson(Map<String, dynamic> json) => DiffLine(
    type: DiffLineType.values.byName(json['type'] as String),
    text: json['text'] as String,
    oldLineNumber: json['oldLineNumber'] as int?,
    newLineNumber: json['newLineNumber'] as int?,
  );
}
