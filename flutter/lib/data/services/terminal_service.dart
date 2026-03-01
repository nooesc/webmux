import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'websocket_service.dart';

class TerminalService {
  final WebSocketService _wsService;
  final Map<String, Terminal> _terminals = {};
  final Map<String, Pty> _ptys = {};
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  
  // Custom input processor to handle modifiers
  Function(String session, String data)? _inputProcessor;

  TerminalService(this._wsService);

  Stream<String> get outputStream => _outputController.stream;

  void setInputProcessor(Function(String session, String data) processor) {
    _inputProcessor = processor;
  }

  Terminal createTerminal(String sessionName, {int cols = 80, int rows = 24}) {
    final terminal = Terminal(maxLines: 10000);

    _terminals[sessionName] = terminal;

    // Set up terminal callbacks
    terminal.onOutput = (data) {
      if (_inputProcessor != null) {
        _inputProcessor!(sessionName, data);
      } else {
        _wsService.sendTerminalData(sessionName, data);
      }
    };

    // Listen for incoming data from WebSocket
    _wsService.messages.listen((message) {
      final type = message['type'] as String?;
      
      // Handle terminal output
      // Note: Backend 'output' message ONLY has 'data', no 'session' field.
      // Since we only have one session attached per WS connection, this is correct.
      if (type == 'output') {
        final data = message['data'] as String?;
        if (data != null) {
          terminal.write(data);
        }
      }
      
      // Also handle legacy terminal_data format which DOES have a session field
      if (type == 'terminal_data') {
        final msgSession = message['session'] as String? ?? message['sessionName'] as String?;
        if (msgSession == sessionName) {
          final data = message['data'] as String?;
          if (data != null) {
            terminal.write(data);
          }
        }
      }
    });

    return terminal;
  }

  void resizeTerminal(String sessionName, int cols, int rows) {
    final terminal = _terminals[sessionName];
    if (terminal != null) {
      terminal.resize(cols, rows);
      _wsService.resizeTerminal(sessionName, cols, rows);
    }
  }

  void writeToTerminal(String sessionName, String data) {
    final terminal = _terminals[sessionName];
    terminal?.write(data);
  }

  void closeTerminal(String sessionName) {
    _terminals.remove(sessionName);
    _ptys[sessionName]?.kill();
    _ptys.remove(sessionName);
  }

  void dispose() {
    for (final pty in _ptys.values) {
      pty.kill();
    }
    _terminals.clear();
    _ptys.clear();
    _outputController.close();
  }
}

class NativeTerminalService {
  final Map<String, Pty> _ptys = {};
  final Map<String, Terminal> _terminals = {};

  Pty createPty(String sessionName, {int cols = 80, int rows = 24}) {
    final pty = Pty.start('/bin/bash', columns: cols, rows: rows);

    _ptys[sessionName] = pty;

    final terminal = Terminal(maxLines: 10000);

    _terminals[sessionName] = terminal;

    pty.output.listen((data) {
      terminal.write(utf8.decode(data));
    });

    terminal.onOutput = (data) {
      pty.write(utf8.encode(data));
    };

    return pty;
  }

  void resize(String sessionName, int cols, int rows) {
    _ptys[sessionName]?.resize(cols, rows);
  }

  void kill(String sessionName) {
    _ptys[sessionName]?.kill();
    _ptys.remove(sessionName);
    _terminals.remove(sessionName);
  }

  void dispose() {
    for (final pty in _ptys.values) {
      pty.kill();
    }
    _ptys.clear();
    _terminals.clear();
  }
}
