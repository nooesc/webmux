import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/system_stats.dart';
import '../../../data/services/websocket_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class SystemState {
  final SystemStats? stats;
  final bool isLoading;
  final String? error;

  const SystemState({this.stats, this.isLoading = false, this.error});

  SystemState copyWith({SystemStats? stats, bool? isLoading, String? error}) {
    return SystemState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SystemNotifier extends StateNotifier<SystemState> {
  final WebSocketService _wsService;
  Timer? _refreshTimer;

  SystemNotifier(this._wsService) : super(const SystemState()) {
    _init();
  }

  void _init() {
    _wsService.messages.listen((message) {
      // Handle both response formats: 'stats' (Capacitor) and 'system_stats' (legacy)
      final type = message['type'] as String?;
      if (type == 'stats' || type == 'system_stats') {
        final stats = SystemStats.fromJson(message);
        state = state.copyWith(stats: stats, isLoading: false);
      }
    });

    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refresh();
    });
  }

  void refresh() {
    state = state.copyWith(isLoading: true);
    _wsService.requestSystemStats();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final systemProvider = StateNotifierProvider<SystemNotifier, SystemState>((
  ref,
) {
  final wsService = ref.watch(sharedWebSocketServiceProvider);
  return SystemNotifier(wsService);
});
