import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:volume_key_board/volume_key_board.dart';

class TerminalViewWidget extends StatefulWidget {
  final Terminal terminal;
  final Function(int cols, int rows) onResize;
  final Function(String data) onInput;
  final FocusNode focusNode;

  const TerminalViewWidget({
    super.key,
    required this.terminal,
    required this.onResize,
    required this.onInput,
    required this.focusNode,
  });

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  double _fontSize = 14.0;
  bool _ctrlPressed = false;

  int _lastCols = 0;
  int _lastRows = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    widget.terminal.onOutput = widget.onInput;
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      String? sequence;

      if (_ctrlPressed) {
        if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
          _zoomIn();
          return;
        } else if (key == LogicalKeyboardKey.minus) {
          _zoomOut();
          return;
        }
      }

      if (key == LogicalKeyboardKey.f1)
        sequence = '\x1bOP';
      else if (key == LogicalKeyboardKey.f2)
        sequence = '\x1bOQ';
      else if (key == LogicalKeyboardKey.f3)
        sequence = '\x1bOR';
      else if (key == LogicalKeyboardKey.f4)
        sequence = '\x1bOS';
      else if (key == LogicalKeyboardKey.f5)
        sequence = '\x1b[15~';
      else if (key == LogicalKeyboardKey.f6)
        sequence = '\x1b[17~';
      else if (key == LogicalKeyboardKey.f7)
        sequence = '\x1b[18~';
      else if (key == LogicalKeyboardKey.f8)
        sequence = '\x1b[19~';
      else if (key == LogicalKeyboardKey.f9)
        sequence = '\x1b[20~';
      else if (key == LogicalKeyboardKey.f10)
        sequence = '\x1b[21~';
      else if (key == LogicalKeyboardKey.f11)
        sequence = '\x1b[23~';
      else if (key == LogicalKeyboardKey.f12)
        sequence = '\x1b[24~';
      else if (key == LogicalKeyboardKey.arrowUp)
        sequence = '\x1b[A';
      else if (key == LogicalKeyboardKey.arrowDown)
        sequence = '\x1b[B';
      else if (key == LogicalKeyboardKey.arrowRight)
        sequence = '\x1b[C';
      else if (key == LogicalKeyboardKey.arrowLeft)
        sequence = '\x1b[D';
      else if (key == LogicalKeyboardKey.enter)
        sequence = '\r';
      else if (key == LogicalKeyboardKey.backspace)
        sequence = '\x7f';
      else if (key == LogicalKeyboardKey.tab)
        sequence = '\t';
      else if (key == LogicalKeyboardKey.escape)
        sequence = '\x1b';
      else if (key == LogicalKeyboardKey.home)
        sequence = '\x1b[H';
      else if (key == LogicalKeyboardKey.end)
        sequence = '\x1b[F';
      else if (key == LogicalKeyboardKey.pageUp)
        sequence = '\x1b[5~';
      else if (key == LogicalKeyboardKey.pageDown)
        sequence = '\x1b[6~';
      else if (key == LogicalKeyboardKey.insert)
        sequence = '\x1b[2~';
      else if (key == LogicalKeyboardKey.delete)
        sequence = '\x1b[3~';
      else if (HardwareKeyboard.instance.isControlPressed) {
        final code = key.keyLabel.toUpperCase().codeUnitAt(0);
        if (code >= 65 && code <= 90) {
          // A-Z
          sequence = String.fromCharCode(code - 64);
        } else if (key == LogicalKeyboardKey.bracketLeft) {
          sequence = '\x1b';
        } else if (key == LogicalKeyboardKey.backslash) {
          sequence = '\x1c';
        } else if (key == LogicalKeyboardKey.bracketRight) {
          sequence = '\x1d';
        } else if (key == LogicalKeyboardKey.space) {
          sequence = '\x00';
        }
      } else if (HardwareKeyboard.instance.isAltPressed) {
        final char = event.character;
        if (char != null) {
          sequence = '\x1b$char';
        }
      } else if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        setState(() {
          _ctrlPressed = !_ctrlPressed;
        });
        return;
      }

      if (sequence != null) {
        widget.onInput(sequence);
      }
    } else if (event is KeyUpEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        setState(() {
          _ctrlPressed = false;
        });
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
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          if (!_initialized) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateTerminalSize(size);
            });
          }

          return GestureDetector(
            onDoubleTap: _zoomIn,
            onLongPress: _zoomOut,
            child: Container(
              color: Colors.black,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: TerminalView(
                widget.terminal,
                focusNode: widget.focusNode,
                textStyle: TerminalStyle(
                  fontSize: _fontSize,
                  fontFamily: 'JetBrains Mono',
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          );
        },
      ),
    );
  }
}
