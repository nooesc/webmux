import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../widgets/professional_message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionName;
  final int windowIndex;

  const ChatScreen({
    super.key,
    required this.sessionName,
    this.windowIndex = 0,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollButton = false;
  bool _autoScroll = true;
  int _previousMessageCount = 0;

  bool get isDarkMode {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Color get surfaceColor => isDarkMode ? const Color(0xFF1E293B) : Colors.white;

  Color get textPrimary =>
      isDarkMode ? Colors.grey.shade100 : const Color(0xFF1E293B);

  Color get textSecondary =>
      isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatProvider.notifier)
          .watchChatLog(widget.sessionName, widget.windowIndex);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom = position.maxScrollExtent - position.pixels < 150;

    if (_showScrollButton != !isNearBottom && _autoScroll) {
      setState(() {
        _showScrollButton = !isNearBottom;
      });
    }
  }

  void _checkAndScrollToBottom(int newCount) {
    if (_autoScroll && newCount > _previousMessageCount) {
      _smoothScrollToBottom();
    }
    _previousMessageCount = newCount;
  }

  void _smoothScrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      if (maxScroll - currentScroll > 50) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).unwatchChatLog();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _controller.text.trim();
    if (content.isNotEmpty) {
      ref.read(chatProvider.notifier).addUserMessage(content);
      ref.read(chatProvider.notifier).sendInput(content);
      _controller.clear();
      _scrollToBottom();
      setState(() {
        _autoScroll = true;
        _showScrollButton = false;
      });
    }
  }

  void _scrollToBottom() {
    _smoothScrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScrollToBottom(chatState.messages.length);
    });

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sessionName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (chatState.detectedTool != null)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chatState.detectedTool!,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: textSecondary),
            onPressed: () {
              ref.read(chatProvider.notifier).clear();
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? _buildEmptyState()
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          return ProfessionalMessageBubble(
                            message: message,
                            showTimestamp: true,
                            isDarkMode: isDarkMode,
                          );
                        },
                      ),
                      if (_showScrollButton)
                        Positioned(
                          right: 16,
                          bottom: 100,
                          child: AnimatedOpacity(
                            opacity: _showScrollButton ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: FloatingActionButton.small(
                              onPressed: () {
                                setState(() {
                                  _autoScroll = true;
                                });
                                _scrollToBottom();
                              },
                              backgroundColor: const Color(0xFF6366F1),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 48,
              color: isDarkMode
                  ? const Color(0xFF818CF8)
                  : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with Claude Code',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF475569)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(fontSize: 15, color: textPrimary),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _controller.text.trim().isNotEmpty
                      ? _sendMessage
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _controller.text.trim().isNotEmpty
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                      boxShadow: _controller.text.trim().isNotEmpty
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _controller.text.trim().isNotEmpty
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
