import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:volume_key_board/volume_key_board.dart';

class TerminalViewWidget extends StatefulWidget {
  final Terminal terminal;
  final TerminalController? controller;
  final Function(int cols, int rows) onResize;
  final Function(String data) onInput;
  final FocusNode focusNode;
  final bool ctrlActive;
  final bool altActive;
  final bool shiftActive;
  final bool isSelectionMode;
  final VoidCallback onModifiersReset;
  final VoidCallback? onTap;

  const TerminalViewWidget({
    super.key,
    required this.terminal,
    this.controller,
    required this.onResize,
    required this.onInput,
    required this.focusNode,
    this.ctrlActive = false,
    this.altActive = false,
    this.shiftActive = false,
    this.isSelectionMode = false,
    required this.onModifiersReset,
    this.onTap,
  });

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> with WidgetsBindingObserver {
  double _fontSize = 14.0;
  bool _initialized = false;
  int _lastCols = 0;
  int _lastRows = 0;
  
  late FocusNode _wrapperFocusNode;
  late TextEditingController _inputController;

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
    _wrapperFocusNode = FocusNode(debugLabel: 'TerminalWrapper');
    _inputController = TextEditingController();
    VolumeKeyBoard.instance.addListener(_handleVolumeKey);
    widget.terminal.addListener(_onTerminalChange);
  }

  @override
  void didUpdateWidget(TerminalViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalChange);
      widget.terminal.addListener(_onTerminalChange);
    }
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalChange);
    WidgetsBinding.instance.removeObserver(this);
    _wrapperFocusNode.dispose();
    _inputController.dispose();
    VolumeKeyBoard.instance.removeListener();
    super.dispose();
  }

  void _onTerminalChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force text input connection to rebuild when returning to app
      if (widget.focusNode.hasFocus) {
        widget.focusNode.unfocus();
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.focusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    } else if (state == AppLifecycleState.paused) {
      widget.focusNode.unfocus();
    }
  }

  @override
  void didChangeMetrics() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _forceResizeCheck();
      }
    });
  }

  void _forceResizeCheck() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _updateTerminalSize(renderBox.size);
    }
  }

  void _handleVolumeKey(VolumeKey event) {
    if (event == VolumeKey.up) {
      _zoomIn();
    } else if (event == VolumeKey.down) {
      _zoomOut();
    }
  }

  void _handleTextFieldInput(String value) {
    if (value.isEmpty) return;

    for (int i = 0; i < value.length; i++) {
      String char = value[i];
      if (char == '\n') {
        _processInputChar('\r');
      } else {
        _processInputChar(char);
      }
    }

    _inputController.value = TextEditingValue.empty;
  }

  void _processInputChar(String char) {
    String finalData = char;
    bool wasModified = false;

    if (widget.ctrlActive || widget.altActive || widget.shiftActive) {
      wasModified = true;

      if (widget.shiftActive) {
        if (_shiftMap.containsKey(char)) {
          finalData = _shiftMap[char]!;
        } else {
          finalData = char.toUpperCase();
        }
      }

      if (widget.ctrlActive) {
        int code = finalData.toUpperCase().codeUnitAt(0);
        if (code >= 64 && code <= 95) {
          finalData = String.fromCharCode(code - 64);
        } else if (finalData == ' ') {
          finalData = '\x00';
        }
      }

      if (widget.altActive) {
        finalData = '\x1b$finalData';
      }
    }

    widget.onInput(finalData);

    if (wasModified) {
      widget.onModifiersReset();
    }
  }

  void _onKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    
    // In selection mode, we might want to allow some keys, 
    // but for now, we keep it simple.
    if (widget.isSelectionMode) return; 

    final key = event.logicalKey;
    String? sequence;

    if (key == LogicalKeyboardKey.backspace) sequence = '\x7f';
    else if (key == LogicalKeyboardKey.tab) sequence = '\t';
    else if (key == LogicalKeyboardKey.escape) sequence = '\x1b';
    else if (key == LogicalKeyboardKey.arrowUp) sequence = '\x1b[A';
    else if (key == LogicalKeyboardKey.arrowDown) sequence = '\x1b[B';
    else if (key == LogicalKeyboardKey.arrowLeft) sequence = '\x1b[D';
    else if (key == LogicalKeyboardKey.arrowRight) sequence = '\x1b[C';
    else if (key == LogicalKeyboardKey.home) sequence = '\x1b[H';
    else if (key == LogicalKeyboardKey.end) sequence = '\x1b[F';
    else if (key == LogicalKeyboardKey.pageUp) sequence = '\x1b[5~';
    else if (key == LogicalKeyboardKey.pageDown) sequence = '\x1b[6~';
    else if (key == LogicalKeyboardKey.delete) sequence = '\x1b[3~';

    if (sequence != null) {
      String finalData = sequence;
      bool wasModified = false;

      if (widget.altActive) {
        finalData = '\x1b$finalData';
        wasModified = true;
      }
      
      widget.onInput(finalData);
      if (wasModified) widget.onModifiersReset();
    }
  }

  void _zoomIn() {
    setState(() {
      _fontSize = (_fontSize * 1.2).clamp(8.0, 32.0);
    });
    _sendResize();
  }

  void _zoomOut() {
    setState(() {
      _fontSize = (_fontSize / 1.2).clamp(8.0, 32.0);
    });
    _sendResize();
  }

  void _sendResize() {
    if (_lastCols > 0 && _lastRows > 0) {
      widget.terminal.resize(_lastCols, _lastRows);
      widget.onResize(_lastCols, _lastRows);
    }
  }

  void _updateTerminalSize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final charWidth = _fontSize * 0.6;
    final charHeight = _fontSize * 1.2;

    final cols = (size.width / charWidth).floor().clamp(10, 200);
    final rows = (size.height / charHeight).floor().clamp(5, 100);

    if (cols != _lastCols || rows != _lastRows) {
      _lastCols = cols;
      _lastRows = rows;
      widget.terminal.resize(cols, rows);
      widget.onResize(cols, rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTerminalSize(size);
          });
        }

        return Focus(
          focusNode: _wrapperFocusNode,
          onKey: (node, event) {
            _onKey(event);
            return KeyEventResult.ignored;
          },
          child: Container(
            color: Colors.black,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Layer 1: GHOST INPUT (Underneath, captures keyboard only)
                // We keep it focused but invisible and non-interactable via gestures
                Positioned(
                  left: -100, // Off-screen but active
                  top: 0,
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _inputController,
                      focusNode: widget.focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _handleTextFieldInput,
                    ),
                  ),
                ),

                // Layer 2: TERMINAL VIEW (On top, captures ALL gestures)
                GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.translucent,
                  child: TerminalView(
                    widget.terminal,
                    controller: widget.controller,
                    readOnly: true, // Crucial: xterm.dart shouldn't try to handle focus itself
                    cursorType: TerminalCursorType.block,
                    textStyle: TerminalStyle(
                      fontSize: _fontSize,
                      fontFamily: 'JetBrains Mono',
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

                // Layer 3: Visual Indicators (Overlay)
                IgnorePointer(
                  child: Stack(
                    children: [
                      if (widget.ctrlActive || widget.altActive || widget.shiftActive)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${widget.ctrlActive ? "CTRL " : ""}${widget.altActive ? "ALT " : ""}${widget.shiftActive ? "SHIFT" : ""}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (widget.isSelectionMode)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SELECTION MODE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
