import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/cron_job.dart';
import '../../../data/services/websocket_service.dart';

class CronState {
  final List<CronJob> jobs;
  final bool isLoading;
  final String? error;

  const CronState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  CronState copyWith({
    List<CronJob>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return CronState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CronNotifier extends StateNotifier<CronState> {
  final WebSocketService _wsService;
  final Uuid _uuid = const Uuid();

  CronNotifier(this._wsService) : super(const CronState()) {
    _init();
  }

  void _init() {
    _wsService.messages.listen((message) {
      if (message['type'] == 'cron_list') {
        final jobs = (message['jobs'] as List?)
                ?.map((j) => CronJob.fromJson(j as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(jobs: jobs, isLoading: false);
      }
    });
  }

  void refresh() {
    state = state.copyWith(isLoading: true);
    _wsService.requestCronJobs();
  }

  Future<void> createCronJob(String schedule, String command) async {
    final job = CronJob(
      id: _uuid.v4(),
      command: command,
      schedule: schedule,
      enabled: true,
      created: DateTime.now(),
    );

    state = state.copyWith(
      jobs: [...state.jobs, job],
    );

    _wsService.createCronJob(schedule, command);
  }

  Future<void> toggleCronJob(String id) async {
    final jobIndex = state.jobs.indexWhere((j) => j.id == id);
    if (jobIndex != -1) {
      final job = state.jobs[jobIndex];
      final newJobs = List<CronJob>.from(state.jobs);
      newJobs[jobIndex] = job.copyWith(enabled: !job.enabled);
      state = state.copyWith(jobs: newJobs);
      _wsService.toggleCronJob(id, !job.enabled);
    }
  }

  Future<void> deleteCronJob(String id) async {
    final newJobs = state.jobs.where((j) => j.id != id).toList();
    state = state.copyWith(jobs: newJobs);
    _wsService.deleteCronJob(id);
  }
}

final cronProvider = StateNotifierProvider<CronNotifier, CronState>((ref) {
  final wsService = WebSocketService();
  return CronNotifier(wsService);
});
