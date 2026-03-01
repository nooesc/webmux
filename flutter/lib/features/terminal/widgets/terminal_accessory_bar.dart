import 'package:flutter/material.dart';

class TerminalAccessoryBar extends StatefulWidget {
  final Function(String data) onKeyPressed;
  final VoidCallback onToggleKeyboard;
  final bool isCtrlActive;
  final bool isAltActive;
  final bool isShiftActive;
  final Function(String mod) onModifierTap;

  const TerminalAccessoryBar({
    super.key,
    required this.onKeyPressed,
    required this.onToggleKeyboard,
    required this.isCtrlActive,
    required this.isAltActive,
    required this.isShiftActive,
    required this.onModifierTap,
  });

  @override
  State<TerminalAccessoryBar> createState() => _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends State<TerminalAccessoryBar> {
  void _handleKey(String key) {
    if (key == 'ESC') {
      widget.onKeyPressed('\x1b');
    } else if (key == 'TAB') {
      widget.onKeyPressed('	');
    } else if (key == 'UP') {
      widget.onKeyPressed('\x1b[A');
    } else if (key == 'DOWN') {
      widget.onKeyPressed('\x1b[B');
    } else if (key == 'LEFT') {
      widget.onKeyPressed('\x1b[D');
    } else if (key == 'RIGHT') {
      widget.onKeyPressed('\x1b[C');
    } else if (key == 'HOME') {
      widget.onKeyPressed('\x1b[H');
    } else if (key == 'END') {
      widget.onKeyPressed('\x1b[F');
    } else if (key == 'PGUP') {
      widget.onKeyPressed('\x1b[5~');
    } else if (key == 'PGDN') {
      widget.onKeyPressed('\x1b[6~');
    } else if (key == 'DEL') {
      widget.onKeyPressed('\x1b[3~');
    } else if (key == 'INS') {
      widget.onKeyPressed('\x1b[2~');
    } else if (key.startsWith('F')) {
      final fMap = {
        'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS',
        'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~',
        'F9': '\x1b[20~', 'F10': '\x1b[21~', 'F11': '\x1b[23~', 'F12': '\x1b[24~',
      };
      widget.onKeyPressed(fMap[key] ?? '');
    } else {
      widget.onKeyPressed(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_hide),
            onPressed: widget.onToggleKeyboard,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildModifierKey('CTRL', widget.isCtrlActive),
                  _buildModifierKey('ALT', widget.isAltActive),
                  _buildModifierKey('SHIFT', widget.isShiftActive),
                  _buildKey('ESC'),
                  _buildKey('TAB'),
                  _buildKey('▲', 'UP'),
                  _buildKey('▼', 'DOWN'),
                  _buildKey('◀', 'LEFT'),
                  _buildKey('▶', 'RIGHT'),
                  _buildKey('HOME'),
                  _buildKey('END'),
                  _buildKey('PGUP'),
                  _buildKey('PGDN'),
                  _buildKey('INS'),
                  _buildKey('DEL'),
                  _buildKey('F1'), _buildKey('F2'), _buildKey('F3'), _buildKey('F4'),
                  _buildKey('F5'), _buildKey('F6'), _buildKey('F7'), _buildKey('F8'),
                  _buildKey('F9'), _buildKey('F10'), _buildKey('F11'), _buildKey('F12'),
                  _buildKey('/'), _buildKey('-'), _buildKey('_'), _buildKey(':'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierKey(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Material(
        color: isActive ? Colors.blue[700] : Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () => widget.onModifierTap(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String label, [String? value]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Material(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () => _handleKey(value ?? label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
