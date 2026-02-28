import 'package:equatable/equatable.dart';

enum ChatMessageType {
  user,
  assistant,
  system,
  tool,
  error,
}

class ChatMessage extends Equatable {
  final String id;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final String? toolName;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.toolName,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? id,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    String? toolName,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolName: toolName ?? this.toolName,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'toolName': toolName,
        'isStreaming': isStreaming,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        type: ChatMessageType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ChatMessageType.system,
        ),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        toolName: json['toolName'] as String?,
        isStreaming: json['isStreaming'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, type, content, timestamp, toolName, isStreaming];
}

class ParsedChatBlock extends Equatable {
  final String id;
  final List<ChatMessage> messages;
  final String? summary;

  const ParsedChatBlock({
    required this.id,
    required this.messages,
    this.summary,
  });

  @override
  List<Object?> get props => [id, messages, summary];
}
