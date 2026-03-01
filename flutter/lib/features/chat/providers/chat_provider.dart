import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/services/websocket_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? detectedTool;
  final String? sessionName;
  final int? windowIndex;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.detectedTool,
    this.sessionName,
    this.windowIndex,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? detectedTool,
    String? sessionName,
    int? windowIndex,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      detectedTool: detectedTool ?? this.detectedTool,
      sessionName: sessionName ?? this.sessionName,
      windowIndex: windowIndex ?? this.windowIndex,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Uuid _uuid = const Uuid();
  StreamSubscription? _messageSubscription;
  WebSocketService? _ws;

  ChatNotifier() : super(const ChatState());

  void setWebSocket(WebSocketService ws) {
    _ws = ws;
    _listenToMessages();
  }

  void _listenToMessages() {
    _messageSubscription?.cancel();
    if (_ws == null) return;

    _messageSubscription = _ws!.messages.listen((message) {
      final type = message['type'] as String?;
      switch (type) {
        case 'chat-history':
          _handleChatHistory(message);
          break;
        case 'chat-event':
          _handleChatEvent(message);
          break;
        case 'chat-log-error':
          _handleChatError(message);
          break;
      }
    });
  }

  void _handleChatHistory(Map<String, dynamic> message) {
    final messagesData = message['messages'] as List<dynamic>? ?? [];
    final tool = message['tool'] as String?;

    final messages = messagesData
        .map((msg) => _parseMessage(msg as Map<String, dynamic>))
        .toList();

    state = state.copyWith(
      messages: messages,
      detectedTool: tool,
      isLoading: false,
      error: null,
    );
  }

  void _handleChatEvent(Map<String, dynamic> message) {
    final msgData = message['message'] as Map<String, dynamic>?;
    if (msgData == null) return;

    final msg = _parseMessage(msgData);

    // Merge consecutive assistant messages
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty &&
        messages.last.type == ChatMessageType.assistant &&
        msg.type == ChatMessageType.assistant) {
      final lastMsg = messages.last;
      messages[messages.length - 1] = lastMsg.copyWith(
        content: lastMsg.content + '\n' + msg.content,
      );
    } else {
      messages.add(msg);
    }

    state = state.copyWith(messages: messages);
  }

  void _handleChatError(Map<String, dynamic> message) {
    final error = message['error'] as String? ?? 'Unknown error';
    state = state.copyWith(error: error, isLoading: false);
  }

  ChatMessage _parseMessage(Map<String, dynamic> data) {
    final role = data['role'] as String? ?? 'assistant';
    final blocks = data['blocks'] as List<dynamic>? ?? [];

    String content = '';
    String? toolName;
    ChatMessageType type;

    if (role == 'user') {
      type = ChatMessageType.user;
      final textBlocks = blocks.where((b) => b['type'] == 'text');
      content = textBlocks.map((b) => b['text'] as String? ?? '').join('\n');
    } else {
      type = ChatMessageType.assistant;
      final textBlocks = blocks.where((b) => b['type'] == 'text');
      final toolBlocks = blocks.where((b) => b['type'] == 'tool_call');
      final toolResultBlocks = blocks.where((b) => b['type'] == 'tool_result');

      content = textBlocks.map((b) => b['text'] as String? ?? '').join('\n');

      if (toolBlocks.isNotEmpty) {
        type = ChatMessageType.tool;
        toolName = toolBlocks.first['name'] as String?;
        final summary = toolBlocks.first['summary'] as String? ?? '';
        content = 'Tool: $toolName - $summary';
      }

      if (toolResultBlocks.isNotEmpty) {
        final resultContent =
            toolResultBlocks.first['content'] as String? ?? '';
        if (resultContent.isNotEmpty) {
          content += '\n\nResult:\n$resultContent';
        }
      }
    }

    return ChatMessage(
      id: _uuid.v4(),
      type: type,
      content: content,
      timestamp: DateTime.now(),
      toolName: toolName,
    );
  }

  void watchChatLog(String sessionName, int windowIndex) {
    state = state.copyWith(
      messages: [],
      isLoading: true,
      error: null,
      sessionName: sessionName,
      windowIndex: windowIndex,
    );
    _ws?.watchChatLog(sessionName, windowIndex);
  }

  void unwatchChatLog() {
    _ws?.unwatchChatLog();
    state = state.copyWith(isLoading: false);
  }

  void sendInput(String data) {
    if (_ws != null && state.sessionName != null) {
      _ws!.sendTerminalData(state.sessionName!, data);
    }
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
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

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final notifier = ChatNotifier();

  // Watch the shared WebSocket service
  ref.listen(sharedWebSocketServiceProvider, (previous, next) {
    notifier.setWebSocket(next as WebSocketService);
  });

  // Set initial WebSocket if already available
  final ws = ref.read(sharedWebSocketServiceProvider);
  notifier.setWebSocket(ws as WebSocketService);

  ref.onDispose(() {
    notifier.unwatchChatLog();
    notifier.dispose();
  });

  return notifier;
});
