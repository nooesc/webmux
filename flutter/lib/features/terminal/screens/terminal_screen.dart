import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../providers/terminal_provider.dart';
import '../widgets/terminal_view_widget.dart';
import '../widgets/mobile_keyboard.dart';
import '../widgets/terminal_accessory_bar.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final String sessionName;

  const TerminalScreen({super.key, required this.sessionName});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final FocusNode _focusNode = FocusNode();
  bool _showCustomKeyboard = false;
  bool _fullscreen = false;
  bool _showStatus = true;
  
  // Modifier states for accessory bar + native keyboard
  bool _ctrlActive = false;
  bool _altActive = false;
  bool _shiftActive = false;

  final Map<String, String> _shiftMap = {
    '1': '!', '2': '@', '3': '#', '4': '\$', '5': '%',
    '6': '^', '7': '&', '8': '*', '9': '(', '0': ')',
    '-': '_', '=': '+', '[': '{', ']': '}', '\\': '|',
    ';': ':', '\'': '"', ',': '<', '.': '>', '/': '?',
    '`': '~',
  };

  @override
  void initState() {
    super.initState();

    // Connect to the terminal session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalProvider.notifier).connect(widget.sessionName);
      // Auto-hide status bar after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showStatus = false;
          });
        }
      });
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
    String finalData = data;
    
    // If it's a single character from native keyboard, apply modifiers
    if (data.length == 1 && (_ctrlActive || _altActive || _shiftActive)) {
      String char = data;
      
      if (_shiftActive) {
        if (_shiftMap.containsKey(char)) {
          char = _shiftMap[char]!;
        } else {
          char = char.toUpperCase();
        }
      }

      if (_ctrlActive) {
        int code = char.toUpperCase().codeUnitAt(0);
        if (code >= 64 && code <= 95) {
          finalData = String.fromCharCode(code - 64);
        } else if (char == ' ') {
          finalData = '\x00';
        } else {
          finalData = char;
        }
      } else {
        finalData = char;
      }

      if (_altActive) {
        finalData = '\x1b$finalData';
      }

      // Auto-reset modifiers after one modified keypress (not locked)
      setState(() {
        _ctrlActive = false;
        _altActive = false;
        _shiftActive = false;
      });
    }

    ref.read(terminalProvider.notifier).sendData(widget.sessionName, finalData);
  }

  void _toggleFullscreen() {
    setState(() {
      _fullscreen = !_fullscreen;
    });
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleKeyboardType() {
    setState(() {
      _showCustomKeyboard = !_showCustomKeyboard;
      if (!_showCustomKeyboard) {
        // Request focus to show native keyboard when switching to accessory bar
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNativeKeyboardVisible = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(widget.sessionName),
              actions: [
                IconButton(
                  icon: Icon(
                    _showCustomKeyboard ? Icons.keyboard : Icons.keyboard_alt_outlined,
                  ),
                  onPressed: _toggleKeyboardType,
                  tooltip: _showCustomKeyboard ? 'Use Native Keyboard' : 'Use Custom Keyboard',
                ),
                IconButton(
                  icon: Icon(
                    _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  onPressed: _toggleFullscreen,
                  tooltip: _fullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref
                        .read(terminalProvider.notifier)
                        .connect(widget.sessionName);
                  },
                  tooltip: 'Reconnect',
                ),
              ],
            ),
      body: Column(
        children: [
          // Connection status bar - shown briefly then auto-hides
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showStatus ? null : 0,
            child: _showStatus
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: terminalState.isConnected
                        ? Colors.green
                        : (terminalState.isLoading
                              ? Colors.orange
                              : Colors.red),
                    child: Text(
                      terminalState.isLoading
                          ? 'Connecting...'
                          : terminalState.isConnected
                          ? 'Connected'
                          : terminalState.error ?? 'Disconnected',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Terminal view
          Expanded(
            child: terminalState.terminal != null
                ? GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                    },
                    onDoubleTap: _toggleFullscreen,
                    onLongPress: () {
                      setState(() {
                        _showStatus = !_showStatus;
                      });
                    },
                    child: TerminalViewWidget(
                      terminal: terminalState.terminal!,
                      onResize: _handleResize,
                      onInput: _handleInput,
                      focusNode: _focusNode,
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Accessory Bar (for native keyboard)
          if (!_showCustomKeyboard && isNativeKeyboardVisible)
            TerminalAccessoryBar(
              onKeyPressed: _handleInput,
              onToggleKeyboard: () {
                _focusNode.unfocus();
              },
              isCtrlActive: _ctrlActive,
              isAltActive: _altActive,
              isShiftActive: _shiftActive,
              onModifierTap: (mod) {
                setState(() {
                  if (mod == 'CTRL') _ctrlActive = !_ctrlActive;
                  if (mod == 'ALT') _altActive = !_altActive;
                  if (mod == 'SHIFT') _shiftActive = !_shiftActive;
                });
              },
            ),

          // Custom virtual keyboard
          if (_showCustomKeyboard)
            MobileKeyboard(
              onKeyPressed: _handleInput,
              onClose: () {
                setState(() {
                  _showCustomKeyboard = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
