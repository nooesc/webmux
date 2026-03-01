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
  final TerminalService terminalService;
  final WebSocketService _wsService;

  TerminalNotifier(this.terminalService, this._wsService) : super(const TerminalState()) {
    _init();
  }

  void _init() {
    _wsService.connectionState.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });
  }

  void connect(String sessionName) {
    state = state.copyWith(isLoading: true, error: null);

    final terminal = terminalService.createTerminal(sessionName);

    // Send attach-session message
    _wsService.attachSession(sessionName, cols: 80, rows: 24);

    state = state.copyWith(
      isLoading: false,
      isConnected: _wsService.isConnected,
      terminal: terminal,
    );
  }

  void disconnect() {
  }

  void sendData(String sessionName, String data) {
    _wsService.sendTerminalData(sessionName, data);
  }

  void resize(String sessionName, int cols, int rows) {
    terminalService.resizeTerminal(sessionName, cols, rows);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

final terminalServiceProvider = Provider<TerminalService>((ref) {
  final wsService = ref.watch(sharedWebSocketServiceProvider);
  return TerminalService(wsService);
});

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) {
    final terminalService = ref.watch(terminalServiceProvider);
    final wsService = ref.watch(sharedWebSocketServiceProvider);
    return TerminalNotifier(terminalService, wsService);
  },
);
