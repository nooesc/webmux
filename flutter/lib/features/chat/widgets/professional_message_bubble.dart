import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight;
import '../../../data/models/chat_message.dart';

class ProfessionalMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final bool isDarkMode;

  const ProfessionalMessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.isDarkMode = false,
  });

  @override
  State<ProfessionalMessageBubble> createState() =>
      _ProfessionalMessageBubbleState();
}

class _ProfessionalMessageBubbleState extends State<ProfessionalMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get isDark => widget.isDarkMode;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.type == ChatMessageType.user;
    final isError = widget.message.type == ChatMessageType.error;
    final isTool =
        widget.message.type == ChatMessageType.tool ||
        widget.message.type == ChatMessageType.toolCall ||
        widget.message.type == ChatMessageType.toolResult;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildHeader(isUser, isError, isTool),
                const SizedBox(height: 6),
                _buildContent(isUser, isError, isTool),
                if (widget.showTimestamp) ...[
                  const SizedBox(height: 4),
                  _buildTimestamp(isUser),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isUser, bool isError, bool isTool) {
    final Color headerColor;
    final String label;
    final IconData icon;

    if (isUser) {
      headerColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
      label = 'You';
      icon = Icons.person;
    } else if (isError) {
      headerColor = Colors.red.shade400;
      label = 'Error';
      icon = Icons.error_outline;
    } else if (isTool) {
      headerColor = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
      label = widget.message.toolName ?? 'Tool';
      icon = Icons.build;
    } else {
      headerColor = isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
      label = 'Assistant';
      icon = Icons.smart_toy;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isUser) ...[
          Icon(icon, size: 14, color: headerColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: headerColor,
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: headerColor),
        ],
      ],
    );
  }

  Widget _buildContent(bool isUser, bool isError, bool isTool) {
    Color bubbleColor;
    Color textColor;
    Color borderColor;

    if (isUser) {
      bubbleColor = isDark ? const Color(0xFF4F46E5) : const Color(0xFF6366F1);
      textColor = Colors.white;
      borderColor = Colors.transparent;
    } else if (isError) {
      bubbleColor = isDark ? Colors.red.shade900 : Colors.red.shade50;
      textColor = isDark ? Colors.red.shade100 : Colors.red.shade900;
      borderColor = isDark ? Colors.red.shade700 : Colors.red.shade200;
    } else if (isTool) {
      bubbleColor = isDark ? Colors.amber.shade900 : Colors.amber.shade50;
      textColor = isDark ? Colors.amber.shade100 : Colors.black87;
      borderColor = isDark ? Colors.amber.shade700 : Colors.amber.shade300;
    } else {
      bubbleColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      textColor = isDark ? Colors.grey.shade100 : const Color(0xFF1E293B);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser ? null : Border.all(color: borderColor, width: 1),
        boxShadow: isUser
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _buildMessageContent(isUser, isError, isTool, textColor),
    );
  }

  Widget _buildMessageContent(
    bool isUser,
    bool isError,
    bool isTool,
    Color textColor,
  ) {
    if (widget.message.blocks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.message.blocks.map((block) {
          switch (block.type) {
            case ChatBlockType.text:
              return _buildMarkdownBlock(block.text ?? '', textColor, isUser);
            case ChatBlockType.toolCall:
              return _buildToolCallCard(block);
            case ChatBlockType.toolResult:
              return _buildToolResultCard(block);
          }
        }).toList(),
      );
    }

    final content = widget.message.content ?? '';
    if (isUser || isError || isTool) {
      return SelectableText(
        content,
        style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
      );
    }

    return _buildMarkdownBlock(content, textColor, isUser);
  }

  Widget _buildMarkdownBlock(String text, Color textColor, bool isUser) {
    if (text.isEmpty) return const SizedBox.shrink();

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: textColor, fontSize: 14, height: 1.6),
        h1: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h4: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        h5: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        h6: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        code: TextStyle(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          color: isDark ? Colors.pink.shade300 : const Color(0xFF6366F1),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          color: textColor.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: textColor.withValues(alpha: 0.3), width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        listBullet: TextStyle(color: textColor),
        tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        tableBody: TextStyle(color: textColor),
        tableBorder: TableBorder.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: textColor.withValues(alpha: 0.2), width: 1),
          ),
        ),
        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
        a: TextStyle(
          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildToolCallCard(ChatBlock block) {
    final toolIcon = _getToolIcon(block.toolName ?? '');
    final toolName = block.toolName ?? 'Unknown Tool';
    final summary = block.summary ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _CollapsibleToolCard(
        icon: toolIcon,
        title: toolName,
        summary: summary,
        isExpanded: false,
        isDark: isDark,
        onToggle: () {},
        child: block.input != null
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _formatJson(block.input!),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildToolResultCard(ChatBlock block) {
    final content = block.content ?? '';
    final summary = block.summary ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _CollapsibleToolCard(
        icon: '📄',
        title: 'Result',
        summary: summary.isNotEmpty ? summary : content.take(50),
        isExpanded: false,
        isDark: isDark,
        onToggle: () {},
        child: content.isNotEmpty
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  content,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTimestamp(bool isUser) {
    final time = widget.message.timestamp;
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Text(
      formattedTime,
      style: TextStyle(
        fontSize: 10,
        color: isUser
            ? Colors.white.withValues(alpha: 0.7)
            : isDark
            ? Colors.grey.shade500
            : Colors.grey.shade500,
      ),
    );
  }

  String _getToolIcon(String toolName) {
    const icons = {
      'Read': '📄',
      'Edit': '✏️',
      'Write': '📝',
      'Bash': '💻',
      'Glob': '🔍',
      'Grep': '🔍',
      'Task': '🤖',
      'TaskCreate': '🤖',
      'TaskUpdate': '🤖',
      'TaskList': '🤖',
      'TaskGet': '🤖',
      'WebSearch': '🌐',
      'WebFetch': '🌐',
    };
    return icons[toolName] ?? '🔧';
  }

  String _formatJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}

class _CollapsibleToolCard extends StatefulWidget {
  final String icon;
  final String title;
  final String summary;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;
  final Widget? child;

  const _CollapsibleToolCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
    this.child,
  });

  @override
  State<_CollapsibleToolCard> createState() => _CollapsibleToolCardState();
}

class _CollapsibleToolCardState extends State<_CollapsibleToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_CollapsibleToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isDark
        ? Colors.amber.shade700
        : Colors.amber.shade300;
    final bgColor = widget.isDark
        ? Colors.amber.shade900
        : Colors.amber.shade50;
    final textColor = widget.isDark
        ? Colors.amber.shade100
        : Colors.amber.shade900;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
            color: bgColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(widget.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (widget.child != null)
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: textColor,
                        ),
                      ),
                  ],
                ),
              ),
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: widget.child ?? const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isUser;
  final bool isDark;

  CodeBlockBuilder({this.isUser = false, this.isDark = false});

  @override
  Widget? visitElementAfter(element, preferredStyle) {
    final code = element.textContent;
    var language = '';

    if (element.attributes['class'] != null) {
      language = element.attributes['class']!.replaceFirst('language-', '');
    }

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
    final codeColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy,
                          size: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: codeColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String take(int count) {
    if (length <= count) return this;
    return '${substring(0, count)}...';
  }
}
