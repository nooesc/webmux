import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../data/services/websocket_service.dart';
import '../../../data/services/terminal_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class TerminalState {
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final Terminal? terminal;

  const TerminalState({
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.terminal,
  });

  TerminalState copyWith({
    bool? isConnected,
    bool? isLoading,
    String? error,
    Terminal? terminal,
  }) {
    return TerminalState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      terminal: terminal ?? this.terminal,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  final WebSocketService _wsService;
  final Map<String, Terminal> _terminals = {};

  TerminalNotifier(this._wsService) : super(const TerminalState()) {
    _init();
  }

  void _init() {
    _wsService.connectionState.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });
  }

  void connect(String sessionName) {
    state = state.copyWith(isLoading: true, error: null);

    // Create or get existing terminal for this session
    if (!_terminals.containsKey(sessionName)) {
      final terminal = Terminal(maxLines: 10000);
      _terminals[sessionName] = terminal;

      // Set up terminal output callback
      terminal.onOutput = (data) {
        _wsService.sendTerminalData(sessionName, data);
      };

      // Set up terminal resize callback
      terminal.onResize = (cols, rows, syncUi, pid) {
        _wsService.resizeTerminal(sessionName, cols, rows);
      };

      // Listen for incoming data from WebSocket
      // Handle output messages - after attach, all output goes to this terminal
      _wsService.messages.listen((message) {
        final type = message['type'] as String?;
        if (type == 'output') {
          // For output messages, write directly to terminal (no session filter needed after attach)
          final data = message['data'] as String?;
          if (data != null) {
            terminal.write(data);
          }
        }
        // Also handle legacy terminal_data format
        if (type == 'terminal_data') {
          final msgSession =
              message['session'] as String? ??
              message['sessionName'] as String?;
          if (msgSession == sessionName) {
            final data = message['data'] as String?;
            if (data != null) {
              terminal.write(data);
            }
          }
        }
      });
    }

    // Send attach-session message using the existing shared WebSocket connection
    // with terminal dimensions (using defaults, resize will update after view renders)
    _wsService.attachSession(sessionName, cols: 80, rows: 24);

    state = state.copyWith(
      isLoading: false,
      isConnected: _wsService.isConnected,
      terminal: _terminals[sessionName],
    );
  }

  void disconnect() {
    // Don't actually disconnect - just clear terminal
  }

  void sendData(String sessionName, String data) {
    _wsService.sendTerminalData(sessionName, data);
  }

  void resize(String sessionName, int cols, int rows) {
    _wsService.resizeTerminal(sessionName, cols, rows);
  }

  @override
  void dispose() {
    _terminals.clear();
    super.dispose();
  }
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) {
    final wsService = ref.watch(sharedWebSocketServiceProvider);
    return TerminalNotifier(wsService);
  },
);
