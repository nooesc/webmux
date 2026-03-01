import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:volume_key_board/volume_key_board.dart';

class TerminalViewWidget extends StatefulWidget {
  final Terminal terminal;
  final Function(int cols, int rows) onResize;
  final Function(String data) onInput;
  final FocusNode focusNode;
  final bool ctrlActive;
  final bool altActive;
  final bool shiftActive;
  final VoidCallback onModifiersReset;

  const TerminalViewWidget({
    super.key,
    required this.terminal,
    required this.onResize,
    required this.onInput,
    required this.focusNode,
    this.ctrlActive = false,
    this.altActive = false,
    this.shiftActive = false,
    required this.onModifiersReset,
  });

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  double _fontSize = 14.0;
  bool _initialized = false;
  int _lastCols = 0;
  int _lastRows = 0;

  @override
  void initState() {
    super.initState();
    VolumeKeyBoard.instance.addListener(_handleVolumeKey);
  }

  @override
  void dispose() {
    VolumeKeyBoard.instance.removeListener();
    super.dispose();
  }

  void _handleVolumeKey(VolumeKey event) {
    if (event == VolumeKey.up) {
      _zoomIn();
    } else if (event == VolumeKey.down) {
      _zoomOut();
    }
  }

  void _onKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;
    String? sequence;

    // Special hardware keys
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
      widget.onInput(sequence);
      if (widget.ctrlActive || widget.altActive || widget.shiftActive) {
        widget.onModifiersReset();
      }
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

        // Use RawKeyboardListener to catch special keys while TerminalView handles text
        return RawKeyboardListener(
          focusNode: widget.focusNode,
          onKey: _onKey,
          child: GestureDetector(
            onTap: () {
              widget.focusNode.requestFocus();
            },
            onDoubleTap: _zoomIn,
            onLongPress: _zoomOut,
            child: Container(
              color: Colors.black,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  // Actual terminal rendering and standard text input handling
                  TerminalView(
                    widget.terminal,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    textStyle: TerminalStyle(
                      fontSize: _fontSize,
                      fontFamily: 'JetBrains Mono',
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  
                  // Visual indicator for active soft modifiers
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
