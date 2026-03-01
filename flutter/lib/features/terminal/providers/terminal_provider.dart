import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../data/services/websocket_service.dart';
import '../../../data/services/terminal_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class TerminalState {
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final Terminal? terminal;
  final TerminalController? controller;

  const TerminalState({
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.terminal,
    this.controller,
  });

  TerminalState copyWith({
    bool? isConnected,
    bool? isLoading,
    String? error,
    Terminal? terminal,
    TerminalController? controller,
  }) {
    return TerminalState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      terminal: terminal ?? this.terminal,
      controller: controller ?? this.controller,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  final TerminalService terminalService;
  final WebSocketService _wsService;
  final Map<String, TerminalController> _controllers = {};
  String? _activeSessionName;

  TerminalNotifier(this.terminalService, this._wsService) : super(TerminalState(isConnected: _wsService.isConnected)) {
    _init();
  }

  void _init() {
    _wsService.connectionState.listen((connected) {
      if (connected && _activeSessionName != null && !state.isConnected) {
        // We just reconnected, so we need to re-attach to the terminal session 
        // to resume receiving terminal data.
        _wsService.attachSession(_activeSessionName!, cols: 80, rows: 24);
      }
      state = state.copyWith(isConnected: connected);
    });
  }

  void connect(String sessionName) async {
    _activeSessionName = sessionName;
    state = state.copyWith(isLoading: true, error: null);

    final terminal = terminalService.createTerminal(sessionName);
    
    // Create or get existing controller for this session
    if (!_controllers.containsKey(sessionName)) {
      _controllers[sessionName] = TerminalController();
    }

    // Send attach-session message
    _wsService.attachSession(sessionName, cols: 80, rows: 24);

    state = state.copyWith(
      isLoading: false,
      isConnected: _wsService.isConnected,
      terminal: terminal,
      controller: _controllers[sessionName],
    );
    
    // Start background service to keep socket alive
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }

  void checkConnection() {
    if (!_wsService.isConnected) {
      _wsService.forceReconnect();
    } else {
      // Send a ping to verify connection is still alive.
      // If the socket is actually dead, this will trigger an error in the channel
      // and force a reconnection cycle.
      _wsService.send({'type': 'ping'});
    }
  }

  void disconnect() {
    _activeSessionName = null;
    FlutterBackgroundService().invoke('stopService');
  }

  void sendData(String sessionName, String data) {
    _wsService.sendTerminalData(sessionName, data);
  }

  void resize(String sessionName, int cols, int rows) {
    terminalService.resizeTerminal(sessionName, cols, rows);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
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
