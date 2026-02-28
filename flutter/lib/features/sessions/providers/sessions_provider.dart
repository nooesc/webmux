import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/tmux_session.dart';
import '../../../data/services/websocket_service.dart';
import '../../../core/config/app_config.dart';

final sharedWebSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect(AppConfig.wsBaseUrl);
  ref.onDispose(() => service.dispose());
  return service;
});

class SessionsState {
  final List<TmuxSession> sessions;
  final bool isLoading;
  final String? error;

  const SessionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.error,
  });

  SessionsState copyWith({
    List<TmuxSession>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return SessionsState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SessionsNotifier extends StateNotifier<SessionsState> {
  final WebSocketService _wsService;

  SessionsNotifier(this._wsService) : super(const SessionsState()) {
    _init();
  }

  void _init() {
    _wsService.messages.listen((message) {
      // Handle both response formats: 'sessions-list' (Capacitor) and 'session_list' (legacy)
      final type = message['type'] as String?;
      if (type == 'sessions-list' || type == 'session_list') {
        final sessions =
            (message['sessions'] as List?)
                ?.map((s) => TmuxSession.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(sessions: sessions, isLoading: false);
      }
    });

    _wsService.connectionState.listen((connected) {
      if (connected) {
        refresh();
      }
    });
  }

  void refresh() {
    state = state.copyWith(isLoading: true);
    _wsService.requestSessions();
  }

  Future<void> createSession(String name) async {
    state = state.copyWith(isLoading: true);
    _wsService.createSession(name);
    await Future.delayed(const Duration(milliseconds: 500));
    refresh();
  }

  Future<void> killSession(String name) async {
    _wsService.killSession(name);
    await Future.delayed(const Duration(milliseconds: 500));
    refresh();
  }

  void attachSession(String name) {
    _wsService.attachSession(name);
  }
}

final sessionsProvider = StateNotifierProvider<SessionsNotifier, SessionsState>(
  (ref) {
    final wsService = ref.watch(sharedWebSocketServiceProvider);
    return SessionsNotifier(wsService);
  },
);
