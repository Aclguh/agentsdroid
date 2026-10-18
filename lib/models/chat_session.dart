import 'chat_message.dart';

class ChatSessionSummary {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final int messageCount;
  String? projectName; // null for standalone conversations (不在项目中)
  bool isArchived; // true if archived (归档)

  ChatSessionSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.projectName,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messageCount': messageCount,
    'projectName': projectName,
    'isArchived': isArchived,
  };

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) => ChatSessionSummary(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled Session',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messageCount: json['messageCount'] as int? ?? 0,
    projectName: json['projectName'] as String?,
    isArchived: json['isArchived'] as bool? ?? false,
  );
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  String? projectName; // null for standalone conversations (不在项目中)
  bool isArchived; // true if archived (归档)

  ChatSession({
    required this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.projectName,
    this.isArchived = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  ChatSessionSummary toSummary() => ChatSessionSummary(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messageCount: messages.length,
    projectName: projectName,
    isArchived: isArchived,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'projectName': projectName,
    'isArchived': isArchived,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled Session',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List<dynamic>?)
            ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    projectName: json['projectName'] as String?,
    isArchived: json['isArchived'] as bool? ?? false,
  );
}
