import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Uuid _uuid = const Uuid();

  ChatNotifier() : super(const ChatState());

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void addUserMessage(String content) {
    final message = ChatMessage(
      id: _uuid.v4(),
      type: ChatMessageType.user,
      content: content,
      timestamp: DateTime.now(),
    );
    addMessage(message);
  }

  void addAssistantMessage(String content, {String? toolName}) {
    final message = ChatMessage(
      id: _uuid.v4(),
      type: toolName != null ? ChatMessageType.tool : ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      toolName: toolName,
    );
    addMessage(message);
  }

  void addSystemMessage(String content) {
    final message = ChatMessage(
      id: _uuid.v4(),
      type: ChatMessageType.system,
      content: content,
      timestamp: DateTime.now(),
    );
    addMessage(message);
  }

  void addErrorMessage(String content) {
    final message = ChatMessage(
      id: _uuid.v4(),
      type: ChatMessageType.error,
      content: content,
      timestamp: DateTime.now(),
    );
    addMessage(message);
  }

  void updateLastMessage(String content) {
    if (state.messages.isNotEmpty) {
      final messages = List<ChatMessage>.from(state.messages);
      final lastMessage = messages.last;
      messages[messages.length - 1] = lastMessage.copyWith(
        content: lastMessage.content + content,
      );
      state = state.copyWith(messages: messages);
    }
  }

  void setStreaming(bool streaming) {
    if (state.messages.isNotEmpty) {
      final messages = List<ChatMessage>.from(state.messages);
      final lastMessage = messages.last;
      messages[messages.length - 1] = lastMessage.copyWith(
        isStreaming: streaming,
      );
      state = state.copyWith(messages: messages);
    }
  }

  void clear() {
    state = const ChatState();
  }

  // Parse Claude Code output into structured messages
  void parseClaudeOutput(String output) {
    final lines = output.split('\n');
    String currentBlock = '';
    String? currentType;

    for (final line in lines) {
      // Detect block types
      if (line.startsWith('Tool:') || line.startsWith('Using tool:')) {
        currentType = 'tool';
        if (currentBlock.isNotEmpty) {
          _flushBlock(currentBlock.trim(), currentType);
        }
        currentBlock = line;
      } else if (line.startsWith('Error:') || line.startsWith('Error -')) {
        currentType = 'error';
        if (currentBlock.isNotEmpty) {
          _flushBlock(currentBlock.trim(), currentType);
        }
        currentBlock = line;
      } else if (line.startsWith('>') || line.startsWith(r'$')) {
        currentType = 'user';
        if (currentBlock.isNotEmpty) {
          _flushBlock(currentBlock.trim(), currentType);
        }
        currentBlock = line;
      } else if (line.trim().isEmpty && currentBlock.isNotEmpty) {
        _flushBlock(currentBlock.trim(), currentType ?? 'assistant');
        currentBlock = '';
        currentType = null;
      } else {
        currentBlock += '\n$line';
      }
    }

    // Flush remaining
    if (currentBlock.isNotEmpty) {
      _flushBlock(currentBlock.trim(), currentType ?? 'assistant');
    }
  }

  void _flushBlock(String content, String type) {
    switch (type) {
      case 'tool':
        final toolName = _extractToolName(content);
        addAssistantMessage(content, toolName: toolName);
        break;
      case 'error':
        addErrorMessage(content);
        break;
      case 'user':
        // Skip user input blocks
        break;
      default:
        addAssistantMessage(content);
    }
  }

  String? _extractToolName(String content) {
    final match = RegExp(r'Tool:\s*(\w+)').firstMatch(content);
    return match?.group(1);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
