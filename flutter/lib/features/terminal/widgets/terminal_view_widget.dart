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

class _TerminalViewWidgetState extends State<TerminalViewWidget> with WidgetsBindingObserver {
  double _fontSize = 14.0;
  bool _initialized = false;
  int _lastCols = 0;
  int _lastRows = 0;
  
  // Use a separate FocusNode for the wrapper to avoid recursion
  late FocusNode _wrapperFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wrapperFocusNode = FocusNode(debugLabel: 'TerminalWrapper');
    VolumeKeyBoard.instance.addListener(_handleVolumeKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wrapperFocusNode.dispose();
    VolumeKeyBoard.instance.removeListener();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Force a resize check when window metrics change (e.g. keyboard show/hide)
    // We use a small delay to let the layout settle
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // This will trigger a rebuild if constraints changed, 
        // but we can also manually trigger a size update if we have the context
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
        } else {
          // Check for size changes during build
          // We wrap in addPostFrameCallback to avoid "setState() or markNeedsBuild() called during build"
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTerminalSize(size);
            }
          });
        }

        return Focus(
          focusNode: _wrapperFocusNode,
          onKey: (node, event) {
            _onKey(event);
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              widget.focusNode.requestFocus();
              SystemChannels.textInput.invokeMethod('TextInput.show');
            },
            onDoubleTap: _zoomIn,
            onLongPress: _zoomOut,
            child: Container(
              color: Colors.black,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
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
