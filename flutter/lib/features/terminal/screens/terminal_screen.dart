import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../providers/terminal_provider.dart';
import '../widgets/terminal_view_widget.dart';
import '../widgets/mobile_keyboard.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final String host;
  final String sessionName;

  const TerminalScreen({
    super.key,
    required this.host,
    required this.sessionName,
  });

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final Terminal _terminal;
  final FocusNode _focusNode = FocusNode();
  bool _showKeyboard = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);

    // Connect to the terminal session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalProvider.notifier).connect(
            widget.host,
            widget.sessionName,
          );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleResize(int cols, int rows) {
    ref.read(terminalProvider.notifier).resize(widget.sessionName, cols, rows);
  }

  void _handleInput(String data) {
    ref.read(terminalProvider.notifier).sendData(widget.sessionName, data);
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
        actions: [
          IconButton(
            icon: Icon(_showKeyboard ? Icons.keyboard_hide : Icons.keyboard),
            onPressed: () {
              setState(() {
                _showKeyboard = !_showKeyboard;
              });
            },
            tooltip: _showKeyboard ? 'Hide Keyboard' : 'Show Keyboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(terminalProvider.notifier).connect(
                    widget.host,
                    widget.sessionName,
                  );
            },
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          if (!terminalState.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: terminalState.isLoading ? Colors.orange : Colors.red,
              child: Text(
                terminalState.isLoading
                    ? 'Connecting...'
                    : terminalState.error ?? 'Disconnected',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),

          // Terminal view
          Expanded(
            child: GestureDetector(
              onTap: () {
                _focusNode.requestFocus();
              },
              child: TerminalViewWidget(
                terminal: _terminal,
                onResize: _handleResize,
                onInput: _handleInput,
                focusNode: _focusNode,
              ),
            ),
          ),

          // Mobile keyboard (toggleable)
          if (_showKeyboard)
            MobileKeyboard(
              onKeyPressed: _handleInput,
              onClose: () {
                setState(() {
                  _showKeyboard = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
