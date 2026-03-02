import 'package:equatable/equatable.dart';

enum ChatMessageType {
  user,
  assistant,
  system,
  tool,
  toolCall,
  toolResult,
  error,
}

enum ChatBlockType { text, toolCall, toolResult }

class ChatBlock extends Equatable {
  final ChatBlockType type;
  final String? text;
  final String? toolName;
  final String? summary;
  final Map<String, dynamic>? input;
  final String? content;

  const ChatBlock({
    required this.type,
    this.text,
    this.toolName,
    this.summary,
    this.input,
    this.content,
  });

  factory ChatBlock.text(String? text) =>
      ChatBlock(type: ChatBlockType.text, text: text ?? '');

  factory ChatBlock.toolCall({
    String? toolName,
    String? summary,
    Map<String, dynamic>? input,
  }) => ChatBlock(
    type: ChatBlockType.toolCall,
    toolName: toolName,
    summary: summary,
    input: input,
  );

  factory ChatBlock.toolResult({String? content, String? summary}) => ChatBlock(
    type: ChatBlockType.toolResult,
    content: content,
    summary: summary,
  );

  @override
  List<Object?> get props => [type, text, toolName, summary, input, content];
}

class ChatMessage extends Equatable {
  final String id;
  final ChatMessageType type;
  final String? content;
  final DateTime timestamp;
  final String? toolName;
  final bool isStreaming;
  final List<ChatBlock> blocks;
  final String? summary;

  const ChatMessage({
    required this.id,
    required this.type,
    this.content,
    required this.timestamp,
    this.toolName,
    this.isStreaming = false,
    this.blocks = const [],
    this.summary,
  });

  ChatMessage copyWith({
    String? id,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    String? toolName,
    bool? isStreaming,
    List<ChatBlock>? blocks,
    String? summary,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolName: toolName ?? this.toolName,
      isStreaming: isStreaming ?? this.isStreaming,
      blocks: blocks ?? this.blocks,
      summary: summary ?? this.summary,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'toolName': toolName,
    'isStreaming': isStreaming,
    'blocks': blocks
        .map(
          (b) => {
            'type': b.type.name,
            'text': b.text,
            'toolName': b.toolName,
            'summary': b.summary,
            'input': b.input,
            'content': b.content,
          },
        )
        .toList(),
    'summary': summary,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    type: ChatMessageType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ChatMessageType.system,
    ),
    content: json['content'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    toolName: json['toolName'] as String?,
    isStreaming: json['isStreaming'] as bool? ?? false,
    blocks:
        (json['blocks'] as List<dynamic>?)
            ?.map(
              (b) => ChatBlock(
                type: ChatBlockType.values.firstWhere(
                  (e) => e.name == b['type'],
                  orElse: () => ChatBlockType.text,
                ),
                text: b['text'] as String?,
                toolName: b['toolName'] as String?,
                summary: b['summary'] as String?,
                input: b['input'] as Map<String, dynamic>?,
                content: b['content'] as String?,
              ),
            )
            .toList() ??
        [],
    summary: json['summary'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    content,
    timestamp,
    toolName,
    isStreaming,
    blocks,
    summary,
  ];
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
