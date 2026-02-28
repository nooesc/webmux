import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/websocket_service.dart';
import '../../../data/services/terminal_service.dart';

class TerminalState {
  final bool isConnected;
  final bool isLoading;
  final String? error;

  const TerminalState({
    this.isConnected = false,
    this.isLoading = false,
    this.error,
  });

  TerminalState copyWith({
    bool? isConnected,
    bool? isLoading,
    String? error,
  }) {
    return TerminalState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  final WebSocketService _wsService;
  late final TerminalService _terminalService;

  TerminalNotifier(this._wsService) : super(const TerminalState()) {
    _terminalService = TerminalService(_wsService);
    _init();
  }

  void _init() {
    _wsService.connectionState.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });
  }

  void connect(String host, String session) {
    state = state.copyWith(isLoading: true, error: null);

    final url = '$host/terminal?session=$session';
    _wsService.connect(url).then((_) {
      state = state.copyWith(isLoading: false);
    }).catchError((e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    });
  }

  void disconnect() {
    _wsService.disconnect();
  }

  void sendData(String sessionName, String data) {
    _wsService.sendTerminalData(sessionName, data);
  }

  void resize(String sessionName, int cols, int rows) {
    _wsService.resizeTerminal(sessionName, cols, rows);
  }

  @override
  void dispose() {
    _terminalService.dispose();
    super.dispose();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return TerminalNotifier(wsService);
});

final isTerminalConnectedProvider = Provider<bool>((ref) {
  final terminalState = ref.watch(terminalProvider);
  return terminalState.isConnected;
});
