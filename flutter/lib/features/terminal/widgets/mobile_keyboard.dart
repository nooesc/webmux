import 'package:flutter/material.dart';

class MobileKeyboard extends StatelessWidget {
  final Function(String data) onKeyPressed;
  final VoidCallback onClose;

  const MobileKeyboard({
    super.key,
    required this.onKeyPressed,
    required this.onClose,
  });

  void _handleKey(String key) {
    if (key == 'ENTER') {
      onKeyPressed('\r');
    } else if (key == 'TAB') {
      onKeyPressed('\t');
    } else if (key == 'ESC') {
      onKeyPressed('\x1b');
    } else if (key == 'SPACE') {
      onKeyPressed(' ');
    } else if (key == 'BKSPC') {
      onKeyPressed('\x7f');
    } else {
      onKeyPressed(key.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Control row
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('ESC', () => _handleKey('ESC'), flex: 1),
                _buildKey('TAB', () => _handleKey('TAB'), flex: 1),
                _buildKey('CTRL', () {}, flex: 1),
                _buildKey('ALT', () {}, flex: 1),
                _buildKey('F1', () => _handleKey('\x1bOP'), flex: 1),
                _buildKey('F2', () => _handleKey('\x1bOQ'), flex: 1),
                _buildKey('F3', () => _handleKey('\x1bOR'), flex: 1),
                _buildKey('F4', () => _handleKey('\x1bOS'), flex: 1),
                _buildKey('F5', () => _handleKey('\x1b[15~'), flex: 1),
              ],
            ),
          ),

          // Number row
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('1', () => _handleKey('1')),
                _buildKey('2', () => _handleKey('2')),
                _buildKey('3', () => _handleKey('3')),
                _buildKey('4', () => _handleKey('4')),
                _buildKey('5', () => _handleKey('5')),
                _buildKey('6', () => _handleKey('6')),
                _buildKey('7', () => _handleKey('7')),
                _buildKey('8', () => _handleKey('8')),
                _buildKey('9', () => _handleKey('9')),
                _buildKey('0', () => _handleKey('0')),
                _buildKey('BKSPC', () => _handleKey('BKSPC'), flex: 2),
              ],
            ),
          ),

          // QWERTY rows
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('Q', () => _handleKey('Q')),
                _buildKey('W', () => _handleKey('W')),
                _buildKey('E', () => _handleKey('E')),
                _buildKey('R', () => _handleKey('R')),
                _buildKey('T', () => _handleKey('T')),
                _buildKey('Y', () => _handleKey('Y')),
                _buildKey('U', () => _handleKey('U')),
                _buildKey('I', () => _handleKey('I')),
                _buildKey('O', () => _handleKey('O')),
                _buildKey('P', () => _handleKey('P')),
              ],
            ),
          ),

          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('A', () => _handleKey('A')),
                _buildKey('S', () => _handleKey('S')),
                _buildKey('D', () => _handleKey('D')),
                _buildKey('F', () => _handleKey('F')),
                _buildKey('G', () => _handleKey('G')),
                _buildKey('H', () => _handleKey('H')),
                _buildKey('J', () => _handleKey('J')),
                _buildKey('K', () => _handleKey('K')),
                _buildKey('L', () => _handleKey('L')),
                _buildKey('ENTER', () => _handleKey('ENTER'), flex: 2),
              ],
            ),
          ),

          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('Z', () => _handleKey('Z')),
                _buildKey('X', () => _handleKey('X')),
                _buildKey('C', () => _handleKey('C')),
                _buildKey('V', () => _handleKey('V')),
                _buildKey('B', () => _handleKey('B')),
                _buildKey('N', () => _handleKey('N')),
                _buildKey('M', () => _handleKey('M')),
              ],
            ),
          ),

          // Bottom row with arrows and space
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildKey('UP', () => _handleKey('\x1b[A'), flex: 1),
                _buildKey('DOWN', () => _handleKey('\x1b[B'), flex: 1),
                _buildKey('LEFT', () => _handleKey('\x1b[D'), flex: 1),
                _buildKey('RIGHT', () => _handleKey('\x1b[C'), flex: 1),
                _buildKey('SPACE', () => _handleKey('SPACE'), flex: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
