import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/terminal_provider.dart';
import '../widgets/terminal_view_widget.dart';
import '../widgets/mobile_keyboard.dart';
import '../widgets/terminal_accessory_bar.dart';
import '../../auth/providers/auth_provider.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final String sessionName;

  const TerminalScreen({super.key, required this.sessionName});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode(debugLabel: 'TerminalMainFocus');
  bool _showCustomKeyboard = false;
  bool _fullscreen = false;
  bool _showStatus = true;
  bool _wasKeyboardVisible = false;
  
  // Selection Mode state
  bool _isSelectionMode = false;
  bool _hasSelection = false;
  
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
    WidgetsBinding.instance.addObserver(this);
    
    _focusNode.addListener(_onFocusChange);

    // Connect to the terminal session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalNotifier = ref.read(terminalProvider.notifier);
      terminalNotifier.connect(widget.sessionName);
      
      terminalNotifier.terminalService.setInputProcessor(_processInput);
      
      // Listen for selection changes via the controller in state
      final terminalState = ref.read(terminalProvider);
      terminalState.controller?.addListener(_onSelectionChange);
      
      _persistActiveSession();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showStatus = false;
          });
        }
      });

      // Initial focus
      _focusNode.requestFocus();
    });
  }

  void _onSelectionChange() {
    final controller = ref.read(terminalProvider).controller;
    if (controller != null) {
      final hasSelection = controller.selection != null;
      if (hasSelection != _hasSelection) {
        setState(() {
          _hasSelection = hasSelection;
        });
      }
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_showCustomKeyboard && !_isSelectionMode) {
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    ref.read(terminalProvider).controller?.removeListener(_onSelectionChange);
    WidgetsBinding.instance.removeObserver(this);
    _clearActiveSession();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Remember keyboard state
      _wasKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    } else if (state == AppLifecycleState.resumed) {
      // Restore focus and keyboard
      if (_wasKeyboardVisible && !_showCustomKeyboard && !_isSelectionMode) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _focusNode.requestFocus();
            // Force keyboard show
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
      }
    }
  }

  void _processInput(String session, String data) {
    if (_isSelectionMode) return;

    String finalData = data;
    bool wasModified = false;

    if (data.length == 1 && (_ctrlActive || _altActive || _shiftActive)) {
      String char = data;
      wasModified = true;

      if (_shiftActive) {
        if (_shiftMap.containsKey(char)) {
          finalData = _shiftMap[char]!;
        } else {
          finalData = char.toUpperCase();
        }
      }

      if (_ctrlActive) {
        int code = finalData.toUpperCase().codeUnitAt(0);
        if (code >= 64 && code <= 95) {
          finalData = String.fromCharCode(code - 64);
        } else if (finalData == ' ') {
          finalData = '\x00';
        }
      }

      if (_altActive) {
        finalData = '\x1b$finalData';
      }
    }

    ref.read(terminalProvider.notifier).sendData(session, finalData);

    if (wasModified) {
      setState(() {
        _ctrlActive = false;
        _altActive = false;
        _shiftActive = false;
      });
    }
  }

  Future<void> _persistActiveSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('active_terminal_session', widget.sessionName);
  }

  Future<void> _clearActiveSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getString('active_terminal_session') == widget.sessionName) {
      await prefs.remove('active_terminal_session');
    }
  }

  void _handleResize(int cols, int rows) {
    ref.read(terminalProvider.notifier).resize(widget.sessionName, cols, rows);
  }

  void _handleInput(String data) {
    // This is called from our widgets (AccessoryBar, MobileKeyboard)
    // We send directly since they handle their own modifiers
    ref.read(terminalProvider.notifier).sendData(widget.sessionName, data);
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
      if (_showCustomKeyboard) {
        _focusNode.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _isSelectionMode = false;
      } else {
        // Show native keyboard
        _focusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (_isSelectionMode) {
        _focusNode.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      } else {
        _focusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
        // Clear selection when leaving selection mode
        ref.read(terminalProvider).controller?.clearSelection();
      }
    });
  }

  void _handleSelectAll() {
    // Temporarily disabled due to API incompatibilities in build
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select All not yet implemented'), duration: Duration(seconds: 1)),
    );
  }

  void _handleCopy() async {
    final terminalState = ref.read(terminalProvider);
    final controller = terminalState.controller;
    final terminal = terminalState.terminal;
    
    if (controller != null && terminal != null && controller.selection != null) {
      final text = terminal.buffer.getText(controller.selection!);
      await Clipboard.setData(ClipboardData(text: text));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _handleInput(data!.text!);
    }
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
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _clearActiveSession();
          }
        },
        child: Column(
          children: [
            // Connection status bar
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
                        if (!_showCustomKeyboard && !_isSelectionMode) {
                          _focusNode.requestFocus();
                          SystemChannels.textInput.invokeMethod('TextInput.show');
                        }
                      },
                      onDoubleTap: _toggleFullscreen,
                      onLongPress: () {
                        setState(() {
                          _showStatus = !_showStatus;
                        });
                      },
                      child: TerminalViewWidget(
                        terminal: terminalState.terminal!,
                        controller: terminalState.controller,
                        onResize: _handleResize,
                        onInput: _handleInput,
                        focusNode: _focusNode,
                        ctrlActive: _ctrlActive,
                        altActive: _altActive,
                        shiftActive: _shiftActive,
                        isSelectionMode: _isSelectionMode,
                        onModifiersReset: () {
                          setState(() {
                            _ctrlActive = false;
                            _altActive = false;
                            _shiftActive = false;
                          });
                        },
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),

            // Accessory Bar (for native keyboard)
            if (!_showCustomKeyboard && (isNativeKeyboardVisible || _isSelectionMode))
              TerminalAccessoryBar(
                onKeyPressed: _handleInput,
                onToggleKeyboard: () {
                  if (_isSelectionMode) {
                    _toggleSelectionMode();
                  } else {
                    _focusNode.unfocus();
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                  }
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
                isSelectionMode: _isSelectionMode,
                onToggleSelectionMode: _toggleSelectionMode,
                onCopy: _handleCopy,
                onPaste: _handlePaste,
                onSelectAll: _handleSelectAll,
                hasSelection: _hasSelection,
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
      ),
    );
  }
}
